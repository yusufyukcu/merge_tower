extends Node

const Projectile = preload("res://scripts/fx/Projectile.gd")
const ImpactEffect = preload("res://scripts/fx/ImpactEffect.gd")
const Shockwave = preload("res://scripts/fx/Shockwave.gd")
const ArrowRain = preload("res://scripts/fx/ArrowRain.gd")
const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# Ticks all defenders/enemies each physics frame in a circular arena centered
# on the fortress, organised into four lanes -- north, east, south, west.
#
# Enemies walk in down one lane and are stopped by the defenders standing on
# that same lane, and only those: a soldier on the north lane does nothing about
# what comes from the south. While one unit on a lane still lives -- soldier or
# shooter -- nothing on that lane reaches the fortress; an enemy either pairs off
# with a free one or queues behind the fight waiting for an opening. Only when
# the whole lane is wiped out does it become an open road.
#
# The one exception is the goblin, which ignores the line entirely and runs for
# the fortress past whoever is standing there.
#
# Ranged defenders sit on an inner ring behind their lane's soldiers and shoot
# whichever enemy is furthest advanced within true 2D range, lane regardless.
# They are safe behind the soldiers, but they are not untouchable: once the line
# in front of them falls, they are what the lane has left and the enemies close
# on them next.

var defenders: Array = []
var enemies: Array = []
# Planted by shamans. They are scenery with a rule attached: nothing can attack
# them, and everything of ours standing inside one swings faster.
var totems: Array = []
# Circles of cold opened by ice wizards. The enemy's answer to a totem: they
# expire on their own, so unlike totems nothing has to take them down.
var fields: Array = []
var fortress: Fortress = null
# Where anything painted on the floor goes: above the arena art, under every
# unit, and outside the y-sorting the fight uses.
var ground_layer: Node2D = null
# Above the fight and outside its y-sorting: where an ability's effects go, so
# nothing an ability throws ever slips behind a body it is landing on.
var fx_layer: Node2D = null
var fortress_center: Vector2 = Vector2.ZERO
var defense_radius: float = 0.0
var fortress_hit_radius: float = 0.0

func reset_state() -> void:
	defenders = []
	enemies = []
	totems = []
	fields = []
	fortress = null
	fortress_center = Vector2.ZERO
	focus_enemy = null

func init(p_fortress: Fortress, p_center: Vector2, p_defense_radius: float,
		p_fortress_hit_radius: float, p_ground_layer: Node2D = null,
		p_fx_layer: Node2D = null) -> void:
	fortress = p_fortress
	fortress_center = p_center
	defense_radius = p_defense_radius
	fortress_hit_radius = p_fortress_hit_radius
	ground_layer = p_ground_layer
	fx_layer = p_fx_layer

# ------------------------------------------------------------------- focus
#
# One enemy the player has picked out with a finger, and the whole line turns on
# it. Until now the player could choose where a soldier stood and nothing else:
# the fight itself picked every target, shooters took whatever was furthest
# advanced and soldiers took whatever walked into them, and a wizard about to
# freeze half the line could not be answered even with the board to do it with.
#
# What focusing changes is the choice of target and nothing else. Nobody leaves
# the slot they are holding, nobody shoots further than they could anyway, and a
# soldier still defends himself against the body in front of him if the focus is
# out of reach -- so this is an order given to a line, not a leash.
#
# It clears itself the moment the target dies, which is the only sensible thing
# for it to do: the alternative is a line still aiming at a corpse.

signal focus_changed(enemy: Enemy)

var focus_enemy: Enemy = null

func set_focus(enemy: Enemy) -> void:
	if enemy != null and (not is_instance_valid(enemy) or not enemy.is_alive()):
		enemy = null
	if focus_enemy == enemy:
		return
	focus_enemy = enemy
	focus_changed.emit(focus_enemy)

func clear_focus() -> void:
	set_focus(null)

# The focus as it actually stands right now. Every reader goes through this
# rather than through the field, because a target can die between one frame and
# the next and no caller should have to remember that.
func focus_target() -> Enemy:
	if focus_enemy != null and (not is_instance_valid(focus_enemy) or not focus_enemy.is_alive()):
		set_focus(null)
	return focus_enemy

# The focus if this particular unit can actually reach it, and null otherwise --
# which is what keeps an order from stopping a soldier fighting.
func focus_within(defender: Defender) -> Enemy:
	var e: Enemy = focus_target()
	if e == null or defender == null or not is_instance_valid(defender):
		return null
	if defender.global_position.distance_to(e.global_position) > defender.attack_range:
		return null
	return e

func add_defender(defender: Defender) -> void:
	defenders.append(defender)
	defender.died.connect(_on_defender_died)

func add_enemy(enemy: Enemy) -> void:
	enemies.append(enemy)
	enemy.died.connect(_on_enemy_died)

func _on_defender_died(defender: Defender) -> void:
	defenders.erase(defender)
	defender.claimed_by = null
	defender.engaged_enemy = null
	# The circle belongs to whoever raised it: kill the shaman and the ground
	# goes dark again.
	if defender.totem != null and is_instance_valid(defender.totem):
		totems.erase(defender.totem)
		defender.totem.dissolve()
	defender.totem = null
	for e in enemies:
		if is_instance_valid(e) and e.target_defender == defender:
			e.target_defender = null
			e.state = Enemy.State.MOVING

