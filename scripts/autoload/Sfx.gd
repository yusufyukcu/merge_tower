extends Node

# Every sound the game makes that is not the music track.
#
# All of it is synthesised on the way up rather than loaded: three short samples
# -- a struck bell, a low thud, a breath of air -- generated once into
# AudioStreamWAVs and then pitched by the caller. That is not a shortcut around
# missing assets so much as the only way the merge note can actually be a note:
# a merge plays a step up a pentatonic scale chosen from the tier that was made
# and how deep the combo is, so a run of merges climbs and the reward for
# keeping the board moving is something the player hears rather than reads.
#
# Everything rides the Master bus, which is what the SOUND switch in the pause
# menu mutes -- there is nothing here to wire into that switch separately.

const MIX_RATE := 22050

# Enough to cover a pile settling into a chain of merges without a sound ever
# cutting off the one before it, and few enough to be worth pooling at all.
const VOICES := 14

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

var _bell: AudioStreamWAV = null
var _thud: AudioStreamWAV = null
var _air: AudioStreamWAV = null

func _ready() -> void:
	_bell = _make_bell()
	_thud = _make_thud()
	_air = _make_air()
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_voices.append(p)

# --------------------------------------------------------------------- notes

# Pentatonic, so no two steps can land on an interval that sounds like a
# mistake -- a chain of merges is a run up this scale whatever order the tiers
# come out in.
const SCALE := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 31]

static func _semitones(step: int) -> float:
	return float(SCALE[clampi(step, 0, SCALE.size() - 1)])

static func _pitch(semitones: float) -> float:
	return pow(2.0, semitones / 12.0)

# ------------------------------------------------------------------- the kit

# The tier decides which part of the scale the merge sits in, the combo walks
# it upward from there: merging wood over and over still climbs, and reaching a
# knight still sounds higher than reaching a warrior.
func merge(level: int, combo: int) -> void:
	var step: int = clampi(level, 0, 4) * 2 + clampi(combo - 1, 0, 6)
	_play(_bell, _pitch(_semitones(step)), -14.0)

# Topping out a branch: the note above, plus its octave a hair later, so the
# moment rings instead of pinging.
func merge_top(level: int, combo: int) -> void:
	merge(level, combo)
	var step: int = clampi(level, 0, 4) * 2 + clampi(combo - 1, 0, 6)
	var octave: float = _semitones(step) + 12.0
	get_tree().create_timer(0.055).timeout.connect(
		func() -> void: _play(_bell, _pitch(octave), -17.0))

# A piece arriving in the pile. Big pieces speak lower than small ones and a
# hard landing is louder than a nudge, which between them is most of what makes
# a tray of different-sized things feel like it has weights in it.
const LAND_GAP_MS := 28

var _last_land_ms: int = 0

func land(radius: float, power: float) -> void:
	# A pile settling reports a burst of contacts at once; without this they
	# stack into one loud mush instead of reading as one landing.
	var now: int = Time.get_ticks_msec()
	if now - _last_land_ms < LAND_GAP_MS:
		return
	_last_land_ms = now
	var pitch: float = clampf(44.0 / maxf(radius, 14.0), 0.55, 1.45) * randf_range(0.94, 1.06)
	_play(_thud, pitch, -19.0 + 11.0 * clampf(power, 0.0, 1.0))

# Letting go of the piece on the finger: air, not a note. The drop itself has
# no impact yet -- that is the thud, a moment later.
func drop() -> void:
	_play(_air, randf_range(0.92, 1.12), -22.0)

