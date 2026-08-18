extends Node

# Background music.
#
# An autoload rather than a node in Main, so restarting a run does not snap the
# track back to its opening bar, and PROCESS_MODE_ALWAYS so it keeps playing
# over the pause menu and the shop instead of cutting out the moment the tree
# freezes. It ducks while those are open: quiet enough to signal that the game
# has stopped, present enough that the silence is not jarring.
#
# Everything rides the Master bus, which is what the SOUND switch in the pause
# menu mutes.

const TRACK := "res://audio/music.mp3"
const VOLUME_DB := -11.0
const DUCKED_DB := -19.0
const FADE_RATE := 26.0    # dB per second, for both the opening fade and ducking

var _player: AudioStreamPlayer = null

# How close to a bad moment the game currently is -- 0 for ordinary play, 1 at
# the edge of an overflow loss. There is only the one track, so tension is
# ridden rather than crossfaded to: louder and a shade higher as it climbs,
# settled back the instant whatever raised it is over.
var _intensity: float = 0.0
const INTENSITY_VOLUME_DB := 4.0
const INTENSITY_PITCH := 0.06
const INTENSITY_RATE := 2.0

func set_intensity(t: float) -> void:
	_intensity = clampf(t, 0.0, 1.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ResourceLoader.exists(TRACK):
		push_warning("MusicPlayer: %s is missing, running silent" % TRACK)
		return

	var stream: AudioStream = load(TRACK)
	# Seamless repeat is a property of the stream, not the player: without this
	# the track plays once and the game goes quiet.
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = "Master"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	# Starts below the floor and climbs, so the track fades up rather than
	# arriving at full volume on the first frame of the game.
	_player.volume_db = -42.0
	add_child(_player)
	_player.play()

func _process(delta: float) -> void:
	if _player == null:
		return
	var target: float = DUCKED_DB if get_tree().paused else VOLUME_DB
	target += _intensity * INTENSITY_VOLUME_DB
	_player.volume_db = move_toward(_player.volume_db, target, FADE_RATE * delta)
	var target_pitch: float = 1.0 + _intensity * INTENSITY_PITCH
	_player.pitch_scale = move_toward(_player.pitch_scale, target_pitch, INTENSITY_RATE * delta)

func is_playing() -> bool:
	return _player != null and _player.playing

# Note on the shutdown log: Godot reports the MP3 stream and its playback as
# leaked at exit. Stopping the player and dropping the stream in _exit_tree
# does not clear it -- the remaining references are the resource cache and the
# audio server's own playback object, released after script land is gone. It is
# an exit-time artifact with no runtime effect, so it is left alone rather than
# papered over with code that does not actually fix it.
