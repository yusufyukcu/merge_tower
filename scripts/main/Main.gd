extends Node2D

const UIStyle = preload("res://scripts/ui/UIStyle.gd")
const ChoicePlate = preload("res://scripts/ui/ChoicePlate.gd")
const PauseMenu = preload("res://scripts/ui/PauseMenu.gd")
const ShopPanel = preload("res://scripts/ui/ShopPanel.gd")
const HeroAbilityButton = preload("res://scripts/ui/HeroAbilityButton.gd")
const MergeEffect = preload("res://scripts/fx/MergeEffect.gd")
const ImpactEffect = preload("res://scripts/fx/ImpactEffect.gd")
const CoinDrop = preload("res://scripts/fx/CoinDrop.gd")
const Brazier = preload("res://scripts/fx/Brazier.gd")
const Waterfall = preload("res://scripts/fx/Waterfall.gd")
const ChimneySmoke = preload("res://scripts/fx/ChimneySmoke.gd")
const CandleFlame = preload("res://scripts/fx/CandleFlame.gd")
const DriftMotes = preload("res://scripts/fx/DriftMotes.gd")
const FxUtil = preload("res://scripts/fx/FxUtil.gd")
const FocusMarker = preload("res://scripts/fx/FocusMarker.gd")

# Phase 2 orchestrator: merge area physics/drag-drop across three branches,
# SEND, fortress, data-driven waves with a growing enemy roster, frontline
# (melee) + backline (ranged) combat, game over/restart.

const VIEW_W := 1080.0
const VIEW_H := 1920.0

# The merge tray is one painted panel (art/merge_area.png) laid across the
# bottom of the screen at full width. Every number below is measured off that
# image and scaled with it, so the physics walls sit exactly on the drawn stone
# and a piece always rests against the surface it looks like it is touching.
# Change the art and these follow; hand-tuned boxes would not.
const MERGE_ART_W := 1337.0
const MERGE_ART_H := 902.0
const MERGE_ART_SCALE := VIEW_W / MERGE_ART_W
const MERGE_ART_TOP := VIEW_H - MERGE_ART_H * MERGE_ART_SCALE

# Inner faces of the frame, in art pixels: 34..1303 across, 80..680 down.
const MERGE_LEFT := 34.0 * MERGE_ART_SCALE
const MERGE_RIGHT := 1303.0 * MERGE_ART_SCALE
const MERGE_TOP := MERGE_ART_TOP + 80.0 * MERGE_ART_SCALE
const MERGE_BOTTOM := MERGE_ART_TOP + 680.0 * MERGE_ART_SCALE
const SPAWN_Y := MERGE_TOP + 88.0   # held piece hangs clear of the rim

# The SEND button is painted into the panel; the real one is an invisible hit
# box sitting exactly on top of it.
const SEND_ART_RECT := Rect2(375.0, 730.0, 587.0, 125.0)

# The fortress sits at the center behind a circular defense boundary.
# Enemies approach it along four fixed lanes and walk straight in.
const ARENA_CENTER := Vector2(540.0, 640.0)
const ARENA_DEFENSE_RADIUS := 300.0
# Pulled in from 210: the backline was close enough to the defense ring that a
# knight and the archer behind him shared pixels.
const ARENA_BACKLINE_RADIUS := 180.0
const ARENA_FORTRESS_HIT_RADIUS := 100.0

const ARENA_AREA_LEFT := 30.0
const ARENA_AREA_RIGHT := 1050.0
const ARENA_AREA_TOP := 140.0
const ARENA_AREA_BOTTOM := MERGE_ART_TOP   # the arena runs right down to the panel

# The hard ceiling of the formation: four lanes x (3 melee + 2 ranged). What the
# player actually plays against is GameManager.unit_slots, which starts well
# below this and is raised a slot at a time from the shop.
const MAX_DEFENDERS := 20
const FORTRESS_BASE_HP := 100.0
const UPGRADE_CHOICES := 3
const UPGRADE_CARD_SLOTS := 4

var merge_layer: Node2D
var ground_layer: Node2D
var combat_layer: Node2D
var fx_layer: Node2D
var ui_layer: CanvasLayer

var fortress: Fortress

var current_object: MergeObject = null
var next_id: String = "wood"
var dragging: bool = false

var wave_plate: Control
var wave_banner: Control
var wave_banner_wrap: Control
var _wave_banner_tween: Tween = null
var next_panel: Panel
var next_arrow: TextureRect
var next_icon: TextureRect
var next_swatch: Panel
var send_button: Button
var shop_button: Button
var shop_panel: ShopPanel
var hero_button: HeroAbilityButton
# The hero this run marched out with, kept because the button over the shop has
# to ask it something once a frame and there is no other way to find it: it is
# one of twenty defenders and it never advertises itself.
var hero_unit: Defender = null
var coin_panel: Control
var coin_label: Label
var units_panel: Control
var units_label: Label
var coin_target: Vector2 = Vector2.ZERO
var _coin_display: float = 0.0
var _coin_tween: Tween = null
var _coin_pulse: Tween = null
var pause_button: Button
var pause_menu: PauseMenu
var screen_flash: ColorRect
var game_over_panel: Control
var defeat_plate: TextureRect
var essence_label: Label
var upgrade_panel: ChoicePlate
var upgrade_card_ids: Array = []

# Waves fought without a scratch on the fortress, and the point the merge
# combo indicator lives at. Both are pure feel -- nothing here changes what a
# wave costs to clear, only how clearing one cleanly is noticed.
var _clean_streak: int = 0
var _last_fortress_hp: float = -1.0
var combo_label: Label = null
var modifier_banner: Label = null
# Set the moment the ice dragon itself goes down, not merely once its wave is
# past -- MetaManager's dragon unlock is earned by the kill, not the wave
# counter reaching it.
var _beat_dragon: bool = false

func _ready() -> void:
	randomize()
	get_tree().paused = false
	GameManager.reset()
	CombatManager.reset_state()
	SpawnManager.reset()
	UpgradeManager.reset()
	BlessingManager.reset()
	# Before anything is built, because the fires on the map register themselves
	# with it as they go up and the statics outlive a restarted run.
	Lighting.reset()
	lighting = Lighting.new()
	add_child(lighting)

	_build_background()
	_build_merge_bounds()
	_build_combat()
	_build_ui()

	GameManager.state_changed.connect(_on_game_state_changed)
	GameManager.coins_changed.connect(_on_coins_changed)
	MergeManager.unit_created.connect(_on_unit_created)
	MergeManager.combo_changed.connect(_on_combo_changed)
	WaveManager.spawn_enemy_requested.connect(_on_spawn_enemy_requested)
	WaveManager.wave_started.connect(_on_wave_started)
	WaveManager.wave_cleared.connect(_on_wave_cleared)
	CombatManager.focus_changed.connect(_on_focus_changed)
	CombatManager.boss_slam_landed.connect(_on_boss_slam_landed)

	# The tray stays empty and the fight stays unstarted until a blessing is
	# picked -- _begin_run() is what used to sit here directly.
	_show_blessing_selection()

# How long the run that just ended actually took to reach wave 30, wall clock
# from the moment the blessing was chosen rather than from _ready() -- the
# blessing screen itself should never count against a speed record.
var _run_start_ms: int = 0

# Everything a blessing can only be applied to once the player has actually
# picked one: the fortress it starts with, the field it starts with, the
# upgrade level it starts with. Held back from _ready() itself so none of it
# runs before there is a blessing to read.
func _begin_run() -> void:
	_run_start_ms = Time.get_ticks_msec()
	if fortress != null:
		fortress.max_hp = maxf(10.0,
			(FORTRESS_BASE_HP + BlessingManager.fortress_hp_delta()) * BlessingManager.fortress_hp_mult())
		fortress.hp = fortress.max_hp
		_on_fortress_hp_changed(fortress.hp, fortress.max_hp)
	GameManager.unit_slots += BlessingManager.bonus_slots()
	# Whatever the menu shop sold for "the next run" is spent on this one, the
	# moment it starts -- so a run that ends in the first minute still counts as
	# the run it was bought for. The damage half of it is read live off
	# MetaManager by every defender; only the slot has to be handed over here.
	var bought: Dictionary = MetaManager.take_run_boosts()
	GameManager.unit_slots += int(bought["extra_slots"])
	var seed_id: String = BlessingManager.seed_upgrade_id()
	if seed_id != "":
		UpgradeManager.apply(seed_id)
	# Branch mastery bought from the menu shop: a permanent head start on
	# whichever "_spawn" upgrades essence has already paid for, applied the
	# same way a blessing's own seed is -- by calling the normal upgrade path
	# that many times before the first piece ever drops.
	for id in MetaManager.META_UPGRADE_IDS:
		for i in range(MetaManager.meta_upgrade_level(id)):
			UpgradeManager.apply(id)

	_spawn_hero()
	_spawn_squad()
	_spawn_initial()
	WaveManager.start()

# ---------------------------------------------------------------------- hero
#
# The one unit a run never has to build. Whichever of the six was chosen on the
# menu is already standing on the ring before the first piece falls into the
# tray, which is the whole promise of the hero screen: the choice made there is
# visible on the field the second the run starts, not five merges in.
#
# It is handed the field slot it stands in rather than taking one, so picking a
# hero never quietly costs the player a merged unit they would otherwise have
# fielded -- and because it is dispatched before anything else, it always gets
# the pick of an empty board.
func _spawn_hero() -> void:
	var id: String = MetaManager.hero_id()
	if id == "" or not UnitDatabase.is_unit(id):
		return
	var role: String = UnitDatabase.get_def(id).get("role", "melee")
	var lane: int = _pick_lane(role)
	if lane < 0:
		return
	var slot: int = _free_slot(lane, role)
	if slot < 0:
		return

	GameManager.unit_slots += 1
	# Held onto for the ability button, which needs to ask this one body about
	# its cooldown every frame for the rest of the run.
	hero_unit = _spawn_defender(id, lane, slot)
	if hero_unit == null:
		return
	# The level the menu's gold has already bought for this hero, brought onto
	# the field the same way the pack's own bodies bring theirs (see
	# _spawn_carried). A hero bought up past UnitDatabase.HERO_ABILITY_LEVEL
	# therefore arrives with its cast already in hand.
	hero_unit.start_at_level(MetaManager.hero_level(id))

	# It arrives rather than appearing. One beat of ground breaking under it is
	# enough to say the run has started with somebody already on the field.
	var at: Vector2 = _lane_slot_position(lane, role, slot)
	var fx := ImpactEffect.new()
	ground_layer.add_child(fx)
	fx.global_position = at
	fx.play_ground_slam(UnitDatabase.get_def(id).get("color", UIStyle.ACCENT_GOLD), 1.2)

# --------------------------------------------------------------- the squad
#
# The two bodies picked on the menu's plaques, standing on the ring beside the
# hero before the first piece falls. They are not a choice like the hero is:
# the hero is chosen again every run and costs nothing, and these are taken out
# of the pack and spent by the run starting -- what stands here is a unit the
# player does not have any more.
#
# Handed a field slot each, the same way the hero is and for the same reason.
# The pack has already paid for this body; charging it a slot as well would
# charge twice for one unit, and the point of carrying one in is to open the
# run with it rather than to open the run one merge short.
func _spawn_squad() -> void:
	for entry in MetaManager.take_squad():
		_spawn_carried(String((entry as Dictionary)["id"]),
			int((entry as Dictionary)["level"]))

func _spawn_carried(id: String, level: int) -> void:
	if id == "" or not UnitDatabase.is_unit(id):
		return
	var role: String = UnitDatabase.get_def(id).get("role", "melee")
	var lane: int = _pick_lane(role)
	if lane < 0:
		return
	var slot: int = _free_slot(lane, role)
	if slot < 0:
		return

	GameManager.unit_slots += 1
	var d: Defender = _spawn_defender(id, lane, slot)
	if d == null:
		# The board was fuller than the lane said. Give the slot back rather
		# than leave the run one wider for a body that never arrived.
		GameManager.unit_slots -= 1
		return
	d.start_at_level(level)

	# Lands the way the hero does, so a run visibly opens with everything that
	# was chosen for it already on the ground.
	var fx := ImpactEffect.new()
	ground_layer.add_child(fx)
	fx.global_position = _lane_slot_position(lane, role, slot)
	fx.play_ground_slam(UnitDatabase.get_def(id).get("color", UIStyle.ACCENT_TEAL), 0.9)

# ---------------------------------------------------------------- background

# Where the four roads meet on art/environment.png, as a fraction of the
# painting. The fortress stands on that crossing, so this is the point the map
# is hung from.
const ENV_CROSSROADS := Vector2(0.497, 0.492)

# The three paintings of the same crossroads: the green one the run starts on,
# the frozen one it goes under at wave 30, and the burning one past the dragon.
# All three are hung the same way and stacked in order, so each changeover is a
# crossfade rather than a swap -- see _play_winter_change and _play_lava_change.
var env_sprite: TextureRect
var winter_sprite: TextureRect
var lava_sprite: TextureRect
var lighting: Lighting

# The ember map arrived spelled the way it is spelled on disk. Both spellings
# are looked for rather than one being taken as correct, so the file can be
# renamed later without this having to be found and changed with it.
const LAVA_ART_IDS := ["environment_lava", "enviroment_lava"]

func _lava_art_path() -> String:
	for id in LAVA_ART_IDS:
		var p: String = UnitDatabase.get_art_path(String(id))
		if p != "":
			return p
	return ""

func _build_background() -> void:
	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(VIEW_W, 0), Vector2(VIEW_W, VIEW_H), Vector2(0, VIEW_H)
	])
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)

	var env_art_path := UnitDatabase.get_art_path("environment")
	if env_art_path != "":
		# The arena is a window onto the map, not a box the map is squeezed into:
		# the painting is laid out around its own crossroads and cropped here.
		var arena_clip := Control.new()
		arena_clip.position = Vector2(ARENA_AREA_LEFT, ARENA_AREA_TOP)
		arena_clip.size = Vector2(
			ARENA_AREA_RIGHT - ARENA_AREA_LEFT, ARENA_AREA_BOTTOM - ARENA_AREA_TOP)
		arena_clip.clip_contents = true
		arena_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(arena_clip)

		env_sprite = _add_env_layer(arena_clip, load(env_art_path))
		# The map is also the light map: every body on the field is tinted by
		# whatever patch of it they are standing on. See Ambient.
		_light_from(env_sprite, arena_clip)
		# And the map is the first thing the evening happens to. See Lighting.
		lighting.add_graded(env_sprite)

		# The winter map is the same painting under snow, so it is laid out by
		# the same rule and simply waits at nothing until wave 30 brings it up.
		var winter_art_path := UnitDatabase.get_art_path("environment_winter")
		if winter_art_path != "":
			winter_sprite = _add_env_layer(arena_clip, load(winter_art_path))
			winter_sprite.modulate = Color(1, 1, 1, 0)
			lighting.add_graded(winter_sprite)

		# And the ember map over that one, waiting on the dragon. Added here
		# rather than when it is needed so all three are hung by the same rule
		# in the same frame: a layer built later would have to be positioned
		# against an arena that has already been laid out around it.
		var lava_art_path := _lava_art_path()
		if lava_art_path != "":
			lava_sprite = _add_env_layer(arena_clip, load(lava_art_path))
			lava_sprite.modulate = Color(1, 1, 1, 0)
			lighting.add_graded(lava_sprite)

		# Last into the window, so it lies over all three paintings rather than
		# under the ones that have not come up yet.
		_build_map_ambience(arena_clip)
	else:
		var arena_fill := Polygon2D.new()
		arena_fill.polygon = PackedVector2Array([
			Vector2(ARENA_AREA_LEFT, ARENA_AREA_TOP), Vector2(ARENA_AREA_RIGHT, ARENA_AREA_TOP),
			Vector2(ARENA_AREA_RIGHT, ARENA_AREA_BOTTOM), Vector2(ARENA_AREA_LEFT, ARENA_AREA_BOTTOM)
		])
		arena_fill.color = Color(0.13, 0.13, 0.19)
		add_child(arena_fill)

	_build_merge_tray()

	_draw_ring(ARENA_CENTER, ARENA_DEFENSE_RADIUS, Color(0.85, 0.3, 0.3, 0.75), 5.0)
	_draw_lane_markers()

# ------------------------------------------------------------- living map
#
# The map is a painting, and a painting of a waterfall is a photograph of one:
# everything in it that ought to be moving is holding perfectly still. These are
# the three places the painting itself admits something is going on -- the fall
# in the north-west, the wisps standing over the chimneys, the candles on the
# signposts at the mouth of every road -- and each is given the movement the
# paint is already promising. Nothing here draws anything the map does not
# already have; it only stops it being a photograph.
#
# Every position is in map-art pixels, read straight off art/environment.png,
# and goes through _env_point, so the effects follow the painting wherever it
# ends up hung rather than being pinned to screen coordinates that would drift
# the moment the arena is resized. The winter map is the same scene under snow,
# so one set of numbers serves both.

# Where the fall meets the pool, and how far above that the ribbons start. The
# arena window cuts the top off the cliff, so the ribbons are emitted from above
# the cut and simply arrive -- which is what a fall coming in from off-screen
# should look like.
const WATERFALL_ART := Vector2(276.0, 141.0)
const WATERFALL_DROP := 86.0

# Chimney pots, each with the way the painted wisp above it leans -- as a ratio
# of travel across the field to travel up the screen, which is what smoke does
# on a map drawn looking down at the village rather than across at it. See
# ChimneySmoke for why that number is so much larger than one.
#
# Both of these stacks stand near an edge of the arena window, so each is blown
# *into* the field rather than out of it: the cottage's plume comes in from the
# left, the farmhouse's runs back along the top. The farmhouse's second, taller
# stack is left out entirely -- it sits above the window's top edge, and smoke
# nobody can see is smoke nobody should be simulating.
const CHIMNEY_ART := [
	{"at": Vector2(108.0, 177.0), "lean": 2.8, "scale": 1.0},
	{"at": Vector2(1096.0, 126.0), "lean": -3.0, "scale": 1.0},
]

# The twelve signpost candles, split by how big the painting drew each flame:
# the posts standing at the crossing carry a full candle, the ones set back down
# the roads a shorter one. A single size for all twelve would put the same fire
# on both and flatten the depth the painting went to the trouble of giving them.
const CANDLE_ART_LARGE := [
	Vector2(537.0, 228.0), Vector2(710.0, 225.0),
	Vector2(282.0, 498.0), Vector2(970.0, 498.0),
	Vector2(538.0, 958.0), Vector2(716.0, 959.0),
]
const CANDLE_ART_SMALL := [
	Vector2(464.0, 457.0), Vector2(785.0, 457.0),
	Vector2(282.0, 666.0), Vector2(971.0, 663.0),
	Vector2(465.0, 755.0), Vector2(784.0, 758.0),
]

# The lights the painting drew but could not switch on.
#
# The map is painted at noon, and at noon a window is a hole in a wall and a
# crystal is a purple rock. Nothing in the picture says so -- the windows are
# there, the mine mouth is there, the seam in the rock is there -- but a
# painting of an afternoon cannot show you which of the things in it would be
# glowing if it were not. So each is given a glow that is worth nothing at noon
# and comes up as the sun goes: by dusk the village has its lights on, and by
# night the only two things in the mine are the crystals.
#
# Positions are in map-art pixels like everything else here, so the same list
# serves the green map and the frozen one -- the windows do not move when it
# snows, and a lit window in a snowfield is worth more than one in a field.
# `peak` is how bright it ever gets, `size` its radius in art pixels.
const MAP_GLOWS := [
	{"at": Vector2(124.0, 252.0), "col": Color(1.0, 0.72, 0.34), "size": 46.0, "peak": 0.55},
	{"at": Vector2(944.0, 268.0), "col": Color(1.0, 0.74, 0.36), "size": 40.0, "peak": 0.50},
	{"at": Vector2(1112.0, 214.0), "col": Color(1.0, 0.70, 0.32), "size": 44.0, "peak": 0.55},
	{"at": Vector2(1020.0, 934.0), "col": Color(1.0, 0.72, 0.34), "size": 44.0, "peak": 0.55},
	{"at": Vector2(1116.0, 1096.0), "col": Color(1.0, 0.64, 0.28), "size": 34.0, "peak": 0.42},
	{"at": Vector2(207.0, 838.0), "col": Color(1.0, 0.60, 0.24), "size": 40.0, "peak": 0.45},
	{"at": Vector2(358.0, 826.0), "col": Color(0.72, 0.42, 1.0), "size": 34.0, "peak": 0.62},
	{"at": Vector2(424.0, 908.0), "col": Color(0.72, 0.42, 1.0), "size": 30.0, "peak": 0.55},
	{"at": Vector2(234.0, 1152.0), "col": Color(0.72, 0.42, 1.0), "size": 30.0, "peak": 0.55},
]

var map_waterfall: Waterfall = null
var _map_glows: Array[Sprite2D] = []
var _glow_phase: float = 0.0