# A unit marching out. The one sound in the kit that moves while it plays: the
# pitch climbs over the flight, which is the tray handing something to the
# field rather than the field being handed something.
func send() -> void:
	var p := _play(_bell, _pitch(7.0), -16.0)
	if p == null:
		return
	var tw := create_tween()
	tw.tween_property(p, "pitch_scale", _pitch(19.0), 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func coin() -> void:
	_play(_bell, _pitch(24.0) * randf_range(0.97, 1.04), -21.0)

# The hour opening. The one sound in the kit that goes down: two notes a fifth
# apart, the second below the first and a beat late, so the field slowing down
# is something heard as well as seen.
func chrono() -> void:
	_play(_bell, _pitch(-5.0), -13.0)
	get_tree().create_timer(0.10).timeout.connect(
		func() -> void: _play(_bell, _pitch(-12.0), -15.0))

# ------------------------------------------------------------------- voicing

func _play(stream: AudioStreamWAV, pitch: float, volume_db: float) -> AudioStreamPlayer:
	if stream == null or _voices.is_empty():
		return null
	var p: AudioStreamPlayer = _take_voice()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.08, 4.0)
	p.volume_db = volume_db
	p.play()
	return p

# A voice that is free if there is one, and otherwise the oldest -- stealing
# beats dropping the sound, since the thing being stolen from is by definition
# the sound that has been ringing longest.
func _take_voice() -> AudioStreamPlayer:
	for i in range(_voices.size()):
		var idx: int = (_next_voice + i) % _voices.size()
		if not _voices[idx].playing:
			_next_voice = (idx + 1) % _voices.size()
			return _voices[idx]
	var stolen: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return stolen

# ------------------------------------------------------------- synthesis
#
# 16-bit mono PCM written straight into a PackedByteArray. Each sample is built
# once at startup and every use of it after that is the same buffer at a
# different pitch, so the whole kit costs three short buffers of memory and no
# disk at all.

const BELL_HZ := 523.25   # C5, the note every pitch above is measured against
const BELL_LEN := 0.40
const THUD_LEN := 0.20
const AIR_LEN := 0.17

func _make_bell() -> AudioStreamWAV:
	var frames: int = int(MIX_RATE * BELL_LEN)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t: float = float(i) / MIX_RATE
		# Two partials over the fundamental, both dying faster than it does:
		# struck wood rather than a held sine.
		var v: float = sin(TAU * BELL_HZ * t)
		v += 0.42 * sin(TAU * BELL_HZ * 2.0 * t) * exp(-t * 15.0)
		v += 0.20 * sin(TAU * BELL_HZ * 3.01 * t) * exp(-t * 26.0)
		var env: float = exp(-t * 8.5) * minf(1.0, t / 0.003)
		data.encode_s16(i * 2, _pcm(v * env * 0.5))
	return _wav(data)

func _make_thud() -> AudioStreamWAV:
	var frames: int = int(MIX_RATE * THUD_LEN)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var dt: float = 1.0 / MIX_RATE
	var phase: float = 0.0
	for i in range(frames):
		var t: float = float(i) * dt
		# The pitch dropping away under it is most of what makes a low tone
		# read as weight landing rather than as a bass note.
		var hz: float = lerpf(150.0, 46.0, minf(1.0, t / 0.07))
		phase += TAU * hz * dt
		var click: float = randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.45
		data.encode_s16(i * 2, _pcm((sin(phase) * 0.95 + click) * exp(-t * 17.0) * 0.7))
	return _wav(data)

func _make_air() -> AudioStreamWAV:
	var frames: int = int(MIX_RATE * AIR_LEN)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var prev: float = 0.0
	for i in range(frames):
		var t: float = float(i) / MIX_RATE
		# White noise dragged through a one-pole low-pass, swelling in and out:
		# a breath, with no pitch in it to clash with the merge notes.
		prev = lerpf(prev, randf_range(-1.0, 1.0), 0.22)
		data.encode_s16(i * 2, _pcm(prev * sin(PI * clampf(t / AIR_LEN, 0.0, 1.0)) * 0.55))
	return _wav(data)

static func _pcm(v: float) -> int:
	return int(clampf(v, -1.0, 1.0) * 32767.0)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = data
	return s