func _on_enemy_died(enemy: Enemy) -> void:
	enemies.erase(enemy)
	_release_claim(enemy)
	# The order dies with the body it was given about.
	if focus_enemy == enemy:
		set_focus(null)

# Lets go of whatever defender this enemy had picked out, so the slot opens back
# up the instant it dies, loses its target, or finds the lane cleared.
func _release_claim(enemy: Enemy) -> void:
	var d: Defender = enemy.target_defender
	enemy.target_defender = null
	if d == null or not is_instance_valid(d):
		return
	if d.claimed_by == enemy:
		d.claimed_by = null
	if d.engaged_enemy == enemy:
		d.engaged_enemy = null

# Everything that had picked this unit out lets go of it, exactly as it would if
# the unit had fallen. Called when the player takes hold of one: an enemy that
# had squared up against a soldier has to look for another when that soldier is
# lifted off the board, rather than following him across the field and standing
# in the middle of somebody else's lane once he is set down.
func release_defender_claims(defender: Defender) -> void:
	if defender == null or not is_instance_valid(defender):
		return
	defender.claimed_by = null
	defender.engaged_enemy = null
	for e in enemies:
		if is_instance_valid(e) and e.target_defender == defender:
			e.target_defender = null
			e.state = Enemy.State.MOVING

# A shaman's circle belongs where the shaman is standing. Move it and the post
# it planted goes back into the ground; the ritual starts over from the new spot
# a beat after it lands, which is the same beat a freshly sent one waits.
func uproot_totem(defender: Defender) -> void:
	if defender == null or not is_instance_valid(defender):
		return
	if defender.totem != null and is_instance_valid(defender.totem):
		totems.erase(defender.totem)
		defender.totem.dissolve()
	defender.totem = null
	defender.has_planted = false
	defender._attack_timer = 0.45

func _angle_of(pos: Vector2) -> float:
	return (pos - fortress_center).angle()

# Enemies stop this far outside the defense ring to fight, so the two lines
# stand facing each other instead of drawing on top of one another. At 46 they
# did draw on top of one another: a goblin sat squarely on the soldier it was
# fighting and hid him, and the drawn swing needs the ground in front of the
# body to be visible for the stroke to read at all.
const ENGAGE_STANDOFF := 84.0
# Rank spacing in the queue. At 50 the bodies waiting their turn stood inside
# one another -- an orc is drawn over 100px across.
const QUEUE_SPACING := 96.0

# ------------------------------------------------------------------ the walk
#
# Every body on the field is placed by two numbers: the angle it stands at
# around the fortress and how far out from it. This is the only thing that
# changes either of them during a walk, and it only ever changes them by what
# the body could actually have covered in the time -- which is what stops an
# enemy ever being somewhere it was not a moment ago.
#
# Both halves come out of one budget, priced in ground rather than in radians:
# a step sideways costs the arc it sweeps, so it costs more the further out the
# body is standing, exactly as it would to walk it. A body that has to cross the
# lane as well as close on it therefore does both at once and finishes them
# together, instead of doing one at a walk and the other at a flicker.
#
# Both of the ways a body used to jump were here. Sideways was a flat 2.4 rad/s,
# which out on the defense ring is better than 700px a second -- fifteen times
# what anything on this field walks at -- so killing the soldier in front of you
# and appearing beside the next one is precisely what it looked like. And the
# distance was a floor rather than a target: it could only ever be walked down,
# so anything that raised it -- a soldier dropped into the lane further out, a
# place lost in the queue -- moved the body the whole way in a single frame.
#
# Answers with whether the body has arrived, which is the cue to stop walking
# and start fighting.

# Close enough to be standing there, in pixels of ground.
const ARRIVE_EPSILON := 1.0

func _approach(enemy: Enemy, want_angle: float, want_radius: float, delta: float) -> bool:
	var d_angle: float = wrapf(want_angle - enemy.angle, -PI, PI)
	var d_radius: float = want_radius - enemy.current_radius
	# The two are covered at the same time, so what is left is the diagonal
	# across them rather than the sum of the two sides -- which is what makes the
	# body cross the ground at its own speed and not at some fraction of it.
	var remaining: float = sqrt(
		pow(d_angle * maxf(enemy.current_radius, 1.0), 2.0) + pow(d_radius, 2.0))
	if remaining <= ARRIVE_EPSILON:
		enemy.angle = want_angle
		enemy.current_radius = want_radius
		enemy.update_position(fortress_center)
		return true

	var k: float = minf(1.0, enemy.speed * delta / remaining)
	enemy.angle += d_angle * k
	enemy.current_radius += d_radius * k
	enemy.update_position(fortress_center)
	return k >= 1.0

# Where a body stops to fight the unit it has picked out. Normally that is a
# standoff's worth of ground outside it: the enemy came in off the field, and
# the two lines end up facing each other across a gap rather than drawing on top
# of one another.
#
# An enemy that has already broken through, though, is on the wrong side of that
# rule -- it is standing inside the ring when a fresh soldier lands in the lane
# behind it, and sending it back out would walk it straight through the body it
# is meant to be fighting. So the gap is opened on whichever side the enemy is
# already standing and it turns and fights from there. The inside is only taken
# when there is real ground between the soldier and the fortress wall to take;
# otherwise the body walks back out the long way, which at least it now does at
# a walk.
func _engage_radius(enemy: Enemy, target: Defender) -> float:
	var target_radius: float = fortress_center.distance_to(target.global_position)
	var inner: float = target_radius - _standoff(enemy)
	if enemy.current_radius < target_radius and inner >= fortress_hit_radius:
		return inner
	return target_radius + _standoff(enemy)