func _build_map_ambience(clip: Control) -> void:
	if env_sprite == null or env_sprite.texture == null:
		return
	# How much bigger than its own pixels the painting ended up being hung, so
	# an effect measured in art pixels comes out the size the art drew it.
	var s: float = env_sprite.size.x / maxf(env_sprite.texture.get_size().x, 1.0)

	map_waterfall = Waterfall.new()
	clip.add_child(map_waterfall)
	map_waterfall.position = _env_point(WATERFALL_ART)
	map_waterfall.setup(WATERFALL_DROP * s, s)

	for spec in CHIMNEY_ART:
		var smoke := ChimneySmoke.new()
		clip.add_child(smoke)
		smoke.position = _env_point(spec["at"] as Vector2)
		smoke.setup(float(spec["scale"]) * s, float(spec["lean"]))

	for art_pos in CANDLE_ART_LARGE:
		_add_candle(clip, art_pos as Vector2, s)
	for art_pos in CANDLE_ART_SMALL:
		_add_candle(clip, art_pos as Vector2, 0.66 * s)

	for spec in MAP_GLOWS:
		_add_map_glow(clip, spec as Dictionary, s)

	# The air itself. Last into the window so the motes drift in front of the
	# painting rather than inside it.
	var motes := DriftMotes.new()
	clip.add_child(motes)
	motes.setup(Rect2(Vector2.ZERO, clip.size))

func _add_candle(clip: Control, art_pos: Vector2, s: float) -> void:
	var flame := CandleFlame.new()
	clip.add_child(flame)
	flame.position = _env_point(art_pos)
	flame.setup(s)

func _add_map_glow(clip: Control, spec: Dictionary, s: float) -> void:
	var size: float = float(spec["size"]) * s
	var glow := FxUtil.bloom(clip, 1.0, 0.0, spec["col"] as Color, 128)
	glow.position = _env_point(spec["at"] as Vector2)
	glow.scale = Vector2.ONE * (size * 2.0 / 128.0)
	# The brightness it will reach lives on the sprite, so the loop that drives
	# all nine of them has only the hour to think about.
	glow.self_modulate = Color(1, 1, 1, float(spec["peak"]))
	_map_glows.append(glow)

# Nine lamps, one loop. Squared against the hour so they come on late: a window
# lit at four in the afternoon is a window nobody believes, and the moment they
# are worth having is the one where the field has gone blue and they have not.
func _update_map_glows(delta: float) -> void:
	if _map_glows.is_empty():
		return
	var night: float = Lighting.night()
	if night <= 0.02 and _glow_phase == 0.0:
		return
	_glow_phase += delta
	var lit: float = night * night
	for i in range(_map_glows.size()):
		var g: Sprite2D = _map_glows[i]
		# Each on its own clock, so nine lamps never breathe as one.
		g.modulate.a = lit * (0.86 + 0.14 * sin(_glow_phase * (0.6 + 0.11 * i) + i * 1.7))

# A point on the painting, given in the painting's own pixels, in the arena
# window's coordinates -- which is the space everything hung inside the window
# is positioned in.
func _env_point(art_pos: Vector2) -> Vector2:
	return env_sprite.position \
		+ art_pos * (env_sprite.size / env_sprite.texture.get_size())

# Hands whichever map is currently on the field to the light sampler, in world
# coordinates, so a unit can ask what the ground under it is doing.
func _light_from(layer: TextureRect, clip: Control) -> void:
	if layer == null or layer.texture == null:
		return
	Ambient.setup(layer.texture, clip.position + layer.position, layer.size)

# Hangs one painting of the crossroads inside the arena window. Every map layer
# goes up through here, so a second one lands pixel for pixel on the first and
# the two can be crossfaded without anything appearing to move.
func _add_env_layer(clip: Control, tex: Texture2D) -> TextureRect:
	var art_size: Vector2 = tex.get_size()
	# Blown up only if the painting cannot reach every edge of the arena
	# once its crossroads is pinned to the fortress; at 1:1 it can, and
	# staying at 1:1 keeps the pixels aligned.
	var cover: float = maxf(1.0, maxf(
		maxf((ARENA_CENTER.x - ARENA_AREA_LEFT) / ENV_CROSSROADS.x,
			(ARENA_AREA_RIGHT - ARENA_CENTER.x) / (1.0 - ENV_CROSSROADS.x)) / art_size.x,
		maxf((ARENA_CENTER.y - ARENA_AREA_TOP) / ENV_CROSSROADS.y,
			(ARENA_AREA_BOTTOM - ARENA_CENTER.y) / (1.0 - ENV_CROSSROADS.y)) / art_size.y))
	var env_size: Vector2 = art_size * cover

	var layer := TextureRect.new()
	layer.texture = tex
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Without this the control's minimum size is the texture's own and it
	# ignores the size it is given -- which is what used to leave the
	# crossroads sitting well below and right of the fortress.
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.size = env_size
	layer.position = (ARENA_CENTER - ENV_CROSSROADS * env_size - clip.position).round()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(layer)
	return layer

# The four roads in. Without these the lane rule is invisible: the player has
# no way to see that a soldier only holds the side he is standing on.
func _draw_lane_markers() -> void:
	for lane_angle in LANE_ANGLES:
		var dir := Vector2(cos(lane_angle), sin(lane_angle))

		var spoke := Line2D.new()
		spoke.points = PackedVector2Array([
			ARENA_CENTER + dir * (ARENA_DEFENSE_RADIUS - 10.0),
			ARENA_CENTER + dir * (ARENA_DEFENSE_RADIUS + 96.0),
		])
		spoke.width = 7.0
		spoke.default_color = Color(0.85, 0.3, 0.3, 0.30)
		add_child(spoke)

		# A short bar across the lane where the line will actually stand -- as
		# wide as the slots themselves, so the marking matches the formation.
		var side := Vector2(-dir.y, dir.x)
		var post := ARENA_CENTER + dir * ARENA_DEFENSE_RADIUS
		var half: float = (LANE_MELEE_SLOTS - 1) * 0.5 * LANE_MELEE_GAP + 22.0
		var bar := Line2D.new()
		bar.points = PackedVector2Array([post - side * half, post + side * half])
		bar.width = 5.0
		bar.default_color = Color(0.95, 0.55, 0.35, 0.32)
		add_child(bar)

# -------------------------------------------------------------- merge tray art

# One painted panel does the whole job: frame, title plaque, the well the
# pieces fall into, and the base the SEND button is printed on. Drawn with
# linear filtering rather than the project's nearest default -- it is a painted
# asset being scaled down, not pixel art, and nearest makes its stonework
# shimmer.

# How far into the evening the tray comes, against the map's full measure.
const TRAY_GRADE := 0.45

func _build_merge_tray() -> void:
	# Anything the panel does not cover (the strip behind its rounded corners).
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([
		Vector2(0, MERGE_ART_TOP), Vector2(VIEW_W, MERGE_ART_TOP),
		Vector2(VIEW_W, VIEW_H), Vector2(0, VIEW_H)
	])
	backdrop.color = Color(0.07, 0.07, 0.11)
	add_child(backdrop)

	# The arena art ends on a hard horizontal cut; this drops it into shadow
	# just above the panel instead of letting it simply stop.
	_add_gradient_band(Vector2(0, MERGE_ART_TOP - 54.0), Vector2(VIEW_W, 54.0),
		Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.5))

	var art_path := UnitDatabase.get_art_path("merge_area")
	if art_path != "":
		var panel := Sprite2D.new()
		panel.texture = load(art_path)
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		panel.centered = false
		panel.position = Vector2(0, MERGE_ART_TOP)
		panel.scale = Vector2(MERGE_ART_SCALE, MERGE_ART_SCALE)
		add_child(panel)
		# The tray comes into the evening with the field, but only part way. It
		# is the surface the player is actually working on, and a workbench at
		# midnight is a workbench nobody can read; taking it a little of the way
		# is enough that it does not read as a lit panel bolted to a dark game.
		lighting.add_graded(panel, TRAY_GRADE)
		_build_braziers()
	else:
		_build_fallback_tray()

	_build_danger_line()
	_build_drop_guide()
	_build_combo_label()

# Merges landed back to back, read off MergeManager's own combo window rather
# than kept here -- this is a display of that count, not a second copy of it.
func _build_combo_label() -> void:
	combo_label = Label.new()
	combo_label.position = Vector2(0, MERGE_ART_TOP - 64.0)
	combo_label.size = Vector2(VIEW_W, 50.0)
	combo_label.pivot_offset = Vector2(VIEW_W * 0.5, 25.0)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 32)
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(combo_label, UIStyle.ACCENT_GOLD, 6)
	combo_label.visible = false
	add_child(combo_label)

	modifier_banner = Label.new()
	modifier_banner.position = Vector2(0, ARENA_AREA_TOP + 40.0)
	modifier_banner.size = Vector2(VIEW_W, 56.0)
	modifier_banner.pivot_offset = Vector2(VIEW_W * 0.5, 28.0)
	modifier_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modifier_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	modifier_banner.add_theme_font_size_override("font_size", 38)
	modifier_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(modifier_banner, UIStyle.ACCENT_RED, 8)
	modifier_banner.modulate.a = 0.0
	add_child(modifier_banner)

# How many merges into a streak the label has finished heating up. Past this it
# is as big, as red and as crooked as it gets -- a ceiling, so a very long run
# does not end up shouting over the tray it is reporting on.
const COMBO_HOT := 6.0

func _on_combo_changed(count: int) -> void:
	if combo_label == null:
		return
	if count < 2:
		combo_label.visible = false
		return
	# The streak is worth more the deeper it runs -- it buys rare-merge chance,
	# and every merge inside it hits harder. The label carries that: the punch
	# grows, the gold burns down to red, and a real run comes in crooked.
	var heat: float = clampf(float(count - 2) / COMBO_HOT, 0.0, 1.0)
	combo_label.visible = true
	combo_label.text = "MERGE x%d" % count
	combo_label.add_theme_color_override("font_color",
		UIStyle.ACCENT_GOLD.lerp(UIStyle.ACCENT_RED, heat))
	var punch: float = 1.22 + 0.5 * heat
	combo_label.scale = Vector2(punch, punch)
	combo_label.rotation = deg_to_rad(randf_range(-5.0, 5.0) * heat)
	var tw := create_tween()
	tw.tween_property(combo_label, "scale", Vector2.ONE, 0.18 + 0.10 * heat) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(combo_label, "rotation", 0.0, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------ overflow

# The tray has a ceiling. Stack a piece over the line and three seconds start
# running; if nothing has dropped back under it by zero, the fortress falls
# outright -- an overflowing tray is a loss, not damage.
#
# The line sits clear ABOVE the piece hanging from the player's finger, not
# below it. Anywhere lower and the count starts the moment a piece is dropped,
# because a falling piece is still up at the release height for a moment. Only
# a pile that has grown all the way to the top should ever trip it, so the line
# is derived from the release height and the largest piece that can hang there
# rather than being a hand-picked number that could quietly drift out of step.
const MAX_PIECE_RADIUS := 50.0     # knight, the biggest thing that can be held
const DANGER_Y := SPAWN_Y - MAX_PIECE_RADIUS - 14.0
const OVERFLOW_SECONDS := 3.0
const DANGER_IDLE := Color(0.95, 0.35, 0.35, 0.26)

var danger_line: Line2D
var overflow_label: Label
var _overflow_timer: float = 0.0
var _overflow_pulse: float = 0.0

func _build_danger_line() -> void:
	danger_line = Line2D.new()
	danger_line.points = PackedVector2Array([
		Vector2(MERGE_LEFT + 10.0, DANGER_Y), Vector2(MERGE_RIGHT - 10.0, DANGER_Y)])
	danger_line.width = 4.0
	danger_line.default_color = DANGER_IDLE
	danger_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	danger_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(danger_line)

func _piece_over_line() -> bool:
	for o in get_tree().get_nodes_in_group("merge_objects"):
		if not (o is MergeObject) or o.held or o.merged:
			continue
		var r: float = float(o.get_stats().get("radius", 34.0))
		if o.global_position.y - r < DANGER_Y:
			return true
	return false

func _update_overflow(delta: float) -> void:
	if not GameManager.is_playing() or not _piece_over_line():
		var was_ticking: bool = GameManager.is_playing() and _overflow_timer > 0.0
		_reset_overflow()
		if was_ticking:
			_on_overflow_escaped()
		return

	_overflow_timer += delta
	var remaining: float = OVERFLOW_SECONDS - _overflow_timer
	if remaining <= 0.0:
		_reset_overflow()
		# Straight to zero, through the normal death path so the castle takes
		# its hit and the game-over screen comes up the way it always does.
		fortress.take_damage(fortress.hp)
		return

	# The closer to zero, the faster and harder the line beats -- and the same
	# closeness rides the music, so the danger is heard as well as seen.
	MusicPlayer.set_intensity(clampf(_overflow_timer / OVERFLOW_SECONDS, 0.0, 1.0))
	_overflow_pulse += delta * (7.0 + (OVERFLOW_SECONDS - remaining) * 5.0)
	var glow: float = 0.55 + 0.45 * sin(_overflow_pulse)
	danger_line.default_color = Color(1.0, 0.28, 0.28, 0.35 + 0.65 * glow)
	danger_line.width = 5.0 + 4.0 * glow

	overflow_label.visible = true
	overflow_label.text = str(int(ceil(remaining)))
	overflow_label.scale = Vector2.ONE * (0.92 + 0.16 * glow)

func _reset_overflow() -> void:
	_overflow_timer = 0.0
	_overflow_pulse = 0.0
	MusicPlayer.set_intensity(0.0)
	if danger_line != null:
		danger_line.default_color = DANGER_IDLE
		danger_line.width = 4.0
	if overflow_label != null:
		overflow_label.visible = false

# The pile came back down under the line with time still on the clock. A
# close call that pays off rather than one that is simply over: a small purse
# for the nerve it took, dropped where the danger line was.
const OVERFLOW_ESCAPE_REWARD := 12

func _on_overflow_escaped() -> void:
	_pay_out(OVERFLOW_ESCAPE_REWARD, Vector2(VIEW_W * 0.5, DANGER_Y))

# The two fire bowls flanking SEND, measured off the panel art (their flames
# are centred at 256,812 and 1076,812 in the image). Added after the panel so
# the light lands on top of the painting.
const BRAZIER_ART_X := [256.0, 1076.0]
const BRAZIER_ART_Y := 812.0

func _build_braziers() -> void:
	for ax in BRAZIER_ART_X:
		var fire := Brazier.new()
		add_child(fire)
		fire.position = Vector2(
			float(ax) * MERGE_ART_SCALE,
			MERGE_ART_TOP + BRAZIER_ART_Y * MERGE_ART_SCALE)
		fire.setup()

# Plain box in the panel's place, so the tray still reads if the art is absent.
func _build_fallback_tray() -> void:
	var well := Polygon2D.new()
	well.polygon = PackedVector2Array([
		Vector2(MERGE_LEFT, MERGE_TOP), Vector2(MERGE_RIGHT, MERGE_TOP),
		Vector2(MERGE_RIGHT, MERGE_BOTTOM), Vector2(MERGE_LEFT, MERGE_BOTTOM)
	])
	well.color = Color(0.10, 0.11, 0.17)
	add_child(well)

	var floor_edge := Line2D.new()
	floor_edge.points = PackedVector2Array([
		Vector2(MERGE_LEFT, MERGE_BOTTOM), Vector2(MERGE_RIGHT, MERGE_BOTTOM)])
	floor_edge.width = 5.0
	floor_edge.default_color = Color(0.55, 0.40, 0.21)
	add_child(floor_edge)

# A vertical strip fading from `from_col` at the top to `to_col` at the bottom.
func _add_gradient_band(pos: Vector2, size: Vector2, from_col: Color, to_col: Color) -> void:
	var grad := Gradient.new()
	grad.set_color(0, from_col)
	grad.set_color(1, to_col)

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 64

	var band := Sprite2D.new()
	band.texture = tex
	band.centered = false
	band.position = pos
	band.scale = Vector2(size.x / 8.0, size.y / 64.0)
	add_child(band)

# ------------------------------------------------------------------ drop guide

# Shows where the held piece will land. Drawn before the merge layer exists, so
# it always sits under the pieces themselves.
var drop_guide: Line2D
var drop_marker: Polygon2D

func _build_drop_guide() -> void:
	drop_guide = Line2D.new()
	drop_guide.width = 5.0
	drop_guide.default_color = Color(1.0, 0.85, 0.45, 0.16)
	drop_guide.visible = false
	add_child(drop_guide)

	drop_marker = Polygon2D.new()
	drop_marker.polygon = PackedVector2Array([
		Vector2(-18, 0), Vector2(18, 0), Vector2(0, -20)])
	drop_marker.color = Color(1.0, 0.85, 0.45, 0.45)
	drop_marker.visible = false
	add_child(drop_marker)

func _process(delta: float) -> void:
	_update_overflow(delta)
	_update_units_chip()
	_update_hero_button()
	_tick_field_touch()
	_update_map_glows(delta)

	var showing: bool = GameManager.is_playing() \
		and current_object != null and is_instance_valid(current_object)
	drop_guide.visible = showing
	drop_marker.visible = showing
	if not showing:
		return

	var x: float = current_object.global_position.x
	var top: float = current_object.global_position.y \
		+ float(current_object.get_stats().get("radius", 34.0)) + 12.0
	drop_guide.points = PackedVector2Array([
		Vector2(x, top), Vector2(x, MERGE_BOTTOM - 10.0)])
	drop_marker.position = Vector2(x, MERGE_BOTTOM - 6.0)

func _draw_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	var line := Line2D.new()
	var segs := 48
	for i in range(segs + 1):
		var a := TAU * i / segs
		line.add_point(center + Vector2(cos(a), sin(a)) * radius)
	line.width = width
	line.default_color = color
	add_child(line)

# ---------------------------------------------------------------- merge area

func _build_merge_bounds() -> void:
	merge_layer = Node2D.new()
	add_child(merge_layer)

	var wall_mat := PhysicsMaterial.new()
	wall_mat.friction = 0.9
	wall_mat.bounce = 0.0

	_add_wall(Vector2(MERGE_LEFT - 10, (MERGE_TOP + MERGE_BOTTOM) / 2.0), Vector2(20, MERGE_BOTTOM - MERGE_TOP), wall_mat)
	_add_wall(Vector2(MERGE_RIGHT + 10, (MERGE_TOP + MERGE_BOTTOM) / 2.0), Vector2(20, MERGE_BOTTOM - MERGE_TOP), wall_mat)
	_add_wall(Vector2((MERGE_LEFT + MERGE_RIGHT) / 2.0, MERGE_BOTTOM + 10), Vector2(MERGE_RIGHT - MERGE_LEFT + 40, 20), wall_mat)

func _add_wall(pos: Vector2, size: Vector2, mat: PhysicsMaterial) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.physics_material_override = mat
	merge_layer.add_child(body)

# -------------------------------------------------------------------- combat

func _build_combat() -> void:
	# Anything painted on the floor: totem circles, the ground a boss breaks
	# through. Its own layer between the arena art and the fight, because a
	# negative z_index does not put a node under the units -- it puts it under
	# the background as well, which is to say nowhere.
	ground_layer = Node2D.new()
	add_child(ground_layer)

	combat_layer = Node2D.new()
	# Sorts every combat node by its ground contact point, so a unit standing
	# lower on screen draws in front of a tree canopy behind it.
	combat_layer.y_sort_enabled = true
	add_child(combat_layer)

	fortress = Fortress.new()
	fortress.position = ARENA_CENTER
	combat_layer.add_child(fortress)
	fortress.hp_changed.connect(_on_fortress_hp_changed)
	fortress.died.connect(_on_fortress_died)

	# Coin drops live above the fight and outside its y-sorting: a coin flying
	# to the corner should never slip behind a unit it passes. The same is true
	# of anything an ability drops out of the sky, which is why CombatManager is
	# handed this layer along with the ground one.
	fx_layer = Node2D.new()
	add_child(fx_layer)

	CombatManager.init(fortress, ARENA_CENTER, ARENA_DEFENSE_RADIUS,
		ARENA_FORTRESS_HIT_RADIUS, ground_layer, fx_layer)

# --------------------------------------------------------------------- lanes

# Four lanes shared by both sides: enemies walk in down one, and the units
# holding that same lane are the only ones who can stop them. Melee stand
# shoulder to shoulder across the defense ring; archers and mages sit behind
# them on an inner ring, covered for as long as the line in front holds.
const LANE_MELEE_SLOTS := 3
const LANE_RANGED_SLOTS := 2

# Neighbours are spaced by the gap between them in pixels, not by a fixed angle.
# A flat 0.30 rad was 90px of arc out on the defense ring, and a knight is drawn
# 130px across -- the line stood inside itself. These are wide enough for the
# biggest body on each ring with air left over, and still leave a clear gap
# between one lane's line and the next.
const LANE_MELEE_GAP := 150.0
const LANE_RANGED_GAP := 140.0

func _lane_spread(role: String) -> float:
	if role == "melee":
		return LANE_MELEE_GAP / ARENA_DEFENSE_RADIUS
	return LANE_RANGED_GAP / ARENA_BACKLINE_RADIUS

# In-flight SEND animations. A unit claims its exact slot the moment it is
# dispatched and holds it until it lands, so two sent together can never aim for
# the same spot: [{ "lane": int, "role": String, "slot": int }].
#
# This used to hold only lane and role, and the landing unit worked out its own
# slot from a head count -- which put two units on one slot whenever a second
# was still in the air, or whenever a death opened a gap lower down the line.
var _pending_sends: Array = []

func _lane_capacity(role: String) -> int:
	return LANE_MELEE_SLOTS if role == "melee" else LANE_RANGED_SLOTS

# Which of the two rings a role stands on. Melee hold the outer one; everything
# else -- shooters and shamans alike -- shares the backline, so they have to
# share its slots too. Comparing roles instead would let a shaman set up in the
# exact spot an archer is already standing in.
func _lane_line(role: String) -> String:
	return "front" if role == "melee" else "back"

# `ignore` is the unit the player has in hand: it still holds its lane and slot
# while it is up in the air, and the spot it was picked up from has to read as
# free or it would be the one place on the board it could not be put back down.
func _slot_taken(lane: int, role: String, slot: int, ignore: Defender = null) -> bool:
	var line: String = _lane_line(role)
	for d in CombatManager.defenders:
		if d == ignore:
			continue
		if is_instance_valid(d) and d.is_alive() and d.lane == lane \
				and _lane_line(d.role) == line and d.slot == slot:
			return true
	for p in _pending_sends:
		if int(p["lane"]) == lane and _lane_line(String(p["role"])) == line \
				and int(p["slot"]) == slot:
			return true
	return false

# The lowest slot on this lane nobody is standing in or flying to, or -1 when
# the lane is full for that role.
func _free_slot(lane: int, role: String, ignore: Defender = null) -> int:
	for i in range(_lane_capacity(role)):
		if not _slot_taken(lane, role, i, ignore):
			return i
	return -1

# Random among the lanes that still have room, so repeated sends spread the
# defense around the fortress instead of banking up on one side.
func _pick_lane(role: String) -> int:
	var open: Array = []
	for lane in range(LANE_ANGLES.size()):
		if _free_slot(lane, role) >= 0:
			open.append(lane)
	if open.is_empty():
		return -1
	return open[randi() % open.size()]

func _lane_slot_position(lane: int, role: String, index: int) -> Vector2:
	var slots: int = _lane_capacity(role)
	var spread: float = _lane_spread(role)
	var radius: float = ARENA_DEFENSE_RADIUS if role == "melee" else ARENA_BACKLINE_RADIUS
	var a: float = float(LANE_ANGLES[lane]) + (index - (slots - 1) * 0.5) * spread
	return ARENA_CENTER + Vector2(cos(a), sin(a)) * radius

# ---------------------------------------------------------------- enemy spawn

# Enemies only ever come in from north, south, east or west -- never from a
# random point around the arena. Consecutive spawns rotate through the four
# lanes in order, so a wave arrives spread evenly around the fortress instead
# of piling onto one side.
const LANE_ANGLES := [
	-PI / 2.0,   # 0 north
	0.0,         # 1 east
	PI / 2.0,    # 2 south
	PI,          # 3 west
]
# Far enough out to sit well outside the defense ring, close enough in to stay
# inside the arena art on every side.
const SPAWN_RADIUS := 440.0

var _next_lane: int = 0

func _next_spawn_lane() -> int:
	var lane: int = _next_lane
	_next_lane = (_next_lane + 1) % LANE_ANGLES.size()
	return lane

func _on_spawn_enemy_requested(enemy_id: String) -> void:
	var e := Enemy.new()
	e.setup(enemy_id)
	e.apply_wave_scaling(WaveManager.hp_mult, WaveManager.damage_mult)
	e.lane = _next_spawn_lane()
	e.lane_angle = float(LANE_ANGLES[e.lane])
	e.angle = e.lane_angle
	e.current_radius = SPAWN_RADIUS
	combat_layer.add_child(e)
	e.update_position(ARENA_CENTER)
	CombatManager.add_enemy(e)
	e.died.connect(_on_enemy_killed)

	if e.is_boss:
		_play_boss_entrance(e)

# A boss is not walked on with the rabble: the ground breaks open, crystals come
# up through it, and the thing is already standing there when they clear. It is
# held in place while that happens -- see Enemy.entry_timer -- so the entrance
# has the field to itself for a beat.
const BOSS_ENTRANCE_HOLD := 1.0

func _play_boss_entrance(e: Enemy) -> void:
	var radius: float = float(UnitDatabase.get_enemy_def(e.enemy_id).get("radius", 28.0))
	var size: float = clampf(radius / 72.0, 0.9, 2.6)

	var fx := ImpactEffect.new()
	ground_layer.add_child(fx)
	fx.global_position = e.global_position
	fx.play_boss_entrance(size)

	e.entry_timer = BOSS_ENTRANCE_HOLD
	# Rises out of the break rather than appearing in it: flat and sunk to
	# begin with, springing up to full height as the crystals reach theirs.
	e.modulate.a = 0.0
	e.scale = Vector2(0.7, 0.05)
	var tw := e.create_tween()
	tw.tween_interval(0.14)
	tw.tween_property(e, "modulate:a", 1.0, 0.26)
	tw.parallel().tween_property(e, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------- shake & hit-stop
#
# The two cheapest things a fight can do to say a hit mattered. Main itself is
# the Node2D every world layer hangs from -- ground, merge tray, combat, fx --
# while the HUD sits on its own CanvasLayer above, untouched by either: the
# shake moves the battlefield, never the numbers reporting on it.

var _shake_tween: Tween = null

# The SCREEN FX switch in the pause menu. Named for the whole family rather than
# asked of each caller: a player who turned the flashes off did not mean "except
# the shaking", and the merge tray now speaks often enough that they would
# notice if it had been read that narrowly.
func _screen_fx_on() -> bool:
	return pause_menu == null or pause_menu.screen_fx_enabled

func _shake(strength: float, duration: float = 0.24) -> void:
	if not _screen_fx_on():
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	position = Vector2.ZERO
	_shake_tween = create_tween()
	_shake_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var steps: int = maxi(4, int(duration * 30.0))
	for i in range(steps):
		var t: float = float(i + 1) / float(steps)
		var falloff: float = 1.0 - t
		var offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) \
			* strength * falloff
		_shake_tween.tween_property(self, "position", offset, duration / steps)
	_shake_tween.tween_property(self, "position", Vector2.ZERO, 0.02)

# A few frames at near-zero speed on the landing blow -- Engine.time_scale
# affects everything paced by delta, physics included, so it is set back by a
# real-time timer rather than one that would itself be slowed by it.
var _hit_stop_active: bool = false

func _hit_stop(duration: float = 0.06, scale: float = 0.05) -> void:
	if _hit_stop_active or not GameManager.is_playing():
		return
	_hit_stop_active = true
	Engine.time_scale = scale
	get_tree().create_timer(duration, true, false, true).timeout.connect(
		func() -> void:
			Engine.time_scale = 1.0
			_hit_stop_active = false)

func _on_boss_slam_landed(_enemy: Enemy) -> void:
	_shake(10.0, 0.28)

# --------------------------------------------------------------------- gold

# Big payouts come apart into several coins, so a boss showers the screen while
# a goblin drops one. The split is exact -- no gold is created or lost by it.
const COIN_PER_DROP := 5.0
const MAX_COIN_DROPS := 6

# A kill is never quite the number on the tin: a small spread either way keeps
# even a goblin from paying the exact same two gold every time, and every so
# often the blow that lands is worth stopping to look at.
const REWARD_VARIANCE := 1
const CRIT_CHANCE := 0.08
const CRIT_MULT := 2.0

func _on_enemy_killed(enemy: Enemy) -> void:
	MetaManager.record_kill()
	match enemy.enemy_id:
		"ice_dragon":
			_beat_dragon = true
			MetaManager.grant_achievement("dragonslayer")
		"stone_golem":
			MetaManager.grant_achievement("stonebreaker")
		"frost_troll":
			MetaManager.grant_achievement("troll_slayer")

	# The very first kill of the save file's life is never left to the dice:
	# it lands as a guaranteed crit with its own (smaller) shake, so a new
	# player's first taste of a kill mattering is not a coin flip either.
	var first_kill: bool = MetaManager.consume_first_kill()
	if enemy.is_boss:
		_shake(16.0, 0.4)
		_hit_stop(0.07, 0.04)
	elif first_kill:
		_shake(8.0, 0.15)

	var base: int = int(UnitDatabase.get_enemy_def(enemy.enemy_id).get("reward", 2))
	var reward: int = base + randi_range(-REWARD_VARIANCE, REWARD_VARIANCE)
	if first_kill or randf() < CRIT_CHANCE:
		reward = int(round(reward * CRIT_MULT))
	_pay_out(maxi(1, reward), enemy.global_position)

# Gold owed to the player, paid from a point on the field: a body that has just
# fallen, or a unit the player has just sold off the board. Either way the coins
# are what actually pay -- the counter moves as each one lands, not at the moment
# the gold was earned.
func _pay_out(reward_in: int, at: Vector2) -> void:
	var reward: int = int(round(reward_in * BlessingManager.gold_mult()))
	if reward <= 0:
		return

	var count: int = clampi(int(round(reward / COIN_PER_DROP)), 1, MAX_COIN_DROPS)
	var per: int = reward / count
	var remainder: int = reward - per * count

	for i in range(count):
		var coin := CoinDrop.new()
		fx_layer.add_child(coin)
		coin.global_position = at
		coin.collected.connect(_on_coin_collected)
		coin.play(per + (1 if i < remainder else 0), coin_target)

func _on_coin_collected(amount: int) -> void:
	Sfx.coin()
	GameManager.add_coins(amount)

# -------------------------------------------------------------- drop control

func _spawn_initial() -> void:
	next_id = SpawnManager.get_next_material()
	_update_next_label()
	_spawn_current_from_next()

func _spawn_current_from_next() -> void:
	var id := next_id
	next_id = SpawnManager.get_next_material()
	_update_next_label()

	var obj := MergeObject.new()
	obj.setup(id)
	obj.held = true
	obj.freeze = true
	merge_layer.add_child(obj)
	obj.global_position = Vector2(VIEW_W / 2.0, SPAWN_Y)
	current_object = obj

# Wordless: an arrow turned to point right, then the art of the material that
# is actually coming. The piece itself is the label.
const NEXT_CHIP_SIZE := Vector2(206.0, 80.0)
const NEXT_ARROW_SIZE := 46.0
const NEXT_ICON_SIZE := 56.0

func _build_next_chip(root: Control) -> void:
	next_panel = Panel.new()
	next_panel.position = Vector2(56.0, MERGE_ART_TOP - NEXT_CHIP_SIZE.y - 14.0)
	next_panel.size = NEXT_CHIP_SIZE
	next_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_panel.add_theme_stylebox_override("panel",
		UIStyle.panel_box(UIStyle.PANEL_BG, UIStyle.ACCENT_GOLD, 26, 2))
	root.add_child(next_panel)

	var arrow_tex: Texture2D = UIStyle.icon_texture("icon_arrow")
	if arrow_tex != null:
		next_arrow = TextureRect.new()
		next_arrow.texture = arrow_tex
		next_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		next_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		next_arrow.stretch_mode = TextureRect.STRETCH_SCALE
		next_arrow.size = Vector2(NEXT_ARROW_SIZE, NEXT_ARROW_SIZE)
		next_arrow.position = Vector2(26.0, (NEXT_CHIP_SIZE.y - NEXT_ARROW_SIZE) / 2.0)
		next_arrow.pivot_offset = Vector2(NEXT_ARROW_SIZE, NEXT_ARROW_SIZE) / 2.0
		next_arrow.rotation_degrees = 90.0
		next_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		next_panel.add_child(next_arrow)

	next_icon = TextureRect.new()
	next_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	next_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	next_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	next_icon.size = Vector2(NEXT_ICON_SIZE, NEXT_ICON_SIZE)
	next_icon.position = Vector2(112.0, (NEXT_CHIP_SIZE.y - NEXT_ICON_SIZE) / 2.0)
	next_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_panel.add_child(next_icon)

	# Only used when a material has no art of its own.
	next_swatch = Panel.new()
	next_swatch.position = next_icon.position + Vector2(8, 8)
	next_swatch.size = Vector2(NEXT_ICON_SIZE - 16.0, NEXT_ICON_SIZE - 16.0)
	next_swatch.visible = false
	next_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_panel.add_child(next_swatch)

func _update_next_label() -> void:
	if next_icon == null:
		return
	var d: Dictionary = UnitDatabase.get_def(next_id)
	var art_path := UnitDatabase.get_art_path(next_id)
	if art_path != "":
		next_icon.texture = load(art_path) as Texture2D
		next_icon.visible = true
		next_swatch.visible = false
	else:
		next_icon.visible = false
		next_swatch.visible = true
		next_swatch.add_theme_stylebox_override("panel",
			UIStyle.swatch_box(d.get("color", UIStyle.ACCENT_GOLD)))

func _unhandled_input(event: InputEvent) -> void:
	# Opening the menu from the keyboard; closing it again is handled by the
	# overlay itself, which is the node still running once the tree is paused.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		_on_pause_pressed()
		return

	if not GameManager.is_playing():
		return

	# The field gets first refusal. A press that landed on a unit already standing
	# out there is about that unit -- selling it or picking it up -- and everything
	# below is about the piece hanging over the tray.
	if _handle_field_input(event):
		return

	if current_object == null or not is_instance_valid(current_object):
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			_update_current_x(event.position.x)
		elif dragging:
			dragging = false
			_release_current()
	elif event is InputEventScreenDrag:
		if dragging:
			_update_current_x(event.position.x)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				_update_current_x(event.position.x)
			elif dragging:
				dragging = false
				_release_current()
	elif event is InputEventMouseMotion:
		if dragging:
			_update_current_x(event.position.x)

func _update_current_x(x: float) -> void:
	var radius: float = current_object.get_stats().get("radius", 34.0)
	var min_x: float = MERGE_LEFT + radius
	var max_x: float = MERGE_RIGHT - radius
	current_object.global_position.x = clamp(x, min_x, max_x)

func _release_current() -> void:
	current_object.held = false
	current_object.freeze = false
	current_object = null
	Sfx.drop()
	_spawn_current_from_next()

# ---------------------------------------------------------------------- send

# How many units the player may field at once, and how many are already out
# there -- counting the ones still flying to their slot, so a double press
# cannot overshoot the limit.
func _defender_limit() -> int:
	return mini(GameManager.unit_slots, MAX_DEFENDERS)

func _defenders_on_field() -> int:
	return CombatManager.defenders.size() + _pending_sends.size()

func _unit_level(id: String) -> int:
	return int(UnitDatabase.get_def(id).get("level", 0))

# Best first. With only a handful of slots on the field, which pieces go out
# matters as much as how many: a knight is worth the three warriors it was made
# from, so the tray is emptied in order of level and the last slots are never
# spent on a warrior while a knight is still sitting in the tray. Ties fall to
# whatever the tray hands back -- between two of the same unit there is nothing
# to choose.
func _deployable_pieces() -> Array:
	var out: Array = []
	for o in get_tree().get_nodes_in_group("merge_objects"):
		if o is MergeObject and o.is_deployable():
			out.append(o)
	out.sort_custom(func(a: MergeObject, b: MergeObject) -> bool:
		return _unit_level(a.unit_id) > _unit_level(b.unit_id))
	return out

# A piece with nowhere to stand is left in the tray rather than consumed: a full
# board, or every lane being full for its role, is a reason to hold it back and
# not to lose it.
func _on_send_pressed() -> void:
	if not GameManager.is_playing():
		return

	for o in _deployable_pieces():
		if _defenders_on_field() >= _defender_limit():
			break
		var role: String = UnitDatabase.get_def(o.unit_id).get("role", "melee")
		var lane: int = _pick_lane(role)
		if lane < 0:
			continue
		var slot: int = _free_slot(lane, role)
		if slot < 0:
			continue

		_pending_sends.append({"lane": lane, "role": role, "slot": slot})

		o.held = true
		o.merged = true
		o.freeze = true
		o.collision_layer = 0
		o.collision_mask = 0
		Sfx.send()
		_animate_send(o, lane, slot)

func _animate_send(o: MergeObject, lane: int, slot: int) -> void:
	var id: String = o.unit_id
	var role: String = UnitDatabase.get_def(id).get("role", "melee")
	var target: Vector2 = _lane_slot_position(lane, role, slot)

	var tw := create_tween()
	tw.tween_property(o, "global_position", target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(o):
			o.queue_free()
		_clear_pending(lane, role, slot)
		_spawn_defender(id, lane, slot)
		# The very first successful send of the save file's life gets a small
		# landing puff -- every one after it is silent, the way the game
		# already leaves this moment otherwise.
		if MetaManager.consume_first_send():
			var fx := ImpactEffect.new()
			ground_layer.add_child(fx)
			fx.global_position = target
			fx.play_ground_slam(UIStyle.ACCENT_GOLD, 0.8)
	)

func _clear_pending(lane: int, role: String, slot: int) -> void:
	var line: String = _lane_line(role)
	for i in range(_pending_sends.size()):
		var p: Dictionary = _pending_sends[i]
		if int(p["lane"]) == lane and _lane_line(String(p["role"])) == line \
				and int(p["slot"]) == slot:
			_pending_sends.remove_at(i)
			return

# Answers with the body it put on the field, or null if it could not: the hero
# spawn needs to keep hold of the one it asked for, and picking it back out of
# CombatManager's list afterwards is a guess that is wrong exactly when this
# returned early.
func _spawn_defender(id: String, lane: int, slot: int) -> Defender:
	if CombatManager.defenders.size() >= _defender_limit():
		return null
	var role: String = UnitDatabase.get_def(id).get("role", "melee")
	# The slot was reserved when the unit was dispatched and released a moment
	# ago, so it is normally still ours. Somebody standing in it anyway means the
	# reservation was lost somewhere -- take any free slot rather than land on
	# top of them, and give up if the lane filled up during the flight.
	if _slot_taken(lane, role, slot):
		slot = _free_slot(lane, role)
		if slot < 0:
			return null

	var d := Defender.new()
	d.setup(id)
	d.lane = lane
	d.slot = slot
	combat_layer.add_child(d)
	d.global_position = _lane_slot_position(lane, role, slot)
	# Faces out of the ring, which is where the enemies are: the drawn frames
	# are painted facing right and have to be mirrored on the far side.
	d.set_facing(d.global_position - ARENA_CENTER)
	CombatManager.add_defender(d)
	return d

# ------------------------------------------------- units already on the field
#
# SEND decides which lane a unit walks out to, and until now that was the last
# word on it: a warrior dropped on the north road stood there until something
# killed him. The player has two things left to say to a unit once it is out
# there, and both are said to the unit itself rather than to a menu:
#
#   press and let go  -- it offers its price, and the price is taken by pressing
#                        it a second time. Two presses rather than one because a
#                        misplaced thumb should never cost a paladin.
#   press and drag    -- it comes up off the ground and can be set down in any
#                        free standing spot on its own ring.
#
# Only the field works this way. The pieces down in the tray are physics bodies
# in the middle of a merge with their own rules -- see MergeObject -- and nothing
# in this section ever looks at them.

# How far the finger has to travel before a press stops being a tap and becomes a
# carry. Anything under this is still a tap, so a thumb that rolls a few pixels
# on its way up sells the unit rather than shuffling it half a slot sideways.
const MOVE_DRAG_SLOP := 22.0

# The carried unit rides this far above the finger, so the thumb is not parked on
# top of the one thing the player is trying to aim.
const CARRY_LIFT := 60.0

# How close to a standing spot the unit has to be let go for it to land there.
# Wider than the gap between two neighbouring spots, so there is no dead ground
# between them -- but bounded, so that letting go out over the tray or off in a
# corner walks the unit back where it came from. That is what makes an accidental
# pickup cost nothing.
const MOVE_SNAP_RADIUS := 200.0

# The footprint drawn on a standing spot, and how far below the unit's own middle
# the circle is laid so it reads as ground rather than as a belt.
const SLOT_RING_RADIUS := 62.0
const SLOT_RING_DROP := 28.0

# The unit comes down where it was let go and walks the last of the way into its
# spot rather than snapping into it. It stays in hand until it lands: nothing
# should square up against a body still coming down.
const CARRY_LAND_TIME := 0.24

# A circle laid flat on the ground: one on every spot a carried unit could be set
# down in, and one under the unit whose price is showing. Drawn rather than built
# out of nodes -- there can be a dozen on the floor at once -- squashed onto the
# ground plane by the same factor as every other circle in the game, and added to
# the light rather than painted over it, so it lights the grass it is lying on
# instead of covering it up.
class SlotRing extends Node2D:
	const FLATTEN := 0.42
	const SEGMENTS := 40
	const BREATH := 1.8

	var radius: float = 62.0
	var color: Color = Color(1.0, 0.84, 0.35)

	# 0 is an open spot, 1 is the spot the unit would land in if it were let go
	# now. Tweened between the two, so the aimed ring lights up rather than
	# switching on -- with a dozen of them out there, a hard switch reads as a
	# flicker running around the field as the finger moves.
	var aim: float = 0.0

	var _phase: float = 0.0
	var _aim_tween: Tween = null

	func _init() -> void:
		material = FxUtil.additive()
		# Started somewhere of its own, so the whole set does not breathe as one.
		_phase = randf() * BREATH

	func setup(at: Vector2, p_radius: float, p_color: Color) -> void:
		position = at
		radius = p_radius
		color = p_color

	func set_aimed(on: bool) -> void:
		if _aim_tween != null and _aim_tween.is_valid():
			_aim_tween.kill()
		_aim_tween = create_tween()
		_aim_tween.tween_property(self, "aim", 1.0 if on else 0.0, 0.12)

	# Fades out and goes, so a set of markers leaves the field the way it arrived
	# rather than blinking off it.
	func close() -> void:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.14)
		tw.tween_callback(queue_free)

	func _process(delta: float) -> void:
		_phase += delta
		queue_redraw()

	func _draw() -> void:
		var pts: PackedVector2Array = _ellipse()
		var breath: float = 0.5 + 0.5 * sin(_phase * TAU / BREATH)

		var fill := color
		fill.a = 0.030 + 0.020 * breath + 0.075 * aim
		draw_colored_polygon(pts, fill)

		var edge := color
		edge.a = 0.20 + 0.10 * breath + 0.45 * aim
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, edge, 3.0 + 3.0 * aim, true)

	# draw_circle cannot be squashed onto the ground plane, so the footprint is
	# built as a polygon.
	func _ellipse() -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in range(SEGMENTS):
			var a: float = TAU * i / SEGMENTS
			pts.append(Vector2(cos(a) * radius, sin(a) * radius * FLATTEN))
		return pts