# A lane holds as long as one of its units is still standing -- soldier or, once
# the soldiers are gone, the shooters behind them.
func lane_is_held(lane: int) -> bool:
	for d in defenders:
		if not is_instance_valid(d):
			continue
		if d.lane == lane and d.is_alive():
			return true
	return false

# Where the fighting happens on a lane: the ring whichever surviving unit stands
# furthest out is on. With the soldiers dead that is the backline itself, so the
# queue closes in on the shooters rather than holding an empty line.
func _lane_front_radius(lane: int) -> float:
	var r := 0.0
	for d in defenders:
		if not is_instance_valid(d) or not d.is_alive() or d.lane != lane:
			continue
		# A unit in the player's hand is not standing anywhere: measure the line
		# off it and the queue behind it would walk in and out as the finger moved.
		if d.held:
			continue
		r = maxf(r, fortress_center.distance_to(d.global_position))
	if r <= 0.0:
		r = defense_radius
	return r

# How far out this particular body stops. A goblin and a golem cannot share one
# figure: the golem is drawn several times as wide, and a flat standoff parked
# it on top of the line it was meant to be fighting.
func _standoff(enemy: Enemy) -> float:
	return ENGAGE_STANDOFF + maxf(0.0, enemy._radius - 28.0) * 0.9

# Soldiers are always taken before shooters: the backline is only reachable
# once the line standing in front of it is gone. Among equals, the nearest one
# across the lane, so the enemy takes the shortest walk to a fight.
const RANGED_RANK_PENALTY := 100.0

func _find_available_defender(enemy: Enemy) -> Defender:
	# A wizard never squares up on anybody: it has nothing to hit with, so it
	# takes no place in the line and simply stops behind whoever is holding it.
	# Nor does the dragon -- it burns the line from above and outside it.
	if enemy.has_field() or enemy.has_breath():
		return null

	var best: Defender = null
	var best_key := INF
	for d in defenders:
		if not is_instance_valid(d) or d.lane != enemy.lane or not d.is_alive():
			continue
		# Nothing squares up against a unit the player is holding: it has no
		# place on the ground to be squared up against yet.
		if d.held:
			continue
		if d.engaged_enemy != null and d.engaged_enemy != enemy \
				and is_instance_valid(d.engaged_enemy) and d.engaged_enemy.is_alive():
			continue
		if d.claimed_by != null and d.claimed_by != enemy \
				and is_instance_valid(d.claimed_by) and d.claimed_by.is_alive():
			continue
		var key: float = absf(wrapf(_angle_of(d.global_position) - enemy.angle, -PI, PI))
		if d.role != "melee":
			key += RANGED_RANK_PENALTY
		if key < best_key:
			best_key = key
			best = d
	return best

# Hands every enemy waiting at a held lane its place in the queue. Enemies
# already trading blows -- and those still walking onto a unit they have claimed
# -- hold the front rank, so newcomers stack up behind them in spawn order
# rather than walking into the same spot. Goblins never queue: the line is not
# there for them.
func _update_lane_queues() -> void:
	var taken: Dictionary = {}
	for e in enemies:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		if e.state == Enemy.State.ENGAGING or e.target_defender != null:
			taken[e.lane] = int(taken.get(e.lane, 0)) + 1

	for e in enemies:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		if e.ignores_line or e.target_defender != null \
				or e.state != Enemy.State.MOVING or not lane_is_held(e.lane):
			e.queue_offset = 0.0
			continue
		var idx: int = int(taken.get(e.lane, 0))
		taken[e.lane] = idx + 1
		e.queue_offset = idx * QUEUE_SPACING

func _find_ranged_target(defender: Defender) -> Enemy:
	# An order the player gave outranks the standing rule, but only within the
	# reach this shooter already had.
	var picked: Enemy = focus_within(defender)
	if picked != null:
		return picked

	var best: Enemy = null
	var best_radius := INF
	for e in enemies:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		if defender.global_position.distance_to(e.global_position) > defender.attack_range:
			continue
		if e.current_radius < best_radius:
			best_radius = e.current_radius
			best = e
	return best

func _physics_process(delta: float) -> void:
	if fortress == null or not is_instance_valid(fortress):
		return
	if not GameManager.is_playing():
		return

	_update_lane_queues()

	_update_auras()

	for defender in defenders.duplicate():
		if not is_instance_valid(defender):
			continue
		# Both of these run whatever else is happening to the body. An ability's
		# cooldown is the price of the last cast and a rally is a gift already
		# given, and neither should be paused by the unit being iced or lifted.
		defender.tick_ability(delta)
		defender.tick_rally(delta)
		# Iced solid: it holds its slot and its lane, and can still be killed --
		# it simply does not get a turn until it thaws.
		if defender.tick_frozen(delta):
			continue
		# Up in the player's hand, on its way to somewhere else on the board. Same
		# rule as the ice: the lane it came from still counts as held, but a unit
		# in the air neither swings nor plants until it is set down.
		if defender.held:
			continue
		match defender.role:
			"melee":
				defender.process_combat(delta)
			"support":
				_process_support_defender(defender, delta)
			_:
				_process_ranged_defender(defender, delta)

	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		_process_enemy(enemy, delta)
		if not is_instance_valid(enemy):
			continue
		if enemy.has_breath():
			_process_breath(enemy, delta)
		elif enemy.is_boss:
			_process_boss_slam(enemy, delta)
		elif enemy.has_dash():
			_process_dash(enemy, delta)
		elif enemy.has_field():
			_process_caster(enemy, delta)