var _touch_defender: Defender = null   # pressed; not yet known to be a tap or a carry
var _touch_start: Vector2 = Vector2.ZERO
var _carried: Defender = null          # actually up off the ground
var _carry_home: Dictionary = {}       # the lane, slot and spot it was picked up from
var _carry_slots: Array = []           # every spot it could be set down in
var _carry_markers: Array = []         # the circle drawn on each of those spots
var _carry_target: int = -1            # which of them it is over right now
var _selected: Defender = null         # the unit whose price is showing
var _selected_ring: SlotRing = null

# Answers with whether the event belonged to the field, which is what stops it
# reaching the tray.
func _handle_field_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		return _field_press(touch.position) if touch.pressed \
			else _field_release(touch.position)
	if event is InputEventScreenDrag:
		return _field_moved((event as InputEventScreenDrag).position)
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return false
		return _field_press(click.position) if click.pressed \
			else _field_release(click.position)
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			return _field_moved(motion.position)
		# The button came up somewhere this window never saw it -- focus lost
		# mid-drag, most often. Whatever was in hand is put down rather than left
		# hanging in the air waiting for a release that is never coming.
		if _carried != null:
			_end_carry(motion.position)
			return true
		_touch_defender = null
		return false
	return false

func _field_press(at: Vector2) -> bool:
	var d: Defender = _defender_at(at)
	if d != null:
		_touch_defender = d
		_touch_start = at
		return true

	# Nothing of ours under the finger. An enemy is the next thing the press
	# could mean, and picking one out is what turns the whole line onto it --
	# tapping the same body again calls the order off.
	var e: Enemy = _enemy_at(at)
	if e != null:
		_clear_selection()
		if CombatManager.focus_target() == e:
			CombatManager.clear_focus()
		else:
			CombatManager.set_focus(e)
		return true

	# A press anywhere else puts an open card away and does nothing more:
	# dismissing it should not also fling the tray piece across the well
	# on the way past.
	if _selected != null:
		_clear_selection()
		return true
	return false

func _field_moved(at: Vector2) -> bool:
	if _carried != null:
		_carry_to(at)
		return true
	if _touch_defender == null:
		return false
	if not is_instance_valid(_touch_defender) or not _touch_defender.is_alive():
		_touch_defender = null
		return false
	if _touch_start.distance_to(at) < MOVE_DRAG_SLOP:
		return true
	_begin_carry(_touch_defender)
	_carry_to(at)
	return true

func _field_release(at: Vector2) -> bool:
	if _carried != null:
		_end_carry(at)
		return true
	var d: Defender = _touch_defender
	_touch_defender = null
	if d == null:
		return false
	if is_instance_valid(d) and d.is_alive():
		# Tapping the same unit again puts its price away -- a second way out of
		# the prompt, and the one a player reaches for without being told.
		if _selected == d:
			_clear_selection()
		else:
			_select_defender(d)
	return true

# The unit under a finger, or null. Nearest wins where two overlap, which on the
# front ring -- three bodies shoulder to shoulder -- they routinely do.
func _defender_at(at: Vector2) -> Defender:
	var best: Defender = null
	var best_dist := INF
	for d in CombatManager.defenders:
		if not is_instance_valid(d) or not d.is_alive() or d.held:
			continue
		var dist: float = at.distance_to(d.global_position)
		if dist > d.tap_radius() or dist >= best_dist:
			continue
		best_dist = dist
		best = d
	return best

# The enemy under a finger, or null. Measured against the drawn body rather than
# the ground it stands on, so a dragon is tapped where it is seen.
func _enemy_at(at: Vector2) -> Enemy:
	var best: Enemy = null
	var best_dist := INF
	for e in CombatManager.enemies:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var dist: float = at.distance_to(e.tap_point())
		if dist > e.tap_radius() or dist >= best_dist:
			continue
		best_dist = dist
		best = e
	return best

# ------------------------------------------------------------------- focusing
#
# The marker that says which body the line has been turned onto. CombatManager
# owns the order itself -- it is the thing every unit reads when it picks a
# target -- and this is the only visible part of it, put up and taken down off
# the one signal so the two can never disagree.

var _focus_marker: FocusMarker = null

func _on_focus_changed(enemy: Enemy) -> void:
	if _focus_marker != null and is_instance_valid(_focus_marker):
		_focus_marker.release()
	_focus_marker = null
	if enemy == null or not is_instance_valid(enemy):
		return
	_focus_marker = FocusMarker.new()
	fx_layer.add_child(_focus_marker)
	_focus_marker.follow(enemy)

# Everything the player had hold of on the field, let go of. Called whenever
# something else takes the screen -- the shop, the pause menu, the upgrade cards,
# the defeat plate -- so nothing is left hanging in the air behind an overlay.
func _release_field_touch() -> void:
	_touch_defender = null
	_clear_selection()
	_cancel_carry()

# Runs with the rest of the frame's housekeeping: the unit a price is showing
# for, or the one in the player's hand, can be killed at any moment by the fight
# going on around it.
func _tick_field_touch() -> void:
	if _touch_defender != null \
			and (not is_instance_valid(_touch_defender) or not _touch_defender.is_alive()):
		_touch_defender = null
	if _carried != null and (not is_instance_valid(_carried) or not _carried.is_alive()):
		_end_carry_state()
	if _selected != null and (not is_instance_valid(_selected) or not _selected.is_alive()):
		_clear_selection()
	elif _selected != null:
		_place_unit_card()
		_refresh_unit_card()

# ------------------------------------------------------- the unit under a finger

func _select_defender(d: Defender) -> void:
	if _selected == d:
		return
	_clear_selection()
	_selected = d

	_refresh_unit_card()
	_place_unit_card()
	unit_card.visible = true
	# Grown out of the unit's head rather than appearing over it: the pivot is the
	# point of the nib, which is the point the card is about.
	unit_card.scale = Vector2(0.6, 0.6)
	unit_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(unit_card, "modulate:a", 1.0, 0.10)
	tw.parallel().tween_property(unit_card, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_selected_ring = _make_slot_ring(
		d.global_position, maxf(d.tap_radius(), SLOT_RING_RADIUS), UIStyle.ACCENT_GOLD)
	_selected_ring.set_aimed(true)

func _clear_selection() -> void:
	_selected = null
	if unit_card != null:
		unit_card.visible = false
	if _selected_ring != null and is_instance_valid(_selected_ring):
		_selected_ring.close()
	_selected_ring = null

# Above the unit if there is room for it and below if there is not. The card is
# most of a phone screen tall, and a soldier holding the north road has nothing
# but HUD above his head -- pinning it to the top edge there would bury the unit
# the player is reading about under the thing they opened to read.
func _place_unit_card() -> void:
	var at: Vector2 = _selected.global_position
	var reach: float = _selected.tap_radius()
	var x: float = clampf(at.x - CARD_SIZE.x * 0.5,
		CARD_EDGE, VIEW_W - CARD_SIZE.x - CARD_EDGE)

	var above: float = at.y - reach - CARD_GAP - CARD_SIZE.y
	if above >= CARD_TOP_LIMIT:
		unit_card.position = Vector2(x, above)
		card_nib.position = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
		card_nib.scale = Vector2(1.0, 1.0)
		unit_card.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y + CARD_GAP)
		return

	# Flipped rather than moved: the nib is the whole reason the card is
	# unambiguous, so it turns over and keeps pointing at the same body.
	unit_card.position = Vector2(x, minf(at.y + reach + CARD_GAP,
		VIEW_H - CARD_SIZE.y - CARD_EDGE))
	card_nib.position = Vector2(CARD_SIZE.x * 0.5, 0.0)
	card_nib.scale = Vector2(1.0, -1.0)
	unit_card.pivot_offset = Vector2(CARD_SIZE.x * 0.5, -CARD_GAP)

func _on_sell_pressed() -> void:
	var d: Defender = _selected
	_clear_selection()
	if d == null or not is_instance_valid(d) or not d.is_alive():
		return
	if not GameManager.is_playing() or d.is_hero():
		return
	# Read before the sale: the unit is on its way out by the time it returns, and
	# the gold has to come from where the body was standing.
	var at: Vector2 = d.global_position
	var price: int = UnitDatabase.get_sell_price(d.unit_id)
	d.sell()
	_pay_out(price, at)

# The other way off the field: back to the tray as the same piece it was sent
# out as, rather than into gold. What frees the lane slot is the same `died`
# signal a sale sends -- CombatManager unhooks it from combat and its totem the
# same way either way -- the only difference is what happens to the unit
# itself afterward.
func _on_recall_pressed() -> void:
	var d: Defender = _selected
	_clear_selection()
	if d == null or not is_instance_valid(d) or not d.is_alive():
		return
	# A hero has no piece in the tray to go back to -- there is no merge that
	# ever produced it and none that could produce it again.
	if not GameManager.is_playing() or d.is_hero():
		return
	var unit_id: String = d.unit_id
	d.recall()
	_drop_bought_piece(unit_id)

# --------------------------------------------------------------------- carrying

func _begin_carry(d: Defender) -> void:
	_clear_selection()
	_touch_defender = null
	_carried = d
	_carry_home = {"lane": d.lane, "slot": d.slot, "at": d.global_position}
	d.held = true
	# Whatever was fighting it lets go: an enemy should look for something else to
	# hit rather than follow a soldier across the field by the scruff of his neck.
	CombatManager.release_defender_claims(d)
	# A shaman's circle belongs where the shaman is. The post goes back into the
	# ground here and is raised again wherever he ends up standing.
	if d.role == "support":
		CombatManager.uproot_totem(d)
	d.lift()
	_build_carry_markers(d)

# Every spot the carried unit could be set down in, drawn on the floor -- its
# own ring only, the same rule of the formation as ever. A free spot is still
# gold; a spot already standing full is offered too, in purple, because
# landing there no longer bounces the carried unit back -- it changes places
# with whoever is standing on it. Only a slot a send is still in flight toward
# is left off both lists: there is nothing there yet to swap with, and
# nowhere free to land until it arrives.
func _build_carry_markers(d: Defender) -> void:
	_carry_slots = []
	_carry_markers = []
	_carry_target = -1
	var radius: float = maxf(d.tap_radius(), SLOT_RING_RADIUS)
	for lane in range(LANE_ANGLES.size()):
		for i in range(_lane_capacity(d.role)):
			if _pending_send_blocks(lane, d.role, i):
				continue
			var occupant: Defender = _defender_in_slot(lane, d.role, i, d)
			var at: Vector2 = _lane_slot_position(lane, d.role, i)
			_carry_slots.append({"lane": lane, "slot": i, "at": at, "occupant": occupant})
			var color: Color = UIStyle.ACCENT_PURPLE if occupant != null else UIStyle.ACCENT_GOLD
			_carry_markers.append(_make_slot_ring(at, radius, color))

# The defender already standing in a lane/slot, ignoring whichever body is
# presently in the player's hand -- the same match _slot_taken makes, just
# handing back who rather than whether.
func _defender_in_slot(lane: int, role: String, slot: int, ignore: Defender) -> Defender:
	var line: String = _lane_line(role)
	for def in CombatManager.defenders:
		if def == ignore:
			continue
		if is_instance_valid(def) and def.is_alive() and def.lane == lane \
				and _lane_line(def.role) == line and def.slot == slot:
			return def
	return null

func _pending_send_blocks(lane: int, role: String, slot: int) -> bool:
	var line: String = _lane_line(role)
	for p in _pending_sends:
		if int(p["lane"]) == lane and _lane_line(String(p["role"])) == line \
				and int(p["slot"]) == slot:
			return true
	return false

func _carry_to(at: Vector2) -> void:
	if not is_instance_valid(_carried):
		_end_carry_state()
		return
	var point: Vector2 = _carry_point(at)
	_carried.global_position = point
	_aim_carry(_slot_index_near(point))

# Where the unit itself is while the finger is at `at`: held clear of the thumb,
# and kept inside the arena so a carried body is never drawn over the tray it can
# never be put down in.
func _carry_point(at: Vector2) -> Vector2:
	return Vector2(
		clampf(at.x, ARENA_AREA_LEFT + 24.0, ARENA_AREA_RIGHT - 24.0),
		clampf(at.y - CARRY_LIFT, ARENA_AREA_TOP + 24.0, ARENA_AREA_BOTTOM - 24.0))

func _slot_index_near(point: Vector2) -> int:
	var best := -1
	var best_dist := MOVE_SNAP_RADIUS
	for i in range(_carry_slots.size()):
		var dist: float = point.distance_to(_carry_slots[i]["at"] as Vector2)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best

func _aim_carry(index: int) -> void:
	if index == _carry_target:
		return
	_carry_target = index
	for i in range(_carry_markers.size()):
		var ring: SlotRing = _carry_markers[i]
		if is_instance_valid(ring):
			ring.set_aimed(i == index)

func _end_carry(at: Vector2) -> void:
	var d: Defender = _carried
	var lane: int = int(_carry_home.get("lane", 0))
	var slot: int = int(_carry_home.get("slot", 0))
	var to: Vector2 = _carry_home.get("at", ARENA_CENTER)
	var home_lane: int = lane
	var home_slot: int = slot
	var home_at: Vector2 = to
	# Nowhere near a standing spot: it goes back where it was picked up from.
	var index: int = _slot_index_near(_carry_point(at)) if is_instance_valid(d) else -1
	var occupant: Defender = null
	if index >= 0:
		var target: Dictionary = _carry_slots[index]
		lane = int(target["lane"])
		slot = int(target["slot"])
		to = target["at"]
		occupant = target.get("occupant") as Defender

	_end_carry_state()
	if d == null or not is_instance_valid(d):
		return
	if occupant != null and is_instance_valid(occupant) and occupant.is_alive():
		_swap_defenders(d, occupant, lane, slot, to, home_lane, home_slot, home_at)
	else:
		_land_defender(d, lane, slot, to)

# Dropped on a spot that already has someone standing on it: the two change
# places rather than the drop bouncing back to where the carried unit started.
# Whoever was standing there leaves the same way the carried unit arrived --
# claims let go, a totem uprooted if it planted one, lifted and landed -- just
# handed both bodies instead of the one the player's own hand was on.
func _swap_defenders(d: Defender, other: Defender, d_lane: int, d_slot: int, d_at: Vector2,
		other_lane: int, other_slot: int, other_at: Vector2) -> void:
	CombatManager.release_defender_claims(other)
	if other.role == "support":
		CombatManager.uproot_totem(other)
	other.held = true
	other.lift()
	_land_defender(other, other_lane, other_slot, other_at)
	_land_defender(d, d_lane, d_slot, d_at)

# Puts whatever is in hand back down where it started, whatever the reason: the
# shop opening, the wave ending, the game being lost out from under it.
func _cancel_carry() -> void:
	var d: Defender = _carried
	var home: Dictionary = _carry_home
	_end_carry_state()
	if d == null or not is_instance_valid(d):
		return
	_land_defender(d, int(home.get("lane", 0)), int(home.get("slot", 0)),
		home.get("at", d.global_position))

func _end_carry_state() -> void:
	_carried = null
	_carry_target = -1
	_carry_slots = []
	for ring in _carry_markers:
		if is_instance_valid(ring):
			ring.close()
	_carry_markers = []

# The lane and slot are claimed the instant the finger comes up, so a SEND pressed
# in the same breath cannot aim at the spot this unit is landing in. The body
# itself takes a moment longer to get there.
func _land_defender(d: Defender, lane: int, slot: int, to: Vector2) -> void:
	d.lane = lane
	d.slot = slot
	d.settle()
	var tw := d.create_tween()
	tw.tween_property(d, "global_position", to, CARRY_LAND_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(d):
			return
		d.held = false
		# Faces out of the ring, which is where the enemies are -- the same rule a
		# freshly sent unit lands under.
		d.set_facing(to - ARENA_CENTER)
	)

func _make_slot_ring(at: Vector2, radius: float, color: Color) -> SlotRing:
	var ring := SlotRing.new()
	ground_layer.add_child(ring)
	ring.setup(at + Vector2(0, SLOT_RING_DROP), radius, color)
	return ring

# ------------------------------------------------------------------- unit card
#
# What a soldier on the field has to say for itself, hung over its head with a
# nib pointing back down at it so there is never a question about which one is
# being talked about.
#
# It began as a price tag and nothing else, which was fine while a unit was
# nothing but its type -- every knight was every other knight, and the only
# thing worth knowing was what one sold for. Levels changed that: this
# particular archer has held the east road for eleven waves and hits half again
# as hard as the one that landed a minute ago, and none of that is visible on
# the field. So the card carries the numbers that actually differ from body to
# body -- what it hits for, how far, how fast, how much it can take, and how
# close it is to its next level -- and the price is one line of it rather than
# the whole thing.
#
# The values are refreshed every frame the card is open rather than pushed at it
# when something changes. A unit is being shot at, healed, hasted and levelled
# while the player is reading it, and a card that told the truth only at the
# moment it opened would be wrong within a second of being useful.

const CARD_SIZE := Vector2(520.0, 312.0)
const CARD_GAP := 26.0        # between the unit's head and the near edge of the card
const CARD_PAD := 22.0
const CARD_EDGE := 12.0       # closest the card is allowed to the screen edge
# The top HUD -- the wave plate, the hearts, the gold and unit chips -- owns
# everything above this. A card that reached into it would be read through the
# fortress health, so a unit with no room over its head takes the card below
# instead of pinning it to the top of the screen.
const CARD_TOP_LIMIT := 282.0
const CARD_COIN := 40.0

# The four numbers, in the order they are laid out: left column top to bottom,
# then right column. "caption" is what the player reads; the key is what
# _refresh_unit_card fills in.
const CARD_STATS := [
	{"key": "dmg", "caption": "DMG"},
	{"key": "spd", "caption": "SPD"},
	{"key": "rng", "caption": "RNG"},
	{"key": "hp", "caption": "HP"},
]

var unit_card: Control
var card_nib: Polygon2D
var card_name_label: Label
var card_level_label: Label
var card_xp_track: Panel
var card_xp_fill: Panel
var card_xp_label: Label
var card_stat_values: Dictionary = {}
var sell_button: Button
var sell_price_label: Label
var sell_caption: Label
var sell_price_row: Control
var recall_button: Button
var recall_caption: Label
var ability_button: Button
var ability_name_label: Label
var ability_state_label: Label
# What stands in place of the whole button row on a hero's card: a hero is
# never sold, never recalled and carries a passive instead of a cast, so the
# three buttons have nothing to say and this says what it does instead.
var hero_note: Label

func _build_unit_card(root: Control) -> void:
	unit_card = Control.new()
	unit_card.size = CARD_SIZE
	# The point of the nib, which is the point the whole card is about.
	unit_card.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y + CARD_GAP)
	unit_card.visible = false
	unit_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(unit_card)

	card_nib = Polygon2D.new()
	card_nib.polygon = PackedVector2Array([
		Vector2(-18, -2), Vector2(18, -2), Vector2(0, 22)])
	card_nib.position = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	card_nib.color = UIStyle.ACCENT_GOLD
	unit_card.add_child(card_nib)

	# Dark glass with a gold rim rather than a solid slab: the card stands over
	# the fight and has to stay readable against whatever is moving under it. It
	# stops mouse events as well, so a tap that lands on the card is never also
	# a tap on the field that dismisses it.
	var back := Panel.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.add_theme_stylebox_override("panel",
		UIStyle.panel_box(UIStyle.PANEL_BG, UIStyle.ACCENT_GOLD, 26, 3))
	unit_card.add_child(back)

	_build_card_header()
	_build_card_xp_bar()
	_build_card_stats()
	_build_card_buttons()

const CARD_HEAD_Y := 14.0
const CARD_HEAD_H := 44.0
const CARD_LEVEL_W := 160.0

func _build_card_header() -> void:
	card_name_label = Label.new()
	card_name_label.position = Vector2(CARD_PAD, CARD_HEAD_Y)
	card_name_label.size = Vector2(
		CARD_SIZE.x - CARD_PAD * 2.0 - CARD_LEVEL_W, CARD_HEAD_H)
	card_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_name_label.add_theme_font_size_override("font_size", 32)
	card_name_label.clip_text = true
	card_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(card_name_label, UIStyle.TEXT_LIGHT, 5)
	unit_card.add_child(card_name_label)

	card_level_label = Label.new()
	card_level_label.position = Vector2(
		CARD_SIZE.x - CARD_PAD - CARD_LEVEL_W, CARD_HEAD_Y)
	card_level_label.size = Vector2(CARD_LEVEL_W, CARD_HEAD_H)
	card_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_level_label.add_theme_font_size_override("font_size", 36)
	card_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(card_level_label, UIStyle.ACCENT_GOLD, 6)
	unit_card.add_child(card_level_label)

# The bar is the one thing on the card that says a unit is going somewhere, so
# it gets a whole row rather than being another number in the grid.
const CARD_XP_Y := 62.0
const CARD_XP_H := 30.0
# Bronze rather than the HUD's gold. The count is written across the middle of
# the bar, and full-brightness gold under white text leaves the one line on the
# card that actually moves as the least readable thing on it.
const CARD_XP_FILL := Color(0.72, 0.50, 0.13)

func _build_card_xp_bar() -> void:
	card_xp_track = Panel.new()
	card_xp_track.position = Vector2(CARD_PAD, CARD_XP_Y)
	card_xp_track.size = Vector2(CARD_SIZE.x - CARD_PAD * 2.0, CARD_XP_H)
	card_xp_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_xp_track.add_theme_stylebox_override("panel",
		UIStyle.swatch_box(Color(0.05, 0.05, 0.09, 0.92), 13))
	unit_card.add_child(card_xp_track)

	card_xp_fill = Panel.new()
	card_xp_fill.size = Vector2(0.0, CARD_XP_H)
	card_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_xp_fill.add_theme_stylebox_override("panel",
		UIStyle.swatch_box(CARD_XP_FILL, 13))
	card_xp_track.add_child(card_xp_fill)

	card_xp_label = Label.new()
	card_xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_xp_label.add_theme_font_size_override("font_size", 21)
	card_xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Outlined rather than shadowed: it is read over the dark track at one end of
	# the bar and over the gold fill at the other, and nothing flat stays legible
	# across both.
	UIStyle.apply_heading(card_xp_label, UIStyle.TEXT_LIGHT, 5)
	card_xp_track.add_child(card_xp_label)

# Two columns of two. A caption in muted text with the number beside it in full
# brightness, so the eye lands on the figures and the labels stay out of the way.
const CARD_STAT_Y := 104.0
const CARD_STAT_ROW := 44.0
const CARD_CAPTION_W := 82.0

func _build_card_stats() -> void:
	var col_w: float = (CARD_SIZE.x - CARD_PAD * 2.0) / 2.0
	for i in range(CARD_STATS.size()):
		var spec: Dictionary = CARD_STATS[i]
		var x: float = CARD_PAD + float(i / 2) * col_w
		var y: float = CARD_STAT_Y + float(i % 2) * CARD_STAT_ROW

		var caption := Label.new()
		caption.text = String(spec["caption"])
		caption.position = Vector2(x, y)
		caption.size = Vector2(CARD_CAPTION_W, CARD_STAT_ROW)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 23)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIStyle.apply_body_text(caption, UIStyle.TEXT_MUTED)
		unit_card.add_child(caption)

		var value := Label.new()
		value.text = "-"
		value.position = Vector2(x + CARD_CAPTION_W, y)
		value.size = Vector2(col_w - CARD_CAPTION_W - 10.0, CARD_STAT_ROW)
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 29)
		value.clip_text = true
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIStyle.apply_heading(value, UIStyle.TEXT_LIGHT, 4)
		unit_card.add_child(value)

		card_stat_values[String(spec["key"])] = value

# The three things the player can do from here. Selling has been possible
# since the card was a price tag; recall sits next to it as the other way off
# the field -- back to the tray instead of into gold, for the unit worth
# keeping rather than cashing out; the ability is what twenty levels buys, and
# it takes what is left of the row rather than replacing anything so the card
# never changes shape.
const CARD_BTN_Y := 200.0
const CARD_BTN_H := 88.0
const CARD_BTN_GAP := 14.0
const CARD_SELL_W := 124.0
const CARD_RECALL_W := 124.0