func _process_boss_slam(enemy: Enemy, delta: float) -> void:
	enemy._slam_timer -= delta
	if enemy._slam_timer > 0.0:
		return
	enemy._slam_timer = enemy.slam_interval
	# Lands with the drawn slam rather than the instant the timer runs out, so
	# the whole line takes it on the frame the ground breaks.
	var slam: float = enemy.slam_damage
	enemy.play_attack(fortress_center - enemy.global_position, func() -> void:
		for d in defenders.duplicate():
			if is_instance_valid(d) and d.is_alive():
				d.take_damage(slam))

# The ice wolf's charge. The cooldown runs wherever the animal is -- one that
# spends its first seconds walking arrives with the charge in hand -- but it is
# only spent on a soldier it is already squared up against, so a wolf never
# throws it at empty ground or at the fortress wall.
func _process_dash(enemy: Enemy, delta: float) -> void:
	if not enemy.dash_ready(delta) or enemy.state != Enemy.State.ENGAGING:
		return
	var target: Defender = enemy.target_defender
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return

	enemy.start_dash_cooldown()
	# The bite is pushed past the end of the charge: one animation at a time, or
	# the wolf swaps frame sets halfway across the gap.
	enemy._attack_timer = maxf(enemy._attack_timer, Enemy.DASH_TOTAL)

	var dealt: float = enemy.damage * enemy.dash_damage_mult
	var hold: float = enemy.dash_freeze
	# Landed on the frame the animal comes down, not when the timer ran out, and
	# checked again then: the soldier it launched at may already be dead.
	enemy.play_dash(target.global_position - enemy.global_position, func() -> void:
		if not is_instance_valid(target) or not target.is_alive():
			return
		target.take_damage(dealt)
		if target.is_alive():
			target.freeze(hold))

# The ice wizard. It never fights: it stops behind whatever is holding the lane
# and opens a circle of cold over the line, and everything of ours standing in
# that circle swings slower until it closes.
#
# The cooldown runs wherever the wizard is, but a circle is only ever opened
# where there is somebody to slow -- a wizard that has walked into an empty lane
# holds its cast rather than lighting up bare ground.
func _process_caster(enemy: Enemy, delta: float) -> void:
	if not enemy.cast_ready(delta):
		return
	var target: Defender = _nearest_defender(enemy.global_position, enemy.field_range)
	if target == null:
		return

	enemy.start_cast_cooldown()
	var at: Vector2 = target.global_position
	var radius: float = enemy.field_radius
	var slow: float = enemy.field_slow
	var life: float = enemy.field_time
	var art: String = enemy.field_art
	# Opened on the frame the wizard raises the orb rather than when the timer
	# ran out, so the drawing and the circle agree. Numbers only in the lambda:
	# the wizard is routinely shot down mid-cast, and the circle it already
	# started should still land.
	enemy.play_attack(at - enemy.global_position, func() -> void:
		_open_frost_field(at, radius, slow, life, art))

# The ice dragon's breath.
#
# It is a state rather than a blow: it lights when there is something in range
# and stays lit, and the only thing killing a soldier changes is which way the
# stream is pointed. The damage is dealt around wherever the stream has actually
# swung to -- not around its target -- so a sweep from one soldier to the next
# burns the ground and anybody standing on it in between.
func _process_breath(enemy: Enemy, delta: float) -> void:
	# It has to have arrived first: a dragon still crossing the map is not
	# burning anything.
	if enemy.entry_timer > 0.0:
		return

	var target: Defender = _breath_target(enemy)
	if target == null:
		# Nothing left in range. This is the one thing that puts it out.
		enemy.stop_breath()
		return

	enemy.set_breath_target(target.global_position)
	if not enemy.is_breathing():
		enemy.start_breath()
		return
	if not enemy.breath_live():
		return

	enemy._breath_tick -= delta
	if enemy._breath_tick > 0.0:
		return
	enemy._breath_tick = enemy.breath_interval

	var at: Vector2 = enemy.breath_point()
	var dealt: float = enemy.damage
	var reach: float = enemy.breath_radius
	for d in defenders.duplicate():
		if not is_instance_valid(d) or not d.is_alive():
			continue
		if d.global_position.distance_to(at) <= reach:
			d.take_damage(dealt)

# What the stream goes to next. The one it is already burning stays the target
# while it lives -- a dragon that reconsidered every tick would never finish
# anybody -- and when it dies the nearest to the stream is picked up next, which
# is what makes the sweep short and readable rather than a jump across the map.
func _breath_target(enemy: Enemy) -> Defender:
	var current: Defender = enemy._breath_focus
	if current != null and is_instance_valid(current) and current.is_alive() \
			and enemy.global_position.distance_to(current.global_position) <= enemy.breath_range:
		return current
	# Nearest to where the stream already is rather than to the dragon, so the
	# sweep onto the next body is the short way round.
	var next: Defender = _nearest_defender(enemy.breath_point(), enemy.breath_range)
	if next == null:
		next = _nearest_defender(enemy.global_position, enemy.breath_range)
	enemy._breath_focus = next
	return next

func _nearest_defender(from: Vector2, within: float) -> Defender:
	var best: Defender = null
	var best_d := INF
	for d in defenders:
		if not is_instance_valid(d) or not d.is_alive() or d.held:
			continue
		var dist: float = from.distance_to(d.global_position)
		if dist > within or dist >= best_d:
			continue
		best_d = dist
		best = d
	return best

func _open_frost_field(at: Vector2, radius: float, slow: float, life: float,
		art: String) -> void:
	var host: Node2D = ground_layer
	if host == null or not is_instance_valid(host):
		return
	var field := FrostField.new()
	host.add_child(field)
	field.global_position = at
	field.setup(art, radius, slow, life)
	fields.append(field)

# Circles do not stack: standing in two of them gives the better of the two and
# not the sum, because two shamans should be worth more ground covered rather
# than a unit somewhere in the middle attacking twice as fast again. The same
# rule runs the other way for the wizards' fields -- two of them overlapping is
# the deeper of the two chills, not the sum.
func _update_auras() -> void:
	# Fields run out on their own, so this is where the dead ones are dropped.
	# Walked backwards and edited in place: removing from the front of an array
	# being iterated forwards skips the entry that slides into the gap.
	for i in range(fields.size() - 1, -1, -1):
		if not is_instance_valid(fields[i]):
			fields.remove_at(i)

	for d in defenders:
		if not is_instance_valid(d):
			continue
		var best := 1.0
		for t in totems:
			if is_instance_valid(t) and t.covers(d.global_position):
				best = maxf(best, t.haste)
		d.aura_haste = best

		var chill := 1.0
		for f in fields:
			if f.covers(d.global_position):
				chill = minf(chill, f.slow)
		d.aura_slow = chill

# A shaman never fights. Once it is standing it performs its ritual, and what
# the ritual leaves behind is the totem. After that it has nothing left to do
# but keep the circle open.
func _process_support_defender(defender: Defender, delta: float) -> void:
	if not defender.is_alive() or defender.has_planted:
		return
	defender._attack_timer -= delta
	if defender._attack_timer > 0.0:
		return
	defender.has_planted = true
	defender.play_attack(_outward(defender), func() -> void: _plant_totem(defender))

# Away from the fortress: the post goes down in front of the shaman so its
# circle reaches over the line it is meant to be helping, not out behind it.
const TOTEM_STEP := 66.0

func _outward(defender: Defender) -> Vector2:
	var d: Vector2 = defender.global_position - fortress_center
	return d.normalized() if d.length() > 0.001 else Vector2.RIGHT

func _plant_totem(defender: Defender) -> void:
	if not is_instance_valid(defender) or not defender.is_alive():
		return
	var host: Node2D = ground_layer if ground_layer != null else defender.get_parent()
	if host == null:
		return

	var out: Vector2 = _outward(defender)
	# Sideways by the slot it stands in, so two shamans on one lane do not drive
	# their posts into the same patch of ground.
	var side := Vector2(-out.y, out.x) * (float(defender.slot) - 0.5) * 52.0

	var t := Totem.new()
	host.add_child(t)
	t.global_position = defender.global_position + out * TOTEM_STEP + side
	t.setup(defender.totem_art, defender.totem_radius, defender.totem_haste,
		clampf(defender._radius / 38.0, 1.0, 1.6))
	defender.totem = t
	totems.append(t)

func _process_ranged_defender(defender: Defender, delta: float) -> void:
	if not defender.is_alive():
		return
	defender._attack_timer -= delta
	if defender._attack_timer > 0.0:
		return
	var target := _find_ranged_target(defender)
	if target == null:
		return
	defender._attack_timer = defender.effective_interval()
	# The shot leaves on the frame the string is released, not on the frame the
	# draw begins, so it is handed to the animation rather than fired here. By
	# then the target may be dead -- a shot at a corpse is skipped, and the
	# shooter simply loses that one.
	defender.play_attack(target.global_position - defender.global_position,
		func() -> void:
			if is_instance_valid(target) and target.is_alive():
				_fire_shot(defender, target))

# What a vine mage throws: the sprig from art/vinee.png, turned a quarter so it
# flies along its own length.
const VINE_FRAMES := ["res://art/fx_vine_1.png"]

# The shot carries the damage; see Projectile for why it lands on arrival
# rather than on release.
func _fire_shot(defender: Defender, target: Enemy) -> void:
	var host := defender.get_parent()
	if host == null:
		return

	var branch: String = UnitDatabase.get_def(defender.unit_id).get("branch", "bow")
	var kind: String = "bolt" if branch == "crystal" else "arrow"

	var damage: float = defender.damage
	var aoe: float = defender.aoe_radius
	var origin: Vector2 = defender.global_position
	# Numbers, not a reference to the shooter: the vine has to keep working even
	# if the mage that threw it is dead before it lands.
	var root_time: float = defender.root_time
	var dps: float = defender.poison_dps

	var shot := Projectile.new()
	host.add_child(shot)
	# Leaves the bow at chest height rather than from the feet. The lambda
	# captures only numbers; the enemy arrives as an argument, because a shot
	# still in the air routinely outlives its target.
	# The shooter is captured alongside the numbers, but only ever to credit the
	# kill: it is checked with is_instance_valid at the far end, because a shot
	# routinely lands after whoever fired it has been cut down, and a dead
	# archer's arrow still has to do its damage.
	shot.fire(defender.global_position + Vector2(0, -22.0), target, kind,
		func(hit: Enemy) -> void:
			_land_shot(hit, damage, aoe, origin, defender)
			if root_time > 0.0 or dps > 0.0:
				if is_instance_valid(hit) and hit.is_alive():
					hit.apply_vine(root_time, dps, _live(defender)),
		defender.shot_tint, defender.shot_scale, defender.shot_sparkle,
		VINE_FRAMES if root_time > 0.0 else [])