func _build_card_buttons() -> void:
	var inner: float = CARD_SIZE.x - CARD_PAD * 2.0

	sell_button = Button.new()
	sell_button.text = ""
	sell_button.position = Vector2(CARD_PAD, CARD_BTN_Y)
	sell_button.size = Vector2(CARD_SELL_W, CARD_BTN_H)
	sell_button.pressed.connect(_on_sell_pressed)
	UIStyle.apply_button_style(sell_button, UIStyle.ACCENT_RED.darkened(0.25), 30, 22)
	unit_card.add_child(sell_button)

	sell_caption = Label.new()
	sell_caption.text = "SELL"
	sell_caption.position = sell_button.position + Vector2(0.0, 10.0)
	sell_caption.size = Vector2(CARD_SELL_W, 28.0)
	sell_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sell_caption.add_theme_font_size_override("font_size", 24)
	sell_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_body_text(sell_caption, UIStyle.TEXT_LIGHT)
	unit_card.add_child(sell_caption)

	# Coin and number as one centred group, so a 1 and a 20 both sit in the
	# middle of the button instead of the number wandering as the price grows.
	var row := HBoxContainer.new()
	row.position = sell_button.position + Vector2(0.0, 40.0)
	row.size = Vector2(CARD_SELL_W, 44.0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_card.add_child(row)
	sell_price_row = row

	var coin_tex: Texture2D = UIStyle.icon_texture("icon_coin")
	if coin_tex != null:
		var coin := TextureRect.new()
		coin.texture = coin_tex
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.custom_minimum_size = Vector2(CARD_COIN, CARD_COIN)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(coin)

	sell_price_label = Label.new()
	sell_price_label.text = "0"
	sell_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sell_price_label.add_theme_font_size_override("font_size", 38)
	sell_price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(sell_price_label, UIStyle.ACCENT_GOLD, 6)
	row.add_child(sell_price_label)

	var recall_x: float = CARD_PAD + CARD_SELL_W + CARD_BTN_GAP
	recall_button = Button.new()
	recall_button.text = ""
	recall_button.position = Vector2(recall_x, CARD_BTN_Y)
	recall_button.size = Vector2(CARD_RECALL_W, CARD_BTN_H)
	recall_button.pressed.connect(_on_recall_pressed)
	UIStyle.apply_button_style(recall_button, UIStyle.ACCENT_TEAL.darkened(0.15), 30, 22)
	unit_card.add_child(recall_button)

	recall_caption = Label.new()
	recall_caption.text = "RECALL"
	recall_caption.position = recall_button.position
	recall_caption.size = Vector2(CARD_RECALL_W, CARD_BTN_H)
	recall_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recall_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recall_caption.add_theme_font_size_override("font_size", 24)
	recall_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_body_text(recall_caption, UIStyle.TEXT_LIGHT)
	unit_card.add_child(recall_caption)

	var ability_x: float = recall_x + CARD_RECALL_W + CARD_BTN_GAP
	var ability_w: float = inner - CARD_SELL_W - CARD_RECALL_W - CARD_BTN_GAP * 2.0

	ability_button = Button.new()
	ability_button.text = ""
	ability_button.position = Vector2(ability_x, CARD_BTN_Y)
	ability_button.size = Vector2(ability_w, CARD_BTN_H)
	ability_button.pressed.connect(_on_ability_pressed)
	UIStyle.apply_button_style(ability_button, UIStyle.ACCENT_PURPLE.darkened(0.15), 30, 22)
	unit_card.add_child(ability_button)

	ability_name_label = Label.new()
	ability_name_label.position = ability_button.position + Vector2(0.0, 12.0)
	ability_name_label.size = Vector2(ability_w, 34.0)
	ability_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ability_name_label.add_theme_font_size_override("font_size", 27)
	ability_name_label.clip_text = true
	ability_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(ability_name_label, UIStyle.TEXT_LIGHT, 4)
	unit_card.add_child(ability_name_label)

	ability_state_label = Label.new()
	ability_state_label.position = ability_button.position + Vector2(0.0, 46.0)
	ability_state_label.size = Vector2(ability_w, 32.0)
	ability_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ability_state_label.add_theme_font_size_override("font_size", 23)
	ability_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_body_text(ability_state_label, UIStyle.TEXT_MUTED)
	unit_card.add_child(ability_state_label)

	# Laid across the whole row the three buttons occupy, and shown only when
	# they are all hidden -- see _refresh_card_actions.
	hero_note = Label.new()
	hero_note.position = Vector2(CARD_PAD, CARD_BTN_Y)
	hero_note.size = Vector2(inner, CARD_BTN_H)
	hero_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	hero_note.add_theme_font_size_override("font_size", 25)
	hero_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_note.visible = false
	UIStyle.apply_body_text(hero_note, UIStyle.ACCENT_GOLD)
	unit_card.add_child(hero_note)

# Everything on the card that can change while it is open, which is nearly all
# of it. Called once when the card opens and once a frame after that.
func _refresh_unit_card() -> void:
	var d: Defender = _selected
	if d == null or not is_instance_valid(d) or unit_card == null:
		return

	card_name_label.text = String(UnitDatabase.get_def(d.unit_id).get("name", d.unit_id))
	card_level_label.text = "LV %d" % d.unit_level

	var need: int = d.xp_to_next()
	if need <= 0:
		card_xp_fill.size.x = card_xp_track.size.x
		card_xp_label.text = "MAX LEVEL  -  %d KILLS" % d.kills
	else:
		card_xp_fill.size.x = card_xp_track.size.x \
			* clampf(float(d.xp) / float(need), 0.0, 1.0)
		card_xp_label.text = "%d / %d XP  -  %d KILLS" % [d.xp, need, d.kills]

	# Attacks per second rather than the gap between them: a bigger number is a
	# better number everywhere else on the card and it should be here too. It is
	# the rate the unit is actually swinging at, totems and chills included.
	var per_second: float = 1.0 / maxf(d.effective_interval(), 0.001)
	card_stat_values["dmg"].text = _card_number(d.damage)
	card_stat_values["spd"].text = "%.2f/s" % per_second
	card_stat_values["rng"].text = "%d" % int(round(d.attack_range))
	# Rounded up so a unit one point from death never reads as already dead, and
	# clamped so it never reads as over full: the two ends round differently and
	# a level that lands on a half point would otherwise show 161/160.
	var shown_max: int = int(round(d.max_hp))
	card_stat_values["hp"].text = "%d/%d" % [clampi(int(ceil(d.hp)), 0, shown_max), shown_max]

	sell_price_label.text = str(UnitDatabase.get_sell_price(d.unit_id))
	_refresh_card_actions(d)

# What the bottom of the card offers. Every merged unit gets the same three
# buttons; a hero gets none of them and a line about what it does instead --
# it was never bought, cannot be put back in a tray it never came out of, and
# what it brings is a passive rather than a cast.
func _refresh_card_actions(d: Defender) -> void:
	var hero: bool = d.is_hero()
	sell_button.visible = not hero
	sell_caption.visible = not hero
	sell_price_row.visible = not hero
	recall_button.visible = not hero
	recall_caption.visible = not hero
	hero_note.visible = hero
	if hero:
		# A hero's cast has a button of its own over the shop and is not put on
		# the card as well: one blow reachable from two places is one place too
		# many to look during a wave. What the card says instead is what the
		# passive does and where the cast stands, which is the part the player
		# came here to read.
		ability_button.visible = false
		ability_name_label.visible = false
		ability_state_label.visible = false
		hero_note.text = _hero_note_text(d)
		return
	_refresh_ability_button(d)

func _hero_note_text(d: Defender) -> String:
	var passive: String = String(UnitDatabase.get_def(d.unit_id).get("desc", ""))
	var spec: Dictionary = d.ability_def()
	if spec.is_empty():
		return passive
	var name: String = String(spec.get("name", "ABILITY"))
	if not d.ability_unlocked():
		return "%s\n%s at level %d" % [passive, name, d.ability_level()]
	var left: float = d.ability_cooldown_left()
	if left > 0.0:
		return "%s\n%s in %ds" % [passive, name, int(ceil(left))]
	return "%s\n%s READY" % [passive, name]

# Damage is the one stat that is routinely below ten, where a rounded figure
# hides the whole difference between two levels.
func _card_number(v: float) -> String:
	return "%.0f" % v if v >= 10.0 else "%.1f" % v

func _refresh_ability_button(d: Defender) -> void:
	# A unit that can never have one keeps an empty slot rather than a card of a
	# different shape: two layouts for the same thing reads worse than one button
	# that is plainly not available yet.
	if not d.has_ability():
		ability_button.visible = false
		ability_name_label.visible = false
		ability_state_label.visible = false
		return

	ability_button.visible = true
	ability_name_label.visible = true
	ability_state_label.visible = true

	var spec: Dictionary = d.ability_def()
	ability_name_label.text = String(spec.get("name", "ABILITY"))

	if not d.ability_unlocked():
		ability_button.disabled = true
		ability_name_label.modulate = Color(1, 1, 1, 0.55)
		ability_state_label.text = "LEVEL %d" % Defender.ABILITY_LEVEL
		ability_state_label.add_theme_color_override("font_color", UIStyle.TEXT_MUTED)
		return

	ability_name_label.modulate = Color(1, 1, 1, 1)
	var left: float = d.ability_cooldown_left()
	if left > 0.0:
		ability_button.disabled = true
		ability_state_label.text = "%ds" % int(ceil(left))
		ability_state_label.add_theme_color_override("font_color", UIStyle.TEXT_MUTED)
	else:
		ability_button.disabled = false
		# The one state worth spotting from across the screen without reading it.
		ability_state_label.text = "READY"
		ability_state_label.add_theme_color_override("font_color", UIStyle.ACCENT_GOLD)

func _on_ability_pressed() -> void:
	var d: Defender = _selected
	if d == null or not is_instance_valid(d) or not d.is_alive():
		return
	if not GameManager.is_playing():
		return
	CombatManager.cast_ability(d)
	_refresh_unit_card()

# ------------------------------------------------------------------- merges

func _on_unit_created(id: String, pos: Vector2) -> void:
	var obj := MergeObject.new()
	obj.setup(id)
	merge_layer.add_child(obj)
	obj.global_position = pos
	obj.apply_central_impulse(Vector2(0, -200))
	# Topping out a branch gets the bigger star and a second echo burst. Asked of
	# the merge chain rather than of a level number, so adding a tier moves the
	# celebration to the new top instead of firing it twice.
	var is_top_tier: bool = String(UnitDatabase.get_def(id).get("merge_into", "")) == ""
	_play_merge_fx(pos, is_top_tier)

	# What the merge is worth, in the two currencies a screen has: how hard it
	# hits and what note it plays. Both climb with the tier that was made and
	# with the streak it belongs to, so the twentieth wood merge of a run is a
	# tick and reaching a paladin mid-combo is an event.
	var level: int = int(UnitDatabase.get_def(id).get("level", 0))
	var combo: int = MergeManager.combo_count()
	var weight: float = float(level) + minf(6.0, float(maxi(0, combo - 1))) * 0.5
	if is_top_tier:
		Sfx.merge_top(level, combo)
		_shake(6.0 + weight * 1.6, 0.34)
		_hit_stop(0.055, 0.06)
	else:
		Sfx.merge(level, combo)
		_shake(2.0 + weight * 1.5, 0.14 + weight * 0.02)

func _play_merge_fx(pos: Vector2, critical: bool = false) -> void:
	var fx := MergeEffect.new()
	merge_layer.add_child(fx)
	fx.global_position = pos
	if critical:
		# Warm wash over the whole screen on the frame the burst lands.
		fx.impact.connect(_flash_screen)
	fx.play(critical)

func _flash_screen() -> void:
	if screen_flash == null or not _screen_fx_on():
		return
	screen_flash.color = Color(1.0, 0.88, 0.55, 0.24)
	var tw := create_tween()
	tw.tween_property(screen_flash, "color:a", 0.0, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------------- ui

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	# The frame of the window the fight is seen through: the light in the arena
	# falls away toward its edges, which is both what an evening does and what
	# holds the eye on the crossroads everything happens around. First into the
	# layer, so the weather and the HUD are both in front of it.
	lighting.attach_vignette(root, Rect2(
		ARENA_AREA_LEFT, ARENA_AREA_TOP,
		ARENA_AREA_RIGHT - ARENA_AREA_LEFT, ARENA_AREA_BOTTOM - ARENA_AREA_TOP))

	# Below the flash so the cold wash lights the weather too, and below the HUD
	# so nothing important is ever read through falling snow. Only ever one of
	# the two is emitting: the embers start on the beat the snow stops.
	_build_snowfall(root)
	_build_emberfall(root)

	# Added first so it washes over the play field but stays under the HUD.
	screen_flash = ColorRect.new()
	screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_flash.color = Color(1, 1, 1, 0)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flash_mat := CanvasItemMaterial.new()
	flash_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	screen_flash.material = flash_mat
	root.add_child(screen_flash)

	# --- top HUD card: wave counter + fortress HP -----------------------
	# No plate behind the top HUD: the hearts and the wave plate sit straight
	# on the arena. Both carry their own outline and shadow, so they stay
	# readable over the bright grass without a panel to lift them off it.
	var hud_panel := Panel.new()
	hud_panel.position = Vector2(24, 24)
	hud_panel.size = Vector2(VIEW_W - 48, 148)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(hud_panel)

	# The wave counter is the painted plate, so it takes the whole left end of
	# the HUD row and the hearts move over to what is left of it.
	wave_plate = _make_wave_plate(root, WAVE_PLATE_WIDTH)
	wave_plate.position = WAVE_PLATE_POS
	_set_wave_number(wave_plate, 1)

	# No number beside the hearts: ten hearts at ten health each already say
	# what a "100/100" would, and the row is easier to read at a glance.
	_build_heart_row(hud_panel)

	wave_banner_wrap = Control.new()
	wave_banner_wrap.position = WAVE_BANNER_POS
	wave_banner_wrap.size = WAVE_PLATE_SIZE * (WAVE_BANNER_WIDTH / WAVE_PLATE_SIZE.x)
	wave_banner_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_banner_wrap.modulate = Color(1, 1, 1, 0)
	root.add_child(wave_banner_wrap)

	# Same plate again, big, for the announcement that swings in on every wave.
	wave_banner = _make_wave_plate(wave_banner_wrap, WAVE_BANNER_WIDTH)

	_build_next_chip(root)

	# The overflow count, sitting just under the line it belongs to.
	overflow_label = Label.new()
	overflow_label.text = ""
	overflow_label.position = Vector2(0, DANGER_Y + 34.0)
	overflow_label.size = Vector2(VIEW_W, 150)
	overflow_label.pivot_offset = Vector2(VIEW_W, 150) / 2.0
	overflow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overflow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overflow_label.add_theme_font_size_override("font_size", 130)
	overflow_label.visible = false
	overflow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(overflow_label, UIStyle.ACCENT_RED, 12)
	root.add_child(overflow_label)

	_build_send_button(root)
	_build_shop(root)
	# Over the fight but under every overlay: a card hanging on a soldier has no
	# business showing through the shop or the defeat plate.
	_build_unit_card(root)

	_build_defeat_panel(root)

	_build_upgrade_panel(root)
	_build_merge_upgrade_panel(root)
	_build_blessing_panel(root)
	_build_coin_chip(root)
	_build_units_chip(root)
	_build_winter_banner(root)
	_build_lava_banner(root)
	_build_retreat_ui(root)
	_build_pause_ui(root)

	_on_fortress_hp_changed(fortress.hp, fortress.max_hp)

# ----------------------------------------------------------------- wave plate

# The wave counter is a painting, not a label. art/wave_plate.png carries the
# word WAVE and leaves a gap to its right, and the number is spelled into that
# gap with digits cut from art/wave_digits.png -- both cut out of the raw
# art/wave.png and art/numbers.png sheets, so the counter reads as one carving
# rather than a font sitting on top of a picture.
const WAVE_PLATE_ART := "res://art/wave_plate.png"
const WAVE_DIGIT_ART := "res://art/wave_digits.png"
const WAVE_PLATE_SIZE := Vector2(1770.0, 657.0)

const WAVE_PLATE_POS := Vector2(24.0, 6.0)
const WAVE_PLATE_WIDTH := 470.0
const WAVE_BANNER_POS := Vector2(130.0, 408.0)
const WAVE_BANNER_WIDTH := 820.0

# Where each digit sits on the strip, 0 through 9. Every cut is the full 96
# height of the sheet and only as wide as the digit's own ink.
const WAVE_DIGIT_H := 96.0
const WAVE_DIGIT_CUTS := [
	Rect2(9, 0, 73, 96), Rect2(110, 0, 56, 96), Rect2(189, 0, 82, 96),
	Rect2(283, 0, 77, 96), Rect2(370, 0, 88, 96), Rect2(468, 0, 76, 96),
	Rect2(558, 0, 80, 96), Rect2(653, 0, 74, 96), Rect2(740, 0, 83, 96),
	Rect2(835, 0, 77, 96),
]

# The gap, measured off the plate in its own pixels. The number is centred in
# it at the same cap height as the painted letters, and only shrinks once it
# grows wide enough to reach the ornament on the right.
const WAVE_NUM_CENTER := Vector2(1218.0, 412.0)
const WAVE_NUM_MAX_W := 207.0
const WAVE_NUM_HEIGHT := 155.0
const WAVE_NUM_TRACKING := 0.08

func _make_wave_plate(parent: Control, plate_width: float) -> Control:
	var scale_factor: float = plate_width / WAVE_PLATE_SIZE.x

	var holder := Control.new()
	holder.size = WAVE_PLATE_SIZE * scale_factor
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)

	var plate := TextureRect.new()
	plate.texture = load(WAVE_PLATE_ART)
	# Linear, not the nearest the rest of the art uses: the plate and its digits
	# are drawn smaller than they are painted, and nearest crawls on the vines
	# and the thin gold frame when it is shrunk.
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Without this the control's minimum size is the texture's own, and the
	# plate ignores the size it is given.
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.size = holder.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(plate)

	# The digits are placed in the plate's own pixels and the whole group is
	# scaled, so one set of measurements serves the HUD plate and the big
	# banner alike.
	var digits := Control.new()
	digits.name = "Digits"
	digits.size = WAVE_PLATE_SIZE
	digits.scale = Vector2.ONE * scale_factor
	digits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(digits)
	return holder

func _set_wave_number(holder: Control, value: int) -> void:
	if holder == null:
		return
	var digits: Control = holder.get_node_or_null("Digits")
	if digits == null:
		return
	# Detached before freeing: queue_free only lands at the end of the frame,
	# and the old number would draw over the new one until it did.
	for child in digits.get_children():
		digits.remove_child(child)
		child.queue_free()

	var text := str(maxi(value, 0))
	var height := WAVE_NUM_HEIGHT
	var ink := 0.0
	for ch in text:
		var measured: Rect2 = WAVE_DIGIT_CUTS[ch.to_int()]
		ink += measured.size.x
	var total: float = ink * height / WAVE_DIGIT_H \
		+ WAVE_NUM_TRACKING * height * float(text.length() - 1)
	if total > WAVE_NUM_MAX_W:
		height *= WAVE_NUM_MAX_W / total
		total = WAVE_NUM_MAX_W

	var sheet: Texture2D = load(WAVE_DIGIT_ART)
	var x: float = WAVE_NUM_CENTER.x - total / 2.0
	for ch in text:
		var cut: Rect2 = WAVE_DIGIT_CUTS[ch.to_int()]
		var glyph_w: float = cut.size.x * height / WAVE_DIGIT_H

		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = cut

		var glyph := TextureRect.new()
		glyph.texture = atlas
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_SCALE
		glyph.position = Vector2(x, WAVE_NUM_CENTER.y - height / 2.0)
		glyph.size = Vector2(glyph_w, height)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		digits.add_child(glyph)

		x += glyph_w + WAVE_NUM_TRACKING * height

# ---------------------------------------------------------------- send button

# The panel art already draws the button, so the real one is an invisible hit
# box laid exactly over it. All it adds is the press feedback the painting
# cannot give: a brief wash of light across the plate.
func _build_send_button(root: Control) -> void:
	send_button = Button.new()
	send_button.text = ""
	send_button.position = Vector2(
		SEND_ART_RECT.position.x * MERGE_ART_SCALE,
		MERGE_ART_TOP + SEND_ART_RECT.position.y * MERGE_ART_SCALE)
	send_button.size = SEND_ART_RECT.size * MERGE_ART_SCALE
	send_button.pressed.connect(_on_send_pressed)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		send_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	root.add_child(send_button)

	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(1, 1, 1, 0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	send_button.add_child(wash)

	send_button.button_down.connect(func() -> void: wash.color = Color(1, 1, 1, 0.16))
	send_button.button_up.connect(func() -> void: wash.color = Color(1, 1, 1, 0.0))

# ----------------------------------------------------------------------- shop

# The shop button rides above the panel opposite the NEXT chip: the merge art
# has no room on its base, and a till is not something to put next to the
# button pressed every wave.
const SHOP_BTN_SIZE := Vector2(300.0, 0.0)   # height follows the art's aspect
const SHOP_BTN_ART := Vector2(645.0, 205.0)
const REPAIR_AMOUNT := 30.0

func _build_shop(root: Control) -> void:
	shop_panel = ShopPanel.new()
	root.add_child(shop_panel)
	shop_panel.build(Vector2(VIEW_W, VIEW_H))
	shop_panel.purchase_requested.connect(_on_purchase_requested)
	shop_panel.closed.connect(_close_shop)

	# The button is a painted plate (art/shop_button.png) with an invisible hit
	# box on top of it, the same way SEND works.
	var btn_size := Vector2(SHOP_BTN_SIZE.x,
		SHOP_BTN_SIZE.x * SHOP_BTN_ART.y / SHOP_BTN_ART.x)
	var btn_pos := Vector2(
		VIEW_W - 56.0 - btn_size.x, MERGE_ART_TOP - btn_size.y - 14.0)

	shop_button = Button.new()
	shop_button.text = ""
	shop_button.position = btn_pos
	shop_button.size = btn_size
	shop_button.pressed.connect(_open_shop)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		shop_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	root.add_child(shop_button)

	# The plate rides on the button rather than beside it, so hiding the button
	# hides the picture with it and the two can never drift apart.
	var plate := TextureRect.new()
	plate.texture = load("res://art/shop_button.png")
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_button.add_child(plate)

	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(1, 1, 1, 0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_button.add_child(wash)
	shop_button.button_down.connect(func() -> void: wash.color = Color(1, 1, 1, 0.18))
	shop_button.button_up.connect(func() -> void: wash.color = Color(1, 1, 1, 0.0))

	_build_hero_button(root, btn_pos, btn_size)

# ------------------------------------------------------------ hero ability
#
# Directly over the shop plate and hard against the same right margin, so the
# two read as one column of things the player reaches for mid-wave rather than
# as a button that wandered in. It is the only control on the screen that is
# there for the whole run whether it can be used or not: dark until the hero
# earns it, then lit, and that changeover is most of how the player finds out
# the ability exists at all.
const HERO_BTN_SIZE := 150.0
const HERO_BTN_GAP := 18.0

func _build_hero_button(root: Control, shop_pos: Vector2, shop_size: Vector2) -> void:
	hero_button = HeroAbilityButton.new()
	root.add_child(hero_button)
	hero_button.build(HERO_BTN_SIZE)
	hero_button.position = Vector2(
		shop_pos.x + shop_size.x - HERO_BTN_SIZE,
		shop_pos.y - HERO_BTN_SIZE - HERO_BTN_GAP)
	hero_button.cast_requested.connect(_on_hero_ability_pressed)

# Whether the screen is the player's to press things on. Set by
# _update_pause_button, which already knows about every overlay there is.
var _hero_button_allowed: bool = true

func _update_hero_button() -> void:
	if hero_button == null:
		return
	if not _hero_button_allowed:
		hero_button.visible = false
		return
	hero_button.refresh(_live_hero())

func _on_hero_ability_pressed() -> void:
	if not GameManager.is_playing() or get_tree().paused:
		return
	var d: Defender = _live_hero()
	if d == null:
		return
	if CombatManager.cast_ability(d):
		_shake(6.0, 0.2)

# The hero if it is still standing, and null if it is not -- a hero can be cut
# down like anything else, and when it is the button goes with it.
func _live_hero() -> Defender:
	if hero_unit != null and (not is_instance_valid(hero_unit) or not hero_unit.is_alive()):
		hero_unit = null
	return hero_unit

func _open_shop() -> void:
	if not GameManager.is_playing() or get_tree().paused:
		return
	_release_field_touch()
	get_tree().paused = true
	shop_button.visible = false
	shop_panel.open(GameManager.coins, _shop_availability(),
		_shop_prices(), _shop_descs())
	_update_pause_button()

func _close_shop() -> void:
	shop_panel.close()
	get_tree().paused = false
	shop_button.visible = true
	_update_pause_button()

# What the shop cannot work out for itself: whether there is anything in the
# tray to clear, and whether the fortress has damage worth paying to undo.
func _shop_availability() -> Dictionary:
	return {
		"clear": not _clearable_pieces().is_empty(),
		"repair": fortress != null and fortress.hp < fortress.max_hp,
		"unit_slot": GameManager.next_slot_price() > 0,
	}

# The slot price climbs with every one bought, and reads 0 -- sold out -- once
# the last is taken.
func _shop_prices() -> Dictionary:
	return {"unit_slot": GameManager.next_slot_price()}

# Spelling out where the limit stands beats a fixed blurb: the whole point of
# the row is the number it moves.
func _shop_descs() -> Dictionary:
	var limit: int = _defender_limit()
	if GameManager.next_slot_price() <= 0:
		return {"unit_slot": "Field limit %d units -- fully expanded" % limit}
	return {"unit_slot": "Field limit %d units, raise it to %d" % [limit, limit + 1]}

func _on_purchase_requested(id: String) -> void:
	if not bool(_shop_availability().get(id, true)):
		return

	if id == "unit_slot":
		# Priced and charged by GameManager: the cost moves with every purchase,
		# so the shelf price is whatever the next slot happens to cost now.
		if not GameManager.buy_unit_slot():
			return
	else:
		var price: int = 0
		for item in ShopPanel.ITEMS:
			if String(item["id"]) == id:
				price = int(item["price"])
				break
		if price <= 0 or not GameManager.spend_coins(price):
			return

		match id:
			"clear":
				for o in _clearable_pieces():
					o.dissolve()
			"repair":
				fortress.heal(REPAIR_AMOUNT)
			_:
				_drop_bought_piece(id)

	_refresh_shop()

func _refresh_shop() -> void:
	if shop_panel == null or not shop_panel.visible:
		return
	shop_panel.refresh(GameManager.coins, _shop_availability(),
		_shop_prices(), _shop_descs())

# The piece on the player's finger is deliberately spared by a tray wipe: it
# has not been dropped in yet, and taking it away would leave nothing to aim.
func _clearable_pieces() -> Array:
	var targets: Array = []
	for o in get_tree().get_nodes_in_group("merge_objects"):
		if o is MergeObject and o != current_object and not o.merged and not o.held:
			targets.append(o)
	return targets

# Bought pieces fall in from the mouth of the well like any other drop, rather
# than appearing already settled in the pile.
func _drop_bought_piece(unit_id: String) -> void:
	var obj := MergeObject.new()
	obj.setup(unit_id)
	merge_layer.add_child(obj)
	obj.global_position = Vector2(
		randf_range(MERGE_LEFT + 120.0, MERGE_RIGHT - 120.0), MERGE_TOP + 60.0)
	obj.apply_central_impulse(Vector2(0, 60))

# ----------------------------------------------------------------- hearts

# Fortress health as a row of hearts from the icon sheet, ten HP each. Every
# heart is a TextureProgressBar drawing the same art twice -- greyed underneath
# and full colour on top -- so a heart caught mid-damage drains partway instead
# of flipping between two states.
#
# The count follows max HP rather than being fixed at ten: the REINFORCED WALLS
# upgrade adds 20 HP, and that has to show up as two more hearts if a heart is
# to keep meaning ten. They shrink to stay inside the row as they multiply.

const HEART_VALUE := 10.0
const HEART_GAP := 9.0
const HEART_MAX_SIZE := 56.0
# The row shares the HUD band with the wave plate now, so it starts where the
# plate ends and runs to the right margin instead of across the whole screen.
const HEART_ROW_WIDTH := 532.0
const HEART_ROW_POS := Vector2(492.0, 55.0)
const HEART_EMPTY := Color(0.30, 0.30, 0.36, 0.80)

var heart_row: Control
var hearts: Array = []
var _heart_fill: Array = []       # last drawn fill per heart, for the pop
var _heart_base_scale: Vector2 = Vector2.ONE

func _build_heart_row(parent: Control) -> void:
	heart_row = Control.new()
	heart_row.position = HEART_ROW_POS
	heart_row.size = Vector2(HEART_ROW_WIDTH, HEART_MAX_SIZE)
	heart_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(heart_row)

func _rebuild_hearts(count: int) -> void:
	for h in hearts:
		if is_instance_valid(h):
			h.queue_free()
	hearts = []
	_heart_fill = []

	var tex: Texture2D = UIStyle.icon_texture("icon_heart")
	if tex == null or heart_row == null:
		return

	var size: float = clampf(
		(HEART_ROW_WIDTH - (count - 1) * HEART_GAP) / float(count), 22.0, HEART_MAX_SIZE)
	var factor: float = size / float(tex.get_width())
	_heart_base_scale = Vector2(factor, factor)

	for i in range(count):
		var heart := TextureProgressBar.new()
		heart.texture_under = tex
		heart.texture_progress = tex
		heart.tint_under = HEART_EMPTY
		heart.tint_progress = Color(1, 1, 1, 1)
		heart.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heart.max_value = 1.0
		heart.step = 0.0     # must precede value, or it snaps to whole hearts
		heart.value = 1.0
		heart.scale = _heart_base_scale
		heart.pivot_offset = tex.get_size() * 0.5
		heart.position = Vector2(i * (size + HEART_GAP), 0)
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heart_row.add_child(heart)
		hearts.append(heart)
		_heart_fill.append(1.0)

func _update_hearts(current: float, max_hp: float) -> void:
	var count: int = maxi(1, int(ceil(max_hp / HEART_VALUE)))
	if hearts.size() != count:
		_rebuild_hearts(count)

	for i in range(hearts.size()):
		var heart: TextureProgressBar = hearts[i]
		if not is_instance_valid(heart):
			continue
		var fill: float = clampf((current - i * HEART_VALUE) / HEART_VALUE, 0.0, 1.0)
		var before: float = float(_heart_fill[i])
		heart.value = fill
		_heart_fill[i] = fill
		if not is_equal_approx(fill, before):
			_pulse_heart(heart, fill > before)

# Hearts kick when they change: outward on a repair, a sharper snap on a hit.
func _pulse_heart(heart: TextureProgressBar, healed: bool) -> void:
	var peak: float = 1.22 if healed else 1.16
	heart.scale = _heart_base_scale * peak
	var tw := create_tween()
	tw.tween_property(heart, "scale", _heart_base_scale, 0.22 if healed else 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------- bar chips

# Gold and units are painted bars (art/bar_coin.png, art/bar_units.png, cut out
# of art/bars.png), icon and frame and all. Only the number is live, so the
# numbers baked into the reference were painted out and the label is laid over
# the space they left. Everything below is a fraction of the painting, so the
# text follows whatever size the bar is drawn at.
#
# BAR_SCALE is the one dial: both bars, the gap between them, the numbers on
# them and the point coins fly to are all derived from it. They are read at a
# glance and then ignored -- the fight is the thing being looked at -- so they
# are drawn small enough to leave the top of the arena to the arena.
const BAR_SCALE := 0.66
const BAR_ROW_Y := 190.0
const BAR_ROW_X := 24.0
const BAR_GAP := 12.0

# Cap height of the number as a fraction of the bar it sits on, taken from the
# painting: 42px of text on a bar drawn 118 tall.
const BAR_TEXT_HEIGHT := 42.0 / 118.0
const BAR_OUTLINE := 6.0 / 118.0

func _build_bar_chip(root: Control, art: String, pos: Vector2, size: Vector2) -> Control:
	var holder := Control.new()
	holder.position = pos
	holder.size = size
	holder.pivot_offset = size / 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)

	var bar := TextureRect.new()
	bar.texture = load(art)
	# Drawn smaller than it is painted, so linear rather than the nearest the
	# sprites use -- see the wave plate.
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.size = size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bar)
	return holder

# `text_x` and `text_w` bound the empty space on the bar, `text_cy` is the line
# the painted number sat on.
func _bar_label(holder: Control, text_x: float, text_w: float, text_cy: float) -> Label:
	var box := Vector2(holder.size.x * text_w, holder.size.y * 0.5)
	var label := Label.new()
	label.position = Vector2(holder.size.x * text_x, holder.size.y * text_cy - box.y / 2.0)
	label.size = box
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",
		int(roundf(holder.size.y * BAR_TEXT_HEIGHT)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(label, UIStyle.ACCENT_GOLD,
		int(roundf(holder.size.y * BAR_OUTLINE)))
	holder.add_child(label)
	return label

# ------------------------------------------------------------------ coin chip

# Sits under the wave plate on the left, mirroring the pause button on the right.
const COIN_CHIP_ART := "res://art/bar_coin.png"
const COIN_CHIP_POS := Vector2(BAR_ROW_X, BAR_ROW_Y)
const COIN_CHIP_SIZE := Vector2(292.0, 118.0) * BAR_SCALE
const COIN_ICON_CENTER := Vector2(0.221, 0.568)
const COIN_TEXT_X := 0.418
const COIN_TEXT_W := 0.451
const COIN_TEXT_CY := 0.578

func _build_coin_chip(root: Control) -> void:
	coin_panel = _build_bar_chip(root, COIN_CHIP_ART, COIN_CHIP_POS, COIN_CHIP_SIZE)
	coin_label = _bar_label(coin_panel, COIN_TEXT_X, COIN_TEXT_W, COIN_TEXT_CY)

	# The painted coin is where the coins fly to, so it has to be a world
	# position: there is no camera, so HUD coordinates are world coordinates.
	coin_target = COIN_CHIP_POS + COIN_ICON_CENTER * COIN_CHIP_SIZE

	_coin_display = float(GameManager.coins)
	coin_label.text = _format_coins(GameManager.coins)

# Rolls the number up to its new value rather than snapping, and bumps the whole
# chip, so a boss payout reads as a payout and not as a redrawn label.
func _on_coins_changed(total: int) -> void:
	if coin_label == null:
		return
	if _coin_tween != null and _coin_tween.is_valid():
		_coin_tween.kill()
	_coin_tween = create_tween()
	_coin_tween.tween_method(_set_coin_display, _coin_display, float(total), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _coin_pulse != null and _coin_pulse.is_valid():
		_coin_pulse.kill()
	coin_panel.scale = Vector2(1.1, 1.1)
	_coin_pulse = create_tween()
	_coin_pulse.tween_property(coin_panel, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Gold can change while the shelf is open -- a purchase is the usual way.
	_refresh_shop()

# ----------------------------------------------------------------- units chip

# Beside the coins, because the two are the same decision: gold buys room on the
# field. Without this the limit is invisible -- SEND simply stops working and
# the player has no idea why.
const UNITS_CHIP_ART := "res://art/bar_units.png"
const UNITS_CHIP_POS := Vector2(BAR_ROW_X + COIN_CHIP_SIZE.x + BAR_GAP, BAR_ROW_Y)
const UNITS_CHIP_SIZE := Vector2(286.0, 118.0) * BAR_SCALE
const UNITS_TEXT_X := 0.416
const UNITS_TEXT_W := 0.461
const UNITS_TEXT_CY := 0.564

func _build_units_chip(root: Control) -> void:
	units_panel = _build_bar_chip(root, UNITS_CHIP_ART, UNITS_CHIP_POS, UNITS_CHIP_SIZE)
	units_label = _bar_label(units_panel, UNITS_TEXT_X, UNITS_TEXT_W, UNITS_TEXT_CY)
	_update_units_chip()

# Driven off the live count rather than signalled from every place a unit
# appears or falls: units die in combat, and the counter has to follow that too.
func _update_units_chip() -> void:
	if units_label == null:
		return
	var count: int = _defenders_on_field()
	var limit: int = _defender_limit()
	var text: String = "%d/%d" % [count, limit]
	if units_label.text == text:
		return
	units_label.text = text
	# Full board reads red: the reason SEND is refusing to deploy anything.
	units_label.add_theme_color_override("font_color",
		UIStyle.ACCENT_RED if count >= limit else UIStyle.ACCENT_GOLD)

func _set_coin_display(value: float) -> void:
	_coin_display = value
	coin_label.text = _format_coins(int(round(value)))

func _format_coins(value: int) -> String:
	var digits := str(value)
	var out := ""
	var placed := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		placed += 1
		if placed % 3 == 0 and i > 0:
			out = "," + out
	return out

# ------------------------------------------------------------------- retreat
#
# The one way out of a run that is neither losing it nor throwing it away. The
# fortress falling banks what the run earned; so does EXIT on the pause menu.
# Neither is a decision -- with no reason to stop, the only move at wave 40 is
# to stand there until the wall comes down, which is the opposite of one.
#
# Walking off the field on purpose pays a multiplier that climbs with the wave
# (MetaManager.extract_multiplier) and, more to the point, lets the player keep
# the units standing on it: whatever is alive when the button is pressed goes
# into the pack and is there on the menu afterwards. So "one more block of ten"
# is always worth something, and so is stopping -- which is the whole of the
# decision this button exists to create.
#
# It is confirmed rather than immediate, and the confirmation shows the pack
# it would bank. A button that ends the run under the player's thumb with no
# warning is a button nobody presses twice.

const RETREAT_BTN_SIZE := Vector2(196.0, 72.0)
const RETREAT_BTN_GAP := 14.0

var retreat_button: Button
var retreat_panel: Control
var retreat_essence_label: Label
var retreat_list: VBoxContainer
var retreat_list_note: Label

func _build_retreat_ui(root: Control) -> void:
	_build_retreat_panel(root)

	# Directly under the pause button and against the same right margin, so the
	# two read as one column of things that take the player out of the fight.
	retreat_button = Button.new()
	retreat_button.text = "RETREAT"
	retreat_button.size = RETREAT_BTN_SIZE
	retreat_button.position = Vector2(
		VIEW_W - 24.0 - RETREAT_BTN_SIZE.x,
		190.0 + PAUSE_BTN_SIZE + RETREAT_BTN_GAP)
	retreat_button.process_mode = Node.PROCESS_MODE_ALWAYS
	UIStyle.apply_button_style(retreat_button, UIStyle.ACCENT_TEAL.darkened(0.12), 28, 20)
	retreat_button.pressed.connect(_on_retreat_pressed)
	root.add_child(retreat_button)

const RETREAT_PANEL_SIZE := Vector2(940.0, 1120.0)

func _build_retreat_panel(root: Control) -> void:
	retreat_panel = Control.new()
	retreat_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	retreat_panel.visible = false
	# The tree is frozen while this is up, so everything on it has to keep
	# running or none of its buttons answer.
	retreat_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(retreat_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.84)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	retreat_panel.add_child(dim)

	var panel := Panel.new()
	panel.size = RETREAT_PANEL_SIZE
	# Centred on the arena rather than the screen, like every other plate here.
	panel.position = Vector2(
		(VIEW_W - RETREAT_PANEL_SIZE.x) / 2.0, ARENA_CENTER.y - RETREAT_PANEL_SIZE.y / 2.0)
	panel.add_theme_stylebox_override("panel",
		UIStyle.panel_box(UIStyle.PANEL_BG, UIStyle.ACCENT_TEAL, 30, 3))
	retreat_panel.add_child(panel)

	var title := Label.new()
	title.text = "RETREAT?"
	title.position = Vector2(0, 34)
	title.size = Vector2(RETREAT_PANEL_SIZE.x, 74)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(title, UIStyle.ACCENT_TEAL, 8)
	panel.add_child(title)

	var sub := Label.new()
	sub.text = "The run ends here and is banked for good. What is still standing comes home with you."
	sub.position = Vector2(48, 112)
	sub.size = Vector2(RETREAT_PANEL_SIZE.x - 96, 74)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.add_theme_font_size_override("font_size", 24)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_body_text(sub, UIStyle.TEXT_MUTED)
	panel.add_child(sub)

	retreat_essence_label = Label.new()
	retreat_essence_label.position = Vector2(0, 192)
	retreat_essence_label.size = Vector2(RETREAT_PANEL_SIZE.x, 62)
	retreat_essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retreat_essence_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	retreat_essence_label.add_theme_font_size_override("font_size", 40)
	retreat_essence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(retreat_essence_label, UIStyle.ACCENT_GOLD, 6)
	panel.add_child(retreat_essence_label)

	var heading := Label.new()
	heading.text = "YOU TAKE WITH YOU"
	heading.position = Vector2(0, 266)
	heading.size = Vector2(RETREAT_PANEL_SIZE.x, 44)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_body_text(heading, UIStyle.TEXT_MUTED)
	panel.add_child(heading)

	# Says so outright when the field is empty, rather than leaving a blank
	# space the player has to work out the meaning of.
	retreat_list_note = Label.new()
	retreat_list_note.position = Vector2(48, 330)
	retreat_list_note.size = Vector2(RETREAT_PANEL_SIZE.x - 96, 44)
	retreat_list_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retreat_list_note.visible = false
	retreat_list_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_body_text(retreat_list_note, UIStyle.TEXT_MUTED)
	panel.add_child(retreat_list_note)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 322)
	scroll.size = Vector2(RETREAT_PANEL_SIZE.x - 80, RETREAT_PANEL_SIZE.y - 322 - 158)
	panel.add_child(scroll)

	retreat_list = VBoxContainer.new()
	retreat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retreat_list.add_theme_constant_override("separation", 12)
	scroll.add_child(retreat_list)

	var btn_w := (RETREAT_PANEL_SIZE.x - 80.0 - 24.0) / 2.0
	var btn_y := RETREAT_PANEL_SIZE.y - 130.0

	var stay := Button.new()
	stay.text = "STAY"
	stay.position = Vector2(40, btn_y)
	stay.size = Vector2(btn_w, 92)
	UIStyle.apply_button_style(stay, UIStyle.ACCENT_BLUE, 34, 24)
	stay.pressed.connect(_close_retreat)
	panel.add_child(stay)

	var go := Button.new()
	go.text = "RETREAT"
	go.position = Vector2(40 + btn_w + 24, btn_y)
	go.size = Vector2(btn_w, 92)
	UIStyle.apply_button_style(go, UIStyle.ACCENT_TEAL, 34, 24)
	go.pressed.connect(_confirm_retreat)
	panel.add_child(go)

# Everything alive on the field, as the {"id", "level"} rows MetaManager stores.
#
# The hero is left out on purpose: it is lent to the run rather than earned by
# it -- standing on the ring before the first piece drops, in a slot handed to
# it rather than taken -- and a hero that could be carried home would be a hero
# the player farms one run at a time.
func _carried_units() -> Array:
	var out: Array = []
	for d in CombatManager.defenders:
		if not is_instance_valid(d) or not d.is_alive():
			continue
		if UnitDatabase.is_hero(d.unit_id):
			continue
		out.append({"id": d.unit_id, "level": d.unit_level})
	return out

func _on_retreat_pressed() -> void:
	if not GameManager.is_playing() or get_tree().paused:
		return
	_release_field_touch()
	get_tree().paused = true
	_refresh_retreat_panel()
	retreat_panel.visible = true
	_update_pause_button()

func _refresh_retreat_panel() -> void:
	var wave: int = WaveManager.current_wave
	var mult: float = MetaManager.extract_multiplier(wave)
	retreat_essence_label.text = "+%d ESSENCE   ×%.2f" % [_retreat_essence(wave, mult), mult]

	for child in retreat_list.get_children():
		child.queue_free()

	var stacks: Array = MetaManager.group_units(_carried_units())
	retreat_list_note.visible = stacks.is_empty()
	retreat_list_note.text = "Nothing is standing on the field."
	for stack in stacks:
		retreat_list.add_child(_retreat_row(stack as Dictionary))

# What the retreat would pay, worked out the same way MetaManager works it out
# so the number on the button and the number banked can never disagree. It is
# recomputed rather than asked for because asking would mean banking the run.
func _retreat_essence(wave: int, mult: float) -> int:
	var base: int = int(floor(wave / 2.0))
	if wave >= 20:
		base += 10
	if wave >= 30:
		base += 20
	if _beat_dragon:
		base += 50
	return int(round(float(base) * mult))

func _retreat_row(stack: Dictionary) -> Control:
	var id: String = String(stack.get("id", ""))
	var d: Dictionary = UnitDatabase.get_def(id)
	var accent: Color = d.get("color", UIStyle.ACCENT_GOLD)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(accent))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var count := Label.new()
	count.text = "×%d" % int(stack.get("count", 1))
	count.custom_minimum_size = Vector2(96, 0)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 34)
	UIStyle.apply_heading(count, accent, 5)
	row.add_child(count)

	var name_lbl := Label.new()
	name_lbl.text = String(d.get("name", id))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 30)
	UIStyle.apply_body_text(name_lbl, UIStyle.TEXT_LIGHT)
	row.add_child(name_lbl)

	var level := Label.new()
	level.text = "LV %d" % int(stack.get("level", 1))
	level.custom_minimum_size = Vector2(140, 0)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level.add_theme_font_size_override("font_size", 28)
	UIStyle.apply_body_text(level, UIStyle.ACCENT_GOLD)
	row.add_child(level)

	return card

func _close_retreat() -> void:
	retreat_panel.visible = false
	get_tree().paused = false
	_update_pause_button()

# The pack is stored before the run is banked, so a save written between the
# two can never contain the essence without the units that were carried out
# alongside it.
func _confirm_retreat() -> void:
	retreat_panel.visible = false
	get_tree().paused = false
	MusicPlayer.set_intensity(0.0)
	MetaManager.add_to_inventory(_carried_units())
	_bank_run(true)
	get_tree().change_scene_to_file(MENU_SCENE)

# ----------------------------------------------------------------- pause menu

const PAUSE_BTN_SIZE := 96.0
const PAUSE_ART := "res://art/pause_button.png"

func _build_pause_ui(root: Control) -> void:
	# Added after the upgrade panel so the overlay covers it, and the button
	# after the overlay so nothing draws on top of it while the game runs.
	pause_menu = PauseMenu.new()
	root.add_child(pause_menu)
	pause_menu.build(Vector2(VIEW_W, VIEW_H))
	pause_menu.resume_requested.connect(_resume_from_pause)
	pause_menu.restart_requested.connect(_restart_from_pause)
	pause_menu.exit_requested.connect(_exit_to_menu)

	# Tucked under the HUD card on the right, clear of the fortress and of the
	# four lanes the enemies walk in on. The frame is already painted into
	# pause_button.png, so the button is invisible and the picture is the
	# whole of what is drawn -- the same shape as every other painted button
	# in this game.
	pause_button = Button.new()
	pause_button.text = ""
	pause_button.size = Vector2(PAUSE_BTN_SIZE, PAUSE_BTN_SIZE)
	pause_button.position = Vector2(VIEW_W - 24.0 - PAUSE_BTN_SIZE, 190.0)
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_on_pause_pressed)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		pause_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	root.add_child(pause_button)

	var art := TextureRect.new()
	art.texture = load(PAUSE_ART)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_button.add_child(art)

	# The painted plate cannot light up on its own, so a wash sits over it.
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(1, 1, 1, 0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_button.add_child(wash)
	pause_button.button_down.connect(func() -> void: wash.color = Color(1, 1, 1, 0.18))
	pause_button.button_up.connect(func() -> void: wash.color = Color(1, 1, 1, 0.0))

func _on_pause_pressed() -> void:
	if not GameManager.is_playing() or get_tree().paused:
		return
	_release_field_touch()
	get_tree().paused = true
	pause_menu.open()
	# After the overlay is up rather than hiding the one button by hand: the
	# retreat plate is on the same column and has to go with it.
	_update_pause_button()

func _resume_from_pause() -> void:
	pause_menu.close()
	get_tree().paused = false
	_update_pause_button()

func _restart_from_pause() -> void:
	pause_menu.close()
	get_tree().paused = false
	get_tree().reload_current_scene()

const MENU_SCENE := "res://scenes/menu/Menu.tscn"

# Leaving a run on purpose. RESTART throws the run away and starts another --
# it is a do-over, and a do-over should not pay out. EXIT is the player saying
# they are finished, which is the same thing the defeat screen says, so it
# banks what the run earned on the way out. Otherwise the only way to keep the
# essence from a run you have had enough of would be to stand still and let
# the fortress fall, which is a rule nobody should have to learn.
#
# The tree is unpaused before the scene changes, or the menu loads frozen and
# nothing on it answers.
func _exit_to_menu() -> void:
	pause_menu.close()
	get_tree().paused = false
	# The track outlives the scene; without this a run abandoned mid-overflow
	# leaves the menu playing at the panic volume it was raised to.
	MusicPlayer.set_intensity(0.0)
	_bank_run()
	get_tree().change_scene_to_file(MENU_SCENE)

# What the run is worth to the player once it is over, paid exactly once. Both
# ways out of a run come through here, so a run can never be banked twice --
# and the essence the defeat screen shows is the same figure this returns.
var _run_banked: bool = false

func _bank_run(extracted: bool = false) -> int:
	if _run_banked:
		return 0
	_run_banked = true
	return MetaManager.record_run_end(WaveManager.current_wave, _beat_dragon, extracted)

# The button only makes sense during play: the upgrade screen and game over
# already own the whole screen and pause the tree themselves.
func _update_pause_button() -> void:
	if pause_button == null:
		return
	# The blessing board is the one overlay that goes up while the run is still
	# nominally playing -- it is shown before _begin_run() -- so it has to be
	# named here or RETREAT and the pause key sit on top of it.
	var overlay_open: bool = pause_menu.visible \
		or (shop_panel != null and shop_panel.visible) \
		or (retreat_panel != null and retreat_panel.visible) \
		or (blessing_panel != null and blessing_panel.visible)
	pause_button.visible = GameManager.is_playing() and not overlay_open
	if shop_button != null:
		shop_button.visible = GameManager.is_playing() and not overlay_open
	if retreat_button != null:
		retreat_button.visible = GameManager.is_playing() and not overlay_open
	# Left to _update_hero_button to decide whether it has anything to show; all
	# this settles is whether the screen belongs to something else.
	_hero_button_allowed = GameManager.is_playing() and not overlay_open
	_update_hero_button()

func _on_game_state_changed(_new_state: int) -> void:
	# The upgrade cards and the defeat plate both take the screen without going
	# through the pause button, so anything held on the field is put down here.
	if not GameManager.is_playing():
		_release_field_touch()
	_update_pause_button()

# --------------------------------------------------------------- blessings
#
# Shown once, before the tray drops anything, and never again this run -- on
# the same painted plate the wave upgrade uses (see ui/ChoicePlate.gd), because
# this is also a screen the player takes one card off and moves on from, and
# two screens that do the one thing have no business looking like two.

var blessing_panel: ChoicePlate
var blessing_card_ids: Array = []

func _build_blessing_panel(root: Control) -> void:
	blessing_panel = ChoicePlate.new()
	blessing_panel.build(Vector2(VIEW_W, VIEW_H))
	blessing_panel.picked.connect(_on_blessing_card_pressed)
	root.add_child(blessing_panel)

# A random sample rather than the whole pool every time, the same way the
# upgrade screen never shows every upgrade at once -- three ordinarily, four
# once MetaManager.has_tier4() has made a fourth slot worth having.
func _show_blessing_selection() -> void:
	var pool: Array = BlessingManager.choices()
	pool.shuffle()
	var card_count: int = 4 if MetaManager.has_tier4() else 3
	var offered: Array = pool.slice(0, mini(card_count, pool.size()))

	blessing_card_ids = []
	var cards: Array = []
	for id in offered:
		var d: Dictionary = BlessingManager.get_def(String(id))
		blessing_card_ids.append(String(id))
		cards.append({
			"name": String(d.get("name", id)),
			"desc": String(d.get("desc", "")),
			"art": BlessingManager.get_art_path(String(id)),
			"accent": BlessingManager.accent(String(id)),
			# Nothing to climb: a blessing is taken once and kept, so the row
			# the upgrade cards spend on Lv N -> N+1 goes to the wording.
			"level": -1,
			"rare": false,
		})

	# The plate's own title and footer both say upgrade, so both are rewritten;
	# everything else the painting says is true on this screen too.
	blessing_panel.open({
		"title": "CHOOSE A BLESSING",
		"subtitle": "THE RUN BEGINS",
		"footer": "Tap a blessing to select",
	}, cards)
	get_tree().paused = true
	_update_pause_button()

func _on_blessing_card_pressed(index: int) -> void:
	if index < 0 or index >= blessing_card_ids.size():
		return
	var id: String = blessing_card_ids[index]
	if id == "":
		return
	BlessingManager.apply(id)
	blessing_panel.close()
	get_tree().paused = false
	_begin_run()
	_update_pause_button()

func _build_upgrade_panel(root: Control) -> void:
	upgrade_panel = ChoicePlate.new()
	upgrade_panel.build(Vector2(VIEW_W, VIEW_H))
	upgrade_panel.picked.connect(_on_upgrade_card_pressed)
	root.add_child(upgrade_panel)

# ------------------------------------------------------- merge upgrade screen
#
# The one wave that pays out in a change to the board rather than a number, so
# it is announced rather than chosen. One painted plate (art/merge_upgrade.png)
# carries the title, both lines of every row and the CONTINUE plate already
# drawn in -- the same "picture plus an invisible hit box" shape the shop
# shelf and the defeat screen use -- so all this owns is the reveal and where
# CONTINUE actually is.

const MERGE_UPGRADE_ART := "res://art/merge_upgrade.png"
const MERGE_UPGRADE_ART_SIZE := Vector2(1122.0, 1402.0)
const MERGE_UPGRADE_WIDTH := 1000.0
# Where the painted CONTINUE plate sits, as a fraction of the art -- measured
# off the picture the same way every other painted hit box in this game is.
const MERGE_UPGRADE_CONTINUE_RECT := Rect2(0.240, 0.849, 0.516, 0.095)

var merge_upgrade_panel: Control
var merge_upgrade_plate: TextureRect

func _build_merge_upgrade_panel(root: Control) -> void:
	merge_upgrade_panel = Control.new()
	merge_upgrade_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	merge_upgrade_panel.visible = false
	merge_upgrade_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(merge_upgrade_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	merge_upgrade_panel.add_child(dim)

	var plate_size := Vector2(MERGE_UPGRADE_WIDTH,
		MERGE_UPGRADE_WIDTH * MERGE_UPGRADE_ART_SIZE.y / MERGE_UPGRADE_ART_SIZE.x)
	var plate_pos := Vector2((VIEW_W - plate_size.x) / 2.0, (VIEW_H - plate_size.y) / 2.0)

	merge_upgrade_plate = TextureRect.new()
	merge_upgrade_plate.texture = load(MERGE_UPGRADE_ART)
	merge_upgrade_plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	merge_upgrade_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	merge_upgrade_plate.stretch_mode = TextureRect.STRETCH_SCALE
	merge_upgrade_plate.position = plate_pos
	merge_upgrade_plate.size = plate_size
	merge_upgrade_plate.pivot_offset = plate_size / 2.0
	merge_upgrade_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	merge_upgrade_panel.add_child(merge_upgrade_plate)

	var go := Button.new()
	go.text = ""
	go.position = plate_pos + MERGE_UPGRADE_CONTINUE_RECT.position * plate_size
	go.size = MERGE_UPGRADE_CONTINUE_RECT.size * plate_size
	go.pressed.connect(_close_merge_upgrade)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		go.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	merge_upgrade_panel.add_child(go)

	# The painted plate cannot light up on its own, so a wash sits over it.
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(1, 0.9, 0.6, 0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go.add_child(wash)
	go.button_down.connect(func() -> void: wash.color = Color(1, 0.9, 0.6, 0.18))
	go.button_up.connect(func() -> void: wash.color = Color(1, 0.9, 0.6, 0.0))

func _show_merge_upgrade() -> void:
	GameManager.merge_upgraded = true
	merge_upgrade_panel.visible = true
	GameManager.enter_upgrade_selection()
	get_tree().paused = true

	_flash_screen()
	merge_upgrade_plate.scale = Vector2(0.8, 0.8)
	merge_upgrade_plate.modulate.a = 0.0

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(merge_upgrade_plate, "modulate:a", 1.0, 0.22)
	tw.parallel().tween_property(merge_upgrade_plate, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_merge_upgrade() -> void:
	merge_upgrade_panel.visible = false
	get_tree().paused = false
	GameManager.resume_playing()
	WaveManager.resume_after_upgrade()

# ----------------------------------------------------------- winter changeover
#
# Wave 30 is the golem, and the field it falls on is the last green one: the
# banner lands, the ground freezes under it, and every wave after this is fought
# in the snow.
#
# The map does not cut. Both paintings are already hung from the same crossroads
# one over the other (see _add_env_layer), so the whole change is the top one
# coming up from nothing -- nothing shifts, the grass just goes white under the
# soldiers standing on it. It runs unpaused, which is safe because the wave is
# already cleared and WaveManager is holding for the upgrade that follows.

# Which wave this belongs to lives in WaveManager, with the roster that changes
# on the same beat.
const WINTER_ART := "res://art/winter_coming.png"
const WINTER_BANNER_WIDTH := 900.0
# Long and even: the freeze is meant to be noticed happening, not to have
# happened. The banner is up for the whole of it and holds a beat after.
const WINTER_FADE := 2.2
const WINTER_HOLD := 0.9

var winter_banner: TextureRect
var _winter_done: bool = false

func _build_winter_banner(root: Control) -> void:
	if not ResourceLoader.exists(WINTER_ART):
		return
	var tex: Texture2D = load(WINTER_ART)
	var art_size: Vector2 = tex.get_size()
	var size := Vector2(WINTER_BANNER_WIDTH, WINTER_BANNER_WIDTH * art_size.y / art_size.x)

	winter_banner = TextureRect.new()
	winter_banner.texture = tex
	# Linear, like the other painted plates: this is a painting being drawn
	# smaller than it was made, and nearest crawls on its icicles.
	winter_banner.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	winter_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	winter_banner.stretch_mode = TextureRect.STRETCH_SCALE
	winter_banner.size = size
	# Centred on the arena rather than the screen, for the same reason the defeat
	# plate is: the middle of the screen is the top of the merge tray.
	winter_banner.position = Vector2((VIEW_W - size.x) / 2.0, ARENA_CENTER.y - size.y / 2.0)
	winter_banner.pivot_offset = size / 2.0
	winter_banner.modulate = Color(1, 1, 1, 0)
	winter_banner.visible = false
	winter_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(winter_banner)

func _play_winter_change() -> void:
	if _winter_done:
		_show_upgrade_selection()
		return
	_winter_done = true

	# Whatever the wave was still announcing goes now. The two plates are drawn
	# in the same place, and this one is not sharing it.
	_hide_wave_banner()

	_flash_cold()
	# The light turns with the ground. Over the same beat as the map itself, so
	# the field does not go blue a second before or after the grass goes white.
	lighting.to_winter(WINTER_FADE)
	if snowfall != null:
		# Started empty rather than preloaded, so the sky fills from the top and
		# the snow reads as beginning to fall rather than as already falling.
		snowfall.emitting = true

	var tw := create_tween()

	# The map turns first and everything else is hung off it with parallel(), so
	# the banner is up for the whole of the freeze rather than after it.
	if winter_sprite != null:
		tw.tween_property(winter_sprite, "modulate:a", 1.0, WINTER_FADE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# The light the field throws changes with the field. Handed over at the
		# halfway point rather than at either end, so the units cool over roughly
		# the same beat the ground does.
		tw.parallel().tween_callback(
			_light_from.bind(winter_sprite, winter_sprite.get_parent())) \
			.set_delay(WINTER_FADE * 0.5)
	else:
		tw.tween_interval(WINTER_FADE)

	# The fall does not stop for the snow -- the frozen painting still has it
	# running down the rock -- but it turns the colour of the water it is landing
	# in, and it turns it over the same beat the map does.
	if map_waterfall != null:
		tw.parallel().tween_method(map_waterfall.set_frost, 0.0, 1.0, WINTER_FADE)

	if winter_banner == null:
		tw.tween_callback(_show_upgrade_selection)
		return

	winter_banner.visible = true
	winter_banner.modulate = Color(1, 1, 1, 0)
	winter_banner.scale = Vector2(0.72, 0.72)
	tw.parallel().tween_property(winter_banner, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(winter_banner, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw.tween_interval(WINTER_HOLD)
	tw.tween_property(winter_banner, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void:
		winter_banner.visible = false
		# The upgrade this wave owes the player, held back until the announcement
		# is off the screen rather than opening a dialog over it.
		_show_upgrade_selection()
	)

# The warm flash belongs to a merge; this one is the cold coming in, so it is
# blue, wider and much slower to clear.
func _flash_cold() -> void:
	_flash_phase(Color(0.62, 0.82, 1.0, 0.40))

# And this one is the ground opening, so it is orange and brighter still. Same
# shape, same duration -- the two changeovers should land with the same weight
# and differ only in colour.
func _flash_hot() -> void:
	_flash_phase(Color(1.0, 0.56, 0.22, 0.46))

func _flash_phase(color: Color) -> void:
	if screen_flash == null:
		return
	if pause_menu != null and not pause_menu.screen_fx_enabled:
		return
	screen_flash.color = color
	var tw := create_tween()
	tw.tween_property(screen_flash, "color:a", 0.0, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------ ember changeover
#
# The dragon falls on wave 50 and the snow goes out from under it: the frozen
# crossroads is the last one fought on ice, and everything after this is fought
# on the ember map.
#
# Built to the same shape as the winter changeover on purpose. The map does not
# cut -- all three paintings are already hung one over the other from the same
# crossroads (see _add_env_layer) -- so this is the top one coming up from
# nothing while the light, the fall and the weather all turn over the same beat.
#
# The one difference is the banner. Winter has a painting of its own
# (art/winter_coming.png) and this does not, so the announcement is set rather
# than drawn -- the same procedural heading the modifier banner and the overflow
# count already use, scaled up to the size the painted one is shown at.
const LAVA_FADE := 2.4
const LAVA_HOLD := 1.0
const LAVA_BANNER_TEXT := "THE EMBERS RISE"

var lava_banner: Label
var _lava_done: bool = false

func _build_lava_banner(root: Control) -> void:
	lava_banner = Label.new()
	lava_banner.text = LAVA_BANNER_TEXT
	lava_banner.size = Vector2(VIEW_W, 200.0)
	# Centred on the arena rather than the screen, for the same reason every
	# other plate here is: the middle of the screen is the top of the tray.
	lava_banner.position = Vector2(0.0, ARENA_CENTER.y - 100.0)
	lava_banner.pivot_offset = Vector2(VIEW_W, 200.0) / 2.0
	lava_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lava_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lava_banner.add_theme_font_size_override("font_size", 96)
	lava_banner.modulate = Color(1, 1, 1, 0)
	lava_banner.visible = false
	lava_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lava_banner, Color(1.0, 0.62, 0.26), 14)
	root.add_child(lava_banner)

func _play_lava_change() -> void:
	if _lava_done:
		_show_upgrade_selection()
		return
	_lava_done = true

	# Whatever the wave was still announcing goes now, the same way it does at
	# the freeze: the two plates are drawn in the same place.
	_hide_wave_banner()

	_flash_hot()
	lighting.to_lava(LAVA_FADE)
	# The snow does not vanish -- what is already in the air finishes falling --
	# but nothing new is emitted, so the sky clears over roughly the same beat
	# the ground does.
	if snowfall != null:
		snowfall.emitting = false
	if emberfall != null:
		emberfall.emitting = true

	var tw := create_tween()

	if lava_sprite != null:
		tw.tween_property(lava_sprite, "modulate:a", 1.0, LAVA_FADE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# The light the field throws changes with the field, handed over at the
		# halfway point so the bodies warm over the same beat the ground does.
		tw.parallel().tween_callback(
			_light_from.bind(lava_sprite, lava_sprite.get_parent())) \
			.set_delay(LAVA_FADE * 0.5)
	else:
		tw.tween_interval(LAVA_FADE)

	# Same fall off the same cliff, running something else now.
	if map_waterfall != null:
		tw.parallel().tween_method(map_waterfall.set_ember, 0.0, 1.0, LAVA_FADE)

	if lava_banner == null:
		tw.tween_callback(_show_upgrade_selection)
		return

	lava_banner.visible = true
	lava_banner.modulate = Color(1, 1, 1, 0)
	lava_banner.scale = Vector2(0.72, 0.72)
	tw.parallel().tween_property(lava_banner, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(lava_banner, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw.tween_interval(LAVA_HOLD)
	tw.tween_property(lava_banner, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void:
		lava_banner.visible = false
		_show_upgrade_selection()
	)

# ------------------------------------------------------------------- snowfall
#
# Ambient weather for the back half of the run. It lives in the HUD layer inside
# a window cut to the arena, which is what keeps flakes in front of the soldiers
# and off the merge tray -- the tray is painted before the fight and would
# otherwise be snowed on through its own frame.

const SNOW_AMOUNT := 90
const SNOW_LIFETIME := 8.0

var snowfall: CPUParticles2D

func _build_snowfall(root: Control) -> void:
	var clip := _arena_window(root)

	snowfall = CPUParticles2D.new()
	snowfall.texture = FxUtil.dot_texture()
	snowfall.amount = SNOW_AMOUNT
	snowfall.lifetime = SNOW_LIFETIME
	snowfall.emitting = false
	# Emitted from a strip along the top of the window, a little wider than the
	# arena so the drift does not leave the edges bare.
	snowfall.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snowfall.emission_rect_extents = Vector2(clip.size.x / 2.0 + 60.0, 8.0)
	snowfall.position = Vector2(clip.size.x / 2.0, -16.0)
	snowfall.direction = Vector2.DOWN
	snowfall.spread = 14.0
	snowfall.initial_velocity_min = 95.0
	snowfall.initial_velocity_max = 165.0
	snowfall.gravity = Vector2(-14.0, 12.0)
	# A little curl on each flake, so they wander down instead of falling on
	# rails -- the one thing that separates snow from rain at this scale.
	snowfall.orbit_velocity_min = -0.04
	snowfall.orbit_velocity_max = 0.04
	# Fat and nearly solid rather than a fine mist: the ground they fall over is
	# already white, and anything subtler than this is lost in the painted snow
	# of the map itself.
	snowfall.scale_amount_min = 2.6
	snowfall.scale_amount_max = 5.6
	# Fades in as it enters and out again well before the bottom, so no flake is
	# ever seen being cut off by the edge of the window.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(0.86, 0.94, 1.0, 0))
	ramp.add_point(0.10, Color(1, 1, 1, 1.0))
	ramp.add_point(0.80, Color(0.90, 0.96, 1.0, 0.9))
	snowfall.color_ramp = ramp
	clip.add_child(snowfall)

# ------------------------------------------------------------------- emberfall
#
# The weather for the last phase, and the snow's opposite in every way that
# matters: it comes off the ground rather than out of the sky, it goes up, and
# it is thin where the snow is thick. Same window, same rule about staying off
# the merge tray -- a tray painted before the fight has no business catching
# sparks through its own frame.
#
# Far fewer particles than the snow, and slower. Snow is weather the player is
# fighting in; embers are the ground the player is fighting on breathing, and a
# blizzard of them would read as a screen effect rather than as a place.

const EMBER_AMOUNT := 40
const EMBER_LIFETIME := 6.0

var emberfall: CPUParticles2D

func _build_emberfall(root: Control) -> void:
	var clip := _arena_window(root)

	emberfall = CPUParticles2D.new()
	emberfall.texture = FxUtil.dot_texture()
	emberfall.amount = EMBER_AMOUNT
	emberfall.lifetime = EMBER_LIFETIME
	emberfall.emitting = false
	# Off the whole floor of the window rather than a strip: a spark is lifting
	# off whatever ground happens to be under it, so it starts everywhere.
	emberfall.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emberfall.emission_rect_extents = Vector2(clip.size.x / 2.0, clip.size.y / 2.0)
	emberfall.position = clip.size / 2.0
	emberfall.direction = Vector2.UP
	emberfall.spread = 22.0
	emberfall.initial_velocity_min = 26.0
	emberfall.initial_velocity_max = 62.0
	# Upward, so a spark keeps climbing rather than arcing over and falling back
	# -- what lifts these is the heat coming off the rock, not a throw.
	emberfall.gravity = Vector2(8.0, -18.0)
	emberfall.orbit_velocity_min = -0.05
	emberfall.orbit_velocity_max = 0.05
	emberfall.scale_amount_min = 1.4
	emberfall.scale_amount_max = 3.4
	# Struck bright, cooling to red on the way up and gone before the top of the
	# window, so no spark is ever seen being cut off by the edge of it.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.86, 0.46, 0))
	ramp.set_color(1, Color(0.86, 0.20, 0.08, 0))
	ramp.add_point(0.12, Color(1.0, 0.80, 0.38, 1.0))
	ramp.add_point(0.70, Color(1.0, 0.46, 0.16, 0.75))
	emberfall.color_ramp = ramp
	clip.add_child(emberfall)

# The window the fight is seen through, as a control that clips whatever is put
# inside it. Both weathers hang in one of these, which is what keeps flakes and
# sparks in front of the soldiers and off the tray.
func _arena_window(root: Control) -> Control:
	var clip := Control.new()
	clip.position = Vector2(ARENA_AREA_LEFT, ARENA_AREA_TOP)
	clip.size = Vector2(
		ARENA_AREA_RIGHT - ARENA_AREA_LEFT, ARENA_AREA_BOTTOM - ARENA_AREA_TOP)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)
	return clip

# --------------------------------------------------------------- defeat panel
#
# One painted plate (art/defeat.png) does the whole screen: frame, title,
# subtitle and the RESTART plate are all in the picture. The real button is an
# invisible hit box laid exactly over the painted one, the same way the SEND
# button works -- all it adds is the press feedback a painting cannot give.
#
# The art already carries its own alpha, fading to nothing at the edges, so it
# sits straight on the dim without a card behind it.

const DEFEAT_ART := "res://art/defeat.png"
const DEFEAT_ART_SIZE := Vector2(1566.0, 1005.0)
const DEFEAT_WIDTH := 1000.0
# Where the RESTART plate sits inside the painting, as a fraction of it. Kept as
# fractions so the hit box follows if the plate is ever drawn at another size.
const DEFEAT_BUTTON := Rect2(0.316, 0.741, 0.374, 0.155)

func _build_defeat_panel(root: Control) -> void:
	game_over_panel = Control.new()
	game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_panel.visible = false
	root.add_child(game_over_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.02, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_panel.add_child(dim)

	var art_size := Vector2(DEFEAT_WIDTH,
		DEFEAT_WIDTH * DEFEAT_ART_SIZE.y / DEFEAT_ART_SIZE.x)
	# Centred on the arena rather than on the screen: the middle of the screen is
	# the top of the merge tray, and the plate ended up straddling the two.
	var art_pos := Vector2((VIEW_W - art_size.x) / 2.0, ARENA_CENTER.y - art_size.y / 2.0)

	var plate := TextureRect.new()
	plate.texture = load(DEFEAT_ART)
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Without this the control's minimum size is the texture's own 1566x1005 and
	# the plate ignores the size it is given, hanging off the right of the screen.
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.position = art_pos
	plate.size = art_size
	plate.pivot_offset = art_size / 2.0
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_panel.add_child(plate)
	defeat_plate = plate

	var restart := Button.new()
	restart.text = ""
	restart.position = art_pos + Vector2(
		DEFEAT_BUTTON.position.x * art_size.x, DEFEAT_BUTTON.position.y * art_size.y)
	restart.size = Vector2(
		DEFEAT_BUTTON.size.x * art_size.x, DEFEAT_BUTTON.size.y * art_size.y)
	restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		restart.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	game_over_panel.add_child(restart)

	# The painted plate cannot light up on its own, so a wash sits over it.
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(1, 0.5, 0.4, 0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	restart.add_child(wash)
	restart.button_down.connect(func() -> void: wash.color = Color(1, 0.5, 0.4, 0.18))
	restart.button_up.connect(func() -> void: wash.color = Color(1, 0.5, 0.4, 0.0))

	# Essence is MetaManager's, not the painting's -- there was never a line in
	# the art for it, so it floats in the clear band below the plate rather
	# than pretending to be part of what was drawn.
	essence_label = Label.new()
	essence_label.position = Vector2(0, art_pos.y + art_size.y + 18.0)
	essence_label.size = Vector2(VIEW_W, 60.0)
	essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	essence_label.add_theme_font_size_override("font_size", 34)
	essence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(essence_label, UIStyle.ACCENT_TEAL, 6)
	essence_label.modulate.a = 0.0
	game_over_panel.add_child(essence_label)

# Drops in rather than appearing: the plate falls the last of the way and
# settles, which is the difference between a defeat screen and a dialog box.
func _show_defeat_panel() -> void:
	game_over_panel.visible = true
	if defeat_plate == null:
		return
	var home: float = defeat_plate.position.y
	defeat_plate.position.y = home - 60.0
	defeat_plate.modulate.a = 0.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(defeat_plate, "modulate:a", 1.0, 0.22)
	tw.parallel().tween_property(defeat_plate, "position:y", home, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if essence_label != null:
		var etw := create_tween()
		etw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		etw.tween_interval(0.3)
		etw.tween_property(essence_label, "modulate:a", 1.0, 0.3)

func _on_fortress_hp_changed(current: float, max_hp: float) -> void:
	_update_hearts(current, max_hp)
	if _last_fortress_hp >= 0.0 and current < _last_fortress_hp:
		_clean_streak = 0
	_last_fortress_hp = current

func _on_fortress_died() -> void:
	_shake(18.0, 0.5)
	var gained: int = _bank_run()
	if essence_label != null:
		essence_label.text = "+%d ESSENCE" % gained
	GameManager.trigger_game_over()
	_show_defeat_panel()

# Repairs between waves. Every wave patches the walls up a little; the tenth
# and its multiples -- the ones that come after an upgrade, and before a boss --
# patch them up more.
const WAVE_HEAL := 20.0
const WAVE_HEAL_MILESTONE := 30.0

func _on_wave_started(wave_number: int) -> void:
	# The sun goes down over the run rather than at any one moment in it: every
	# wave moves the light a little and no wave announces that it did.
	lighting.set_wave(wave_number)

	# Wave 1 starts at full health, so there is nothing to repair yet.
	if wave_number > 1:
		fortress.heal(WAVE_HEAL_MILESTONE if wave_number % 10 == 0 else WAVE_HEAL)

	# The counter in the corner always keeps up; the big plate is the announcement
	# and that one wave gets to skip it.
	_set_wave_number(wave_plate, wave_number)

	# Wave 30 is the golem's and wave 50 the dragon's, and each ends in a
	# changeover. Their plates are left off entirely so nothing of the wave's
	# own is still on the screen when the announcement drops into the same place.
	if wave_number == WaveManager.WINTER_WAVE or wave_number == WaveManager.LAVA_WAVE:
		_hide_wave_banner()
		return

	_set_wave_number(wave_banner, wave_number)
	wave_banner_wrap.modulate = Color(1, 1, 1, 0)
	wave_banner_wrap.scale = Vector2(0.85, 0.85)
	wave_banner_wrap.pivot_offset = wave_banner_wrap.size / 2.0
	if _wave_banner_tween != null and _wave_banner_tween.is_valid():
		_wave_banner_tween.kill()
	_wave_banner_tween = create_tween()
	var tw := _wave_banner_tween
	tw.tween_property(wave_banner_wrap, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(wave_banner_wrap, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(wave_banner_wrap, "modulate:a", 0.0, 0.4)

	_show_modifier_banner(WaveManager.modifier_for(wave_number))

# The name of whatever twist WaveManager put on this wave, held up just long
# enough to be read before the fight starts -- "" plays it silent, which is
# every ordinary wave.
func _show_modifier_banner(modifier_id: String) -> void:
	if modifier_banner == null or modifier_id == "":
		return
	modifier_banner.text = WaveManager.modifier_name(modifier_id)
	modifier_banner.modulate.a = 0.0
	modifier_banner.scale = Vector2(0.8, 0.8)
	var tw2 := create_tween()
	tw2.tween_property(modifier_banner, "modulate:a", 1.0, 0.18)
	tw2.parallel().tween_property(modifier_banner, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_interval(0.9)
	tw2.tween_property(modifier_banner, "modulate:a", 0.0, 0.4)

# Takes the plate off the screen and stops whatever was animating it. Kept as
# one call because a plate that is merely transparent is still being tweened,
# and the next thing to fade it up would be fighting a tween that is fading it
# back down.
func _hide_wave_banner() -> void:
	if _wave_banner_tween != null and _wave_banner_tween.is_valid():
		_wave_banner_tween.kill()
	_wave_banner_tween = null
	if wave_banner_wrap != null:
		wave_banner_wrap.modulate = Color(1, 1, 1, 0)

# ------------------------------------------------------------------ upgrades

# Waves cleared with the fortress untouched, back to back. Avoiding the
# overflow line or taking a hit and still holding is its own reward already;
# this is the one on top for the run that never had to cash either in.
const CLEAN_STREAK_MILESTONES := [3, 5, 10, 15, 20, 25, 30]

func _is_clean_streak_milestone(streak: int) -> bool:
	return CLEAN_STREAK_MILESTONES.has(streak) or (streak > 30 and streak % 10 == 0)

func _on_wave_cleared(wave_number: int) -> void:
	fortress.set_level(1 + wave_number / 10)
	if fortress != null and fortress.hp >= fortress.max_hp:
		_clean_streak += 1
		MetaManager.record_clean_streak(_clean_streak)
		if _is_clean_streak_milestone(_clean_streak):
			_pay_out(20 + wave_number * 2, fortress.global_position)
		if WaveManager.modifier_for(wave_number) == "brutal":
			MetaManager.grant_achievement("storm_weathered")
	if wave_number == WaveManager.WINTER_WAVE and _run_start_ms > 0:
		MetaManager.record_wave30_time((Time.get_ticks_msec() - _run_start_ms) / 1000.0)
	# The golem's wave and the dragon's pay out like any other tenth, but the
	# changeover each ends in is the reward the player actually came for, so it
	# goes first and hands over to the upgrade screen when it is done.
	if wave_number == WaveManager.WINTER_WAVE:
		_play_winter_change()
		return
	if wave_number == WaveManager.LAVA_WAVE:
		_play_lava_change()
		return
	if wave_number % 10 == 0:
		_show_upgrade_selection()

# Wave 20 pays out in the merge upgrade rather than a stat bump: the tray stops
# dropping wood, bows and crystals and starts dropping gold, emeralds and
# totems. Nothing to choose -- it is announced and taken.
const MERGE_UPGRADE_WAVE := 20

func _show_upgrade_selection() -> void:
	if WaveManager.current_wave == MERGE_UPGRADE_WAVE:
		_show_merge_upgrade()
		return
	var choice_count: int = UPGRADE_CARD_SLOTS if MetaManager.fourth_card_unlocked else UPGRADE_CHOICES
	var choices: Array = UpgradeManager.get_random_choices(choice_count)

	upgrade_card_ids = []
	var cards: Array = []
	for id in choices:
		var d: Dictionary = UpgradeManager.get_def(String(id))
		var is_rare: bool = String(d.get("rarity", "common")) == "rare"
		upgrade_card_ids.append(String(id))
		cards.append({
			"name": String(d.get("name", id)),
			"desc": String(d.get("desc", "")),
			"art": UpgradeManager.get_art_path(String(id)),
			"accent": UIStyle.ACCENT_GOLD if is_rare \
				else UIStyle.category_color(String(d.get("category", "general"))),
			"level": UpgradeManager.get_level(String(id)),
			"rare": is_rare,
		})

	# The plate already says CHOOSE AN UPGRADE and how to answer it; the only
	# line on it that has to know anything about this run is the wave.
	upgrade_panel.open({"subtitle": "WAVE %d COMPLETE" % WaveManager.current_wave}, cards)
	GameManager.enter_upgrade_selection()
	get_tree().paused = true

func _on_upgrade_card_pressed(index: int) -> void:
	if index < 0 or index >= upgrade_card_ids.size():
		return
	var id: String = upgrade_card_ids[index]
	if id == "":
		return

	UpgradeManager.apply(id)
	match id:
		"fortress_max_hp":
			fortress.grow_max_hp(FORTRESS_BASE_HP * 0.2)
		"fortress_heal":
			fortress.heal_percent(FORTRESS_BASE_HP, 0.2)

	upgrade_panel.close()
	get_tree().paused = false
	GameManager.resume_playing()
	WaveManager.resume_after_upgrade()