# The unit if it is still standing, and null if it is not. Everything that
# credits a kill goes through this, so a freed node is never handed on.
func _live(defender: Defender) -> Defender:
	return defender if defender != null and is_instance_valid(defender) else null

func _land_shot(target: Enemy, damage: float, aoe: float, origin: Vector2,
		by: Defender = null) -> void:
	if not is_instance_valid(target) or not target.is_alive():
		return
	var shooter: Defender = _live(by)
	var point: Vector2 = target.global_position
	target.take_damage(damage, origin, false, shooter)
	if aoe <= 0.0:
		return
	# Duplicated: a splash kill erases from `enemies` mid-loop, which would
	# otherwise shuffle the next enemy past the iterator and spare it.
	for e in enemies.duplicate():
		if e == target or not is_instance_valid(e) or not e.is_alive():
			continue
		if point.distance_to(e.global_position) <= aoe:
			e.take_damage(damage, origin, false, shooter)

func _process_enemy(enemy: Enemy, delta: float) -> void:
	# Rot works whatever the body is doing, and can kill it outright -- after
	# which there is nothing left to process.
	enemy.tick_vine(delta)
	if not enemy.is_alive():
		return

	# Still arriving: a boss holds where it broke through until its entrance has
	# played, and takes hits the whole time like anything else standing there.
	if enemy.entry_timer > 0.0:
		enemy.entry_timer -= delta
		return

	match enemy.state:
		Enemy.State.MOVING:
			# Held by a vine: it can still turn and still be fought, it simply
			# cannot close any more ground while the creepers have it.
			if enemy.is_rooted():
				return

			# A held lane is a wall: the enemy closes to the unit it picked out
			# (or to its place in the queue behind the fight) and gets no
			# further while anything on that lane still stands. A cleared lane
			# -- and, for a goblin, any lane at all -- is an open road.
			var blocked: bool = not enemy.ignores_line and lane_is_held(enemy.lane)

			if not blocked:
				_release_claim(enemy)
				# Big bodies stop short of the walls for the same reason they
				# stop short of the line: a golem parked on the fortress radius
				# would be standing in the middle of the castle.
				var wall: float = fortress_hit_radius \
					+ _standoff(enemy) - ENGAGE_STANDOFF
				if _approach(enemy, enemy.lane_angle, wall, delta):
					enemy.state = Enemy.State.ATTACKING_FORTRESS
					enemy._attack_timer = 0.0
				return

			# Pick the unit to fight while still walking, not on arrival: the
			# enemy then spends the approach sliding across the lane onto it
			# instead of snapping into place the moment it gets there.
			var target: Defender = enemy.target_defender
			if target != null and (not is_instance_valid(target) or not target.is_alive()):
				_release_claim(enemy)
				target = null
			if target == null:
				target = _find_available_defender(enemy)
				if target != null:
					target.claimed_by = enemy
					enemy.target_defender = target

			var want_angle: float = enemy.lane_angle
			var stop_radius: float = _lane_front_radius(enemy.lane) \
				+ _standoff(enemy) + enemy.queue_offset
			# Waiting its turn is standing still, never backing off: a place well
			# down a long queue is further out than the body ever walked in from,
			# and nothing should retreat to reach the back of a line.
			stop_radius = minf(stop_radius, enemy.current_radius)
			if target != null:
				want_angle = _angle_of(target.global_position)
				stop_radius = _engage_radius(enemy, target)

			# In place and squared up: the walk turns into a fight. Both halves of
			# being in place are the walk's own business now -- it arrives at the
			# angle and the distance together or not at all.
			if _approach(enemy, want_angle, stop_radius, delta) and target != null:
				target.engaged_enemy = enemy
				enemy.state = Enemy.State.ENGAGING
				enemy._attack_timer = enemy.attack_interval
		Enemy.State.ENGAGING:
			if enemy.target_defender == null or not is_instance_valid(enemy.target_defender) or not enemy.target_defender.is_alive():
				_release_claim(enemy)
				enemy.state = Enemy.State.MOVING
				return
			enemy._attack_timer -= delta
			if enemy._attack_timer <= 0.0:
				enemy._attack_timer = enemy.attack_interval
				# Dealt on the frame the blow is drawn landing, so the soldier
				# has to still be standing then rather than only now.
				var d: Defender = enemy.target_defender
				enemy.play_attack(d.global_position - enemy.global_position,
					func() -> void:
						if is_instance_valid(d) and d.is_alive():
							d.take_damage(enemy.damage))
		Enemy.State.ATTACKING_FORTRESS:
			# A wizard that reaches the wall does nothing to it. It has no blow to
			# throw, and its circle is aimed at soldiers rather than masonry -- so
			# an unopposed one is a body the player still has to clear, not a
			# threat to the fortress. A dragon does hit the wall, but never while
			# its breath is lit: one animation owns the body at a time.
			if enemy.has_field() or enemy.is_breathing():
				return
			enemy._attack_timer -= delta
			if enemy._attack_timer <= 0.0:
				enemy._attack_timer = enemy.attack_interval
				var at: Vector2 = enemy.global_position
				enemy.play_attack(fortress_center - at, func() -> void:
					if is_instance_valid(fortress):
						fortress.take_damage(enemy.damage, at))

# ---------------------------------------------------------- special abilities
#
# What a unit that has reached Defender.ABILITY_LEVEL does when the player taps
# the button on its card. The unit itself knows whether it has earned one and
# whether the wait is over; everything past that is here, because this is where
# the enemies are.
#
# The ones that are thrown are all aimed the same way: at the body the player
# has focused if there is one in reach, and otherwise at the thickest part of
# the crowd. That makes picking a target and hitting it one gesture -- tap the
# wizard, then drop the volley on it -- without ever forcing the player to do
# both to get a sensible result.

# How far past its own range a unit can throw one. Small on purpose: an ability
# is meant to be the best blow a unit has, not a way for it to reach across the
# map to a lane it is not holding.
const ABILITY_REACH := 1.25

func cast_ability(defender: Defender) -> bool:
	if defender == null or not is_instance_valid(defender) or not defender.ability_ready():
		return false
	var spec: Dictionary = defender.ability_def()
	if spec.is_empty():
		return false

	var at: Vector2 = defender.global_position
	if bool(spec.get("ranged", false)):
		var aim: Enemy = _ability_aim(defender, float(spec.get("radius", 160.0)))
		# Refused rather than spent: a volley dropped on empty ground would cost
		# the player half a minute of cooldown for nothing at all.
		if aim == null:
			defender.float_text("NO TARGET", Color(0.78, 0.80, 0.90))
			return false
		at = aim.global_position

	defender.start_ability_cooldown()
	defender.float_text(String(spec.get("name", "")), spec.get("color", Color(1, 1, 1)))

	match UnitDatabase.get_ability_id(defender.unit_id):
		"arrow_rain": _cast_arrow_rain(defender, spec, at)
		"meteor": _cast_meteor(defender, spec, at)
		"war_slam": _cast_war_slam(defender, spec)
		"briar": _cast_briar(defender, spec, at)
		"rally": _cast_rally(defender, spec)
	return true

# The body to drop it on. The player's own pick first, and failing that whoever
# has the most company inside the circle the ability would cover -- with the one
# furthest advanced breaking a tie, because that is the one closest to the wall.
func _ability_aim(defender: Defender, radius: float) -> Enemy:
	var from: Vector2 = defender.global_position
	var reach: float = defender.attack_range * ABILITY_REACH

	var picked: Enemy = focus_target()
	if picked != null and from.distance_to(picked.global_position) <= reach:
		return picked

	var best: Enemy = null
	var best_count: int = -1
	var best_radius: float = INF
	for e in enemies:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		if from.distance_to(e.global_position) > reach:
			continue
		var count: int = 0
		for other in enemies:
			if not is_instance_valid(other) or not other.is_alive():
				continue
			if e.global_position.distance_to(other.global_position) <= radius:
				count += 1
		if count > best_count or (count == best_count and e.current_radius < best_radius):
			best_count = count
			best_radius = e.current_radius
			best = e
	return best

# Everything standing inside a circle takes the blow. Duplicated for the same
# reason a splash is: a kill erases from `enemies` mid-loop and would shuffle
# the next body past the iterator.
func _damage_around(at: Vector2, radius: float, dealt: float, by: Defender) -> void:
	var shooter: Defender = _live(by)
	for e in enemies.duplicate():
		if not is_instance_valid(e) or not e.is_alive():
			continue
		if at.distance_to(e.global_position) <= radius:
			e.take_damage(dealt, at, false, shooter)

func _ground_host() -> Node2D:
	if ground_layer != null and is_instance_valid(ground_layer):
		return ground_layer
	return null

# Above the fight: what falls out of the sky has to draw over the bodies it is
# falling onto.
func _air_host() -> Node2D:
	if fx_layer != null and is_instance_valid(fx_layer):
		return fx_layer
	return _ground_host()

func _ring_at(at: Vector2, tint: Color, from_r: float, to_r: float,
		from_w: float, to_w: float, dur: float) -> void:
	var host: Node2D = _ground_host()
	if host == null:
		return
	var ring := Shockwave.new()
	host.add_child(ring)
	ring.global_position = at
	ring.color = tint
	ring.run(from_r, to_r, from_w, to_w, 0.9, dur)

func _slam_at(at: Vector2, tint: Color, radius: float) -> void:
	var host: Node2D = _ground_host()
	if host == null:
		return
	var fx := ImpactEffect.new()
	host.add_child(fx)
	fx.global_position = at
	fx.play_ground_slam(tint, clampf(radius / 120.0, 0.8, 2.4))

# --- the volley -------------------------------------------------------------

func _cast_arrow_rain(d: Defender, spec: Dictionary, at: Vector2) -> void:
	var host: Node2D = _ground_host()
	if host == null:
		return
	# Read now, spent per arrow: the volley keeps hitting for what the archer was
	# worth when it loosed, even if the archer is dead before the last one lands.
	var dealt: float = d.damage * float(spec.get("power", 0.5))
	var hit_radius: float = float(spec.get("hit_radius", 50.0))

	var rain := ArrowRain.new()
	host.add_child(rain)
	rain.global_position = at
	rain.play(float(spec.get("radius", 180.0)), int(spec.get("count", 14)),
		float(spec.get("duration", 1.8)), spec.get("color", Color(1, 1, 1)),
		func(point: Vector2) -> void: _damage_around(point, hit_radius, dealt, d))

# --- the stone --------------------------------------------------------------

# Low enough that the stone is on screen for most of its fall. It accelerates
# into the ground, so a drop tall enough to start off the top of the arena spends
# the whole telegraph invisible and arrives out of nowhere.
const METEOR_DROP := 520.0
const METEOR_LEAN := 150.0

func _cast_meteor(d: Defender, spec: Dictionary, at: Vector2) -> void:
	var tint: Color = spec.get("color", Color(1, 1, 1))
	var radius: float = float(spec.get("radius", 180.0))
	var fall: float = maxf(float(spec.get("duration", 0.5)), 0.12)
	var dealt: float = d.damage * float(spec.get("power", 3.0))

	# The ground is marked before the stone reaches it -- a ring closing on the
	# point of impact -- so the blow is something the player watches arrive
	# rather than something that has already happened.
	var host: Node2D = _ground_host()
	if host != null:
		var warn := Shockwave.new()
		host.add_child(warn)
		warn.global_position = at
		warn.color = tint
		warn.run_inward(radius * 1.7, radius * 0.5, 4.0, 18.0, 0.85, fall)

	var air: Node2D = _air_host()
	if air == null:
		_meteor_land(at, radius, dealt, d, tint)
		return

	var rock := Node2D.new()
	air.add_child(rock)
	rock.z_index = 82
	rock.global_position = at + Vector2(-METEOR_LEAN, -METEOR_DROP)
	FxUtil.bloom(rock, 0.62, 0.95, tint, 128)

	var core := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(9):
		var a: float = TAU * i / 9.0
		var r: float = 15.0 + randf() * 7.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	core.polygon = pts
	core.color = Color(0.24, 0.16, 0.16)
	rock.add_child(core)

	var trail := FxUtil.burst(rock, 22, 0.36, 20.0, 70.0,
		Color(1.0, 0.92, 0.66, 1.0), Color(tint.r, tint.g * 0.4, tint.b * 0.2, 0.0))
	trail.one_shot = false
	trail.explosiveness = 0.0
	trail.local_coords = false
	trail.gravity = Vector2(0, -40)
	trail.emitting = true

	var tw := rock.create_tween()
	tw.tween_property(rock, "global_position", at, fall) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_meteor_land(at, radius, dealt, d, tint)
		rock.queue_free())

func _meteor_land(at: Vector2, radius: float, dealt: float, by: Defender,
		tint: Color) -> void:
	_slam_at(at, tint, radius)
	_ring_at(at, tint, radius * 0.15, radius * 1.15, 22.0, 3.0, 0.45)
	_damage_around(at, radius, dealt, by)

# --- the slam ---------------------------------------------------------------

func _cast_war_slam(d: Defender, spec: Dictionary) -> void:
	var at: Vector2 = d.global_position
	var tint: Color = spec.get("color", Color(1, 1, 1))
	var radius: float = float(spec.get("radius", 220.0))

	_slam_at(at, tint, radius)
	_ring_at(at, tint, radius * 0.18, radius, 20.0, 3.0, 0.42)
	_damage_around(at, radius, d.damage * float(spec.get("power", 2.5)), d)

	var hold: float = float(spec.get("root", 0.0))
	if hold <= 0.0:
		return
	# Whatever survived it is left where it fell for a moment. Read after the
	# damage, so nothing already dead is pinned.
	for e in enemies.duplicate():
		if not is_instance_valid(e) or not e.is_alive():
			continue
		if at.distance_to(e.global_position) <= radius:
			e.stagger(hold)

# --- the snare --------------------------------------------------------------

func _cast_briar(d: Defender, spec: Dictionary, at: Vector2) -> void:
	var tint: Color = spec.get("color", Color(1, 1, 1))
	var radius: float = float(spec.get("radius", 200.0))
	var hold: float = float(spec.get("root", 2.5))
	# The mage's own rot, several times over. A vine mage that has never been
	# given one still gets something off its damage, so the ability is never a
	# blank for whatever ends up carrying it.
	var dps: float = maxf(d.poison_dps, d.damage * 0.4) * float(spec.get("poison_mult", 2.0))

	_ring_at(at, tint, radius * 0.2, radius, 16.0, 3.0, 0.5)
	_damage_around(at, radius, d.damage * float(spec.get("power", 0.9)), d)

	for e in enemies.duplicate():
		if not is_instance_valid(e) or not e.is_alive():
			continue
		if at.distance_to(e.global_position) <= radius:
			e.apply_vine(hold, dps, _live(d))

# --- the rally --------------------------------------------------------------

func _cast_rally(d: Defender, spec: Dictionary) -> void:
	var tint: Color = spec.get("color", Color(1, 1, 1))
	var haste: float = float(spec.get("haste", 1.5))
	var seconds: float = float(spec.get("duration", 8.0))
	var mend: float = float(spec.get("heal", 0.3))

	# Everything of ours, wherever it is standing. A shaman's circle is already
	# how it helps the ground around it; the point of this one is that it reaches
	# the lanes it is not on.
	for other in defenders.duplicate():
		if is_instance_valid(other) and other.is_alive():
			other.apply_rally(haste, seconds, mend)

	_ring_at(d.global_position, tint, 40.0, 620.0, 24.0, 3.0, 0.75)
