extends Node

const OUT := "C:/Users/yusuf/AppData/Local/Temp/claude/C--Users-yusuf-OneDrive-Masa-st--merge-tower-main/03edf953-aeb7-4d98-94b2-f0803851bd24/scratchpad/shots/"

# The launch has to ask for this by name:
#
#   Godot_v4.7-stable_win64_console.exe --path . -- --devshot
#
# Read off both lists, so the flag works whether it is passed after the engine's
# own "--" or straight on the command line.
const FLAG := "--devshot"

var _menu: Node = null

func _ready() -> void:
	# Registered as an autoload, so this wakes on every launch -- and what it
	# does is overwrite the player's own save and then quit. It runs when the
	# launch asked for it and never otherwise.
	if not _asked_for():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	DisplayServer.window_set_size(Vector2i(810, 1440))
	await get_tree().create_timer(1.2).timeout
	DirAccess.make_dir_recursive_absolute(OUT)

	_menu = get_tree().current_scene
	MetaManager.gold = 214255
	MetaManager.essence = 12480
	MetaManager.last_free_gold_at = 0
	MetaManager.pending_unit_boost = false
	MetaManager.pending_extra_slot = false
	MetaManager.inventory = []
	_menu._refresh_all()

	await _hitbox_pass()
	await _click_pass()
	_economy_pass()
	await _broke_pass()
	await _menu_pass()
	await _quests_pass()
	await _rail_pass()
	await _run_pass()
	await _choice_pass()

	print("DEVSHOT: done")
	get_tree().quit()

# ------------------------------------------------------------ where they are

func _hitbox_pass() -> void:
	_menu._open_shop(0)
	await _paint_hits()
	await _shot("10_hits_shop")
	_menu.shop_screen._go(1)
	await _paint_hits()
	await _shot("11_hits_gold")
	_menu.shop_screen._go(2)
	await _paint_hits()
	await _shot("12_hits_essence")
	_menu.shop_screen._close_out()
	await get_tree().process_frame

func _paint_hits() -> void:
	await get_tree().process_frame
	var n := 0
	for child in _menu.shop_screen._page_root.get_children():
		if not (child is Button):
			continue
		var mark := ColorRect.new()
		mark.position = Vector2.ZERO
		mark.size = child.size
		mark.color = Color(1, 0, 0, 0.22) if n % 2 == 0 else Color(0, 1, 1, 0.22)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.add_child(mark)
		n += 1
	print("DEVSHOT: %d hit boxes" % n)

# ---------------------------------------------------------- do they answer

func _click_pass() -> void:
	_menu._open_shop(0)
	await get_tree().process_frame
	var shop: Node = _menu.shop_screen

	await _click(shop._at(shop.S_GOLD_PLUS).get_center())
	print("DEVSHOT: gold plus -> page %d (want 1)" % shop._page)

	await _click(shop._at(shop.G_ESS_PLUS).get_center())
	print("DEVSHOT: essence plus -> page %d (want 2)" % shop._page)

	# The X, from a tab that was reached two moves in. It is the way out of the
	# shop now rather than a way back through the pages, so one press ends it
	# wherever the player is standing.
	await _click(shop._at(shop.E_CLOSE).get_center())
	print("DEVSHOT: X from essence -> shop node %s (want <null>)"
		% str(_menu.shop_screen))

	_menu._open_shop(0)
	await get_tree().process_frame
	shop = _menu.shop_screen
	await _click(shop._rail_rect(2).get_center())
	print("DEVSHOT: essence tab -> page %d (want 2)" % shop._page)
	await _click(shop._at(shop.E_CLOSE).get_center())
	print("DEVSHOT: X -> shop node %s (want <null>)" % str(_menu.shop_screen))

	_menu._open_shop(0)
	await get_tree().process_frame
	shop = _menu.shop_screen

	# The free gold card, then the wood chest, both by pressing where a thumb
	# would land rather than by calling anything.
	var before_gold: int = MetaManager.gold
	await _click(shop._at(shop._card(0, 0)).get_center())
	print("DEVSHOT: free gold %d -> %d (want +1000), ready %s (want false)"
		% [before_gold, MetaManager.gold, str(MetaManager.free_gold_ready())])

	before_gold = MetaManager.gold
	await _click(shop._at(shop._card(0, 1)).get_center())
	print("DEVSHOT: wood chest %d -> %d (want -10000), pack %d (want 3..5)"
		% [before_gold, MetaManager.gold, MetaManager.inventory_count()])

	await _click(shop._at(shop._card(1, 1)).get_center())
	print("DEVSHOT: unit boost armed %s (want true), gold %d"
		% [str(MetaManager.pending_unit_boost), MetaManager.gold])
	await _shot("13_after_clicks")

	var probe: Vector2 = shop._at(shop.S_SEE_OFFERS).get_center()
	for child in shop._page_root.get_children():
		if child is Button:
			print("DEVSHOT:   btn %s hit=%s vis=%s dis=%s filt=%d"
				% [str(Rect2(child.position, child.size)),
					str(Rect2(child.position, child.size).has_point(probe)),
					str(child.visible), str(child.disabled), child.mouse_filter])
	await _click(probe)
	print("DEVSHOT: see offers -> page %d (want 1)" % shop._page)
	var before_ess: int = MetaManager.essence
	await _click(shop._at(shop._pack_card(0, shop.G_ROW_Y, shop.G_ROW_H,
		shop.G_COL_X, shop.G_COL_W)).get_center())
	print("DEVSHOT: pile of gold essence %d -> %d (want -200), gold %d"
		% [before_ess, MetaManager.essence, MetaManager.gold])

	await _click(shop._at(shop.G_CLOSE).get_center())
	print("DEVSHOT: closed, menu gold reads %s" % _menu.gold_label.text)

func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	get_viewport().push_input(move, true)
	for i in range(3):
		await get_tree().process_frame
	print("DEVSHOT:   under %s -> %s" % [str(at), str(get_viewport().gui_get_hovered_control())])
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)
		for i in range(3):
			await get_tree().process_frame
	for i in range(3):
		await get_tree().process_frame

# --------------------------------------------------------- does it add up

func _economy_pass() -> void:
	print("DEVSHOT: chest pools 2/3/4 = %s / %s / %s"
		% [str(UnitDatabase.units_of_tier(2)), str(UnitDatabase.units_of_tier(3)),
			str(UnitDatabase.units_of_tier(4))])
	print("DEVSHOT: free gold twice -> %d then %d (want 1000 then 0)"
		% [_reclaim(), MetaManager.claim_free_gold()])
	MetaManager.pending_unit_boost = true
	MetaManager.pending_extra_slot = true
	var taken: Dictionary = MetaManager.take_run_boosts()
	print("DEVSHOT: boosts taken %s, run mult %.2f (want 1.25), pending %s/%s (want false/false)"
		% [str(taken), MetaManager.run_damage_mult(), str(MetaManager.pending_unit_boost),
			str(MetaManager.pending_extra_slot)])
	MetaManager.take_run_boosts()
	print("DEVSHOT: next run mult %.2f (want 1.00)" % MetaManager.run_damage_mult())

func _reclaim() -> int:
	MetaManager.last_free_gold_at = 0
	return MetaManager.claim_free_gold()

func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")

# ------------------------------------------------ nothing in the purse

func _broke_pass() -> void:
	MetaManager.gold = 12000
	MetaManager.essence = 100
	MetaManager.last_free_gold_at = MetaManager._now()
	MetaManager.pending_unit_boost = false
	MetaManager.pending_extra_slot = false
	MetaManager.inventory = []
	_menu._refresh_all()
	_menu._open_shop(0)
	await get_tree().process_frame
	var shop: Node = _menu.shop_screen
	await _shot("20_broke_shop")

	var g: int = MetaManager.gold
	await _click(shop._at(shop._card(0, 2)).get_center())
	print("DEVSHOT: broke silver chest gold %d -> %d (want same), pack %d (want 0)"
		% [g, MetaManager.gold, MetaManager.inventory_count()])

	await _click(shop._at(shop._card(1, 0)).get_center())
	print("DEVSHOT: broke hero chest -> gold %d (want 12000)" % MetaManager.gold)

	await _click(shop._at(shop._card(0, 0)).get_center())
	print("DEVSHOT: free gold on cooldown -> gold %d (want 12000), left %ds"
		% [MetaManager.gold, MetaManager.free_gold_seconds_left()])
	await _shot("21_broke_toast")

	await _click(shop._at(shop._card(0, 1)).get_center())
	print("DEVSHOT: wood chest with 12000 -> gold %d (want 2000), pack %d (want 3..5)"
		% [MetaManager.gold, MetaManager.inventory_count()])

	await _click(shop._rail_rect(1).get_center())
	print("DEVSHOT: gold tab -> page %d (want 1)" % shop._page)
	await _shot("22_broke_gold")

	var e: int = MetaManager.essence
	await _click(shop._at(shop._pack_card(5, shop.G_ROW_Y, shop.G_ROW_H,
		shop.G_COL_X, shop.G_COL_W)).get_center())
	print("DEVSHOT: broke gold hoard essence %d -> %d (want same)" % [e, MetaManager.essence])
	# the rail, from a page that never used to carry one
	await _click(shop._rail_rect(2).get_center())
	print("DEVSHOT: rail essence from gold -> page %d (want 2)" % shop._page)
	await _shot("25_rail_essence")
	await _click(shop._rail_rect(0).get_center())
	print("DEVSHOT: rail shop from essence -> page %d (want 0)" % shop._page)
	await _click(shop._rail_rect(1).get_center())
	print("DEVSHOT: rail gold from shop -> page %d (want 1)" % shop._page)
	await _shot("26_rail_gold")

	await _click(shop._at(shop.G_ESS_PLUS).get_center())
	print("DEVSHOT: essence plus -> page %d (want 2)" % shop._page)
	await _click(shop._at(shop._pack_card(2, shop.E_ROW_Y, shop.E_ROW_H,
		shop.E_COL_X, shop.E_COL_W)).get_center())
	print("DEVSHOT: essence pack -> page %d, essence %d (want 100)"
		% [shop._page, MetaManager.essence])
	await _shot("23_essence_toast")

	await _click(shop._at(shop.E_ESS_PLUS).get_center())
	print("DEVSHOT: essence plus on essence page -> page %d" % shop._page)

	print("DEVSHOT: esc from page %d (want 2)" % shop._page)
	await _esc()
	print("DEVSHOT: esc -> shop node %s (want <null>)" % str(_menu.shop_screen))
	await _shot("24_back_on_menu")

func _esc() -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = pressed
		get_viewport().push_input(ev, true)
		for i in range(3):
			await get_tree().process_frame

func _asked_for() -> bool:
	return OS.get_cmdline_user_args().has(FLAG) or OS.get_cmdline_args().has(FLAG)

# ------------------------------------------------ the three plaques on the road

func _menu_pass() -> void:
	MetaManager.inventory = []
	MetaManager.squad = [{}, {}]
	MetaManager.add_to_inventory([
		{"id": "knight", "level": 3}, {"id": "warrior", "level": 1},
		{"id": "warrior", "level": 2}, {"id": "archmage", "level": 1},
	])
	# Aurelia is behind essence now, so the shot has to own her before it can
	# stand her on the ring. A level with her, too, so the hero the run opens
	# with is visibly one the menu paid to grow.
	MetaManager.heroes_owned = ["hero_aurelia"]
	MetaManager.hero_levels = {"hero_venom_dartmaster": 4, "hero_aurelia": 12}
	MetaManager.select_hero("hero_aurelia")
	_menu._refresh_all()
	await get_tree().process_frame

	var n := 0
	for holder in _menu.slot_frames:
		var mark := ColorRect.new()
		mark.position = Vector2.ZERO
		mark.size = holder.size
		mark.color = Color(1, 0, 0, 0.28) if n % 2 == 0 else Color(0, 1, 1, 0.28)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(mark)
		n += 1
	print("DEVSHOT: %d plaques, rects %s" % [n, str(_menu.slot_frames.map(
		func(c: Control) -> Rect2: return Rect2(c.position, c.size)))])
	await _shot("30_slots_marked")

	_menu._refresh_all()
	await get_tree().process_frame
	await _shot("31_slots_empty")

	print("DEVSHOT: pick knight -> %s, warrior -> %s (want true true)"
		% [str(MetaManager.set_squad(0, "knight", 3)), str(MetaManager.set_squad(1, "warrior", 2))])
	_menu._refresh_all()
	await _shot("32_slots_filled")
	print("DEVSHOT: squad %s, hero %s" % [str(MetaManager.squad), MetaManager.hero_id()])

	# the pack still holds what the plaques are showing -- picking is not spending
	print("DEVSHOT: pack after picking %d (want 4)" % MetaManager.inventory_count())

	# two plaques cannot hold the one body the pack has only one of
	MetaManager.squad = [{}, {}]
	MetaManager.inventory = [{"id": "knight", "level": 1}]
	print("DEVSHOT: one knight -> slot0 %s (want true), slot1 %s (want false)"
		% [str(MetaManager.set_squad(0, "knight", 1)), str(MetaManager.set_squad(1, "knight", 1))])

	# and a pick the pack loses is dropped rather than left standing
	MetaManager.inventory = []
	MetaManager.prune_squad()
	print("DEVSHOT: pack emptied -> squad %s (want two empties)" % str(MetaManager.squad))

	MetaManager.add_to_inventory([
		{"id": "knight", "level": 3}, {"id": "warrior", "level": 1},
		{"id": "archmage", "level": 1},
	])
	MetaManager.set_squad(0, "knight", 3)
	_menu._refresh_all()
	_menu._on_squad_slot(1)
	await get_tree().process_frame
	await _shot("33_slot_picker")
	_menu._root.get_child(_menu._root.get_child_count() - 1).queue_free()
	await get_tree().process_frame

	_menu._on_heroes()
	# Long enough for the pop-up to have finished arriving.
	await get_tree().create_timer(0.4).timeout
	await _shot("34_hero_picker")
	var page: Node = _menu.hero_page
	var locked: String = String(UnitDatabase.HERO_IDS[3])

	# A locked row with nothing in the purse: the tap has to bounce off it.
	MetaManager.essence = 100
	page._show()
	await get_tree().process_frame
	await _click(page.row_rect(3).get_center())
	print("DEVSHOT: broke tap on %s -> owned %s (want false), essence %d (want 100)"
		% [locked, str(MetaManager.hero_owned(locked)), MetaManager.essence])
	await _shot("34b_hero_broke")

	# And with the price in hand it is bought, and worn without a second tap.
	MetaManager.essence = 4000
	page._show()
	await get_tree().process_frame
	await _click(page.row_rect(3).get_center())
	print("DEVSHOT: bought %s for %d -> owned %s (want true), essence %d (want %d), hero %s"
		% [locked, MetaManager.hero_unlock_cost(locked),
			str(MetaManager.hero_owned(locked)), MetaManager.essence,
			4000 - MetaManager.hero_unlock_cost(locked), MetaManager.hero_id()])
	await _shot("34c_hero_bought")

	# The gold plate under CHOOSE buys the next level.
	MetaManager.gold = 60000
	page._show()
	await get_tree().process_frame
	var lvl_before: int = MetaManager.hero_level(locked)
	var gold_before: int = MetaManager.gold
	var price: int = MetaManager.hero_level_cost(locked)
	await _click(page.level_seat(3).get_center())
	print("DEVSHOT: level plate %s lv %d -> %d (want +1), gold %d -> %d (want -%d)"
		% [locked, lvl_before, MetaManager.hero_level(locked), gold_before,
			MetaManager.gold, price])
	await _shot("34d_hero_levelled")

	await _click(page._at(page.CLOSE_BTN_RECT).get_center())
	print("DEVSHOT: CLOSE -> hero page %s (want <null>)" % str(_menu.hero_page))
	await get_tree().process_frame

	# The pack, on the plate the in-run shop is painted on.
	MetaManager.inventory = [
		{"id": "knight", "level": 6}, {"id": "knight", "level": 6},
		{"id": "archmage", "level": 3}, {"id": "warrior", "level": 1},
		{"id": "warrior", "level": 1}, {"id": "warrior", "level": 1},
		{"id": "master_archer", "level": 9}, {"id": "hoplite", "level": 2},
	]
	_menu._on_inventory()
	await get_tree().create_timer(0.4).timeout
	await _shot("36_inventory")
	var pack: Node = _menu.menu_board
	print("DEVSHOT: pack shows %d stacks of %d bodies"
		% [MetaManager.inventory_stacks().size(), MetaManager.inventory_count()])
	await _click(pack._at(pack.CLOSE_RECT).get_center())
	print("DEVSHOT: CLOSE -> inventory %s (want <null>)" % str(_menu.menu_board))
	await get_tree().process_frame
	await _menu_hits()
	_menu._root.get_child(_menu._root.get_child_count() - 1).queue_free()
	await get_tree().process_frame

# Every hit box on the front screen at once, so a rect the new paintings have
# moved out from under shows up as a mark sitting on nothing.
func _menu_hits() -> void:
	var n := 0
	for child in _menu._root.get_children():
		if not (child is Button):
			continue
		var mark := ColorRect.new()
		mark.position = Vector2.ZERO
		mark.size = child.size
		mark.color = Color(1, 0, 0, 0.30) if n % 2 == 0 else Color(0, 1, 1, 0.30)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.add_child(mark)
		n += 1
	print("DEVSHOT: %d menu hit boxes" % n)
	await _shot("35_menu_hits")

# ---------------------------------------------------------------- the board

func _quests_pass() -> void:
	MetaManager.gold = 5000
	MetaManager.roll_quests()
	MetaManager.quest_progress = {
		"battles": 3, "merges": 10, "waves": 2, "chests": 2, "boosts": 0, "level3": 1,
	}
	MetaManager.quest_claimed = {}
	_menu._on_quests()
	await get_tree().create_timer(0.4).timeout
	var q: Node = _menu.quests_screen
	await _shot("40_quests")
	print("DEVSHOT: claimable %d (want 3)" % MetaManager.quests_claimable_count())

	var before: int = MetaManager.gold
	await _click(q._at(q.CLAIM_RECTS[0]).get_center())
	print("DEVSHOT: claim battles %d -> %d (want +1000), claimed %s (want true)"
		% [before, MetaManager.gold, str(MetaManager.quest_is_claimed("battles"))])
	await _shot("41_quests_claimed")

	# a finished short row puts its plate over the bar rather than under the
	# reward, because a short row has no room under the reward
	before = MetaManager.gold
	var mid: float = float(q.BAR_MID[3])
	await _click(q._at(Rect2(q.BAR_X, mid - 24.0, q.BAR_W, 48.0)).get_center())
	print("DEVSHOT: claim chests %d -> %d (want +1000)" % [before, MetaManager.gold])

	before = MetaManager.gold
	print("DEVSHOT: claim chests again -> %d (want 0), gold %d (want %d)"
		% [MetaManager.claim_quest("chests"), MetaManager.gold, before])

	print("DEVSHOT: claimable now %d (want 1)" % MetaManager.quests_claimable_count())
	await _shot("42_quests_mixed")

	MetaManager.quest_day = "1999-01-01"
	MetaManager.roll_quests()
	print("DEVSHOT: new day -> progress %s, claimed %s (want both empty)"
		% [str(MetaManager.quest_progress), str(MetaManager.quest_claimed)])
	MetaManager.record_quest("merges", 4)
	MetaManager.record_quest("merges", 100)
	print("DEVSHOT: merges %d (want 10, capped at the goal)" % MetaManager.quest_count("merges"))
	print("DEVSHOT: unknown quest -> goal %d (want 0)" % MetaManager.quest_goal("nonsense"))
	q._show()
	await get_tree().process_frame
	await _shot("43_quests_fresh")

	# Nothing done at all: the tab should carry no badge whatever, rather than
	# the grey disc a flat cover used to leave on it.
	MetaManager.quest_progress = {}
	MetaManager.quest_claimed = {}
	q._show()
	await get_tree().process_frame
	print("DEVSHOT: claimable with nothing done %d (want 0)"
		% MetaManager.quests_claimable_count())
	await _shot("46_quests_none")

	await _click(q._at(q.CLOSE_RECT).get_center())
	print("DEVSHOT: X -> quests node %s (want <null>)" % str(_menu.quests_screen))

# In through the tiles on the rail rather than by calling anything.
func _rail_pass() -> void:
	MetaManager.quest_progress = {"merges": 10, "waves": 5}
	MetaManager.quest_claimed = {}
	_menu._refresh_all()
	await _click(_menu._rect(_menu._rail_right(1)).get_center())
	print("DEVSHOT: QUESTS tile -> board open %s (want true)"
		% str(_menu.quests_screen != null))
	await _shot("44_quests_from_rail")
	if _menu.quests_screen != null:
		await _click(_menu.quests_screen._at(_menu.quests_screen.CLOSE_RECT).get_center())
	print("DEVSHOT: X -> board %s (want <null>)" % str(_menu.quests_screen))

	var before: int = _menu._root.get_child_count()
	await _click(_menu._rect(_menu._rail_left(0)).get_center())
	print("DEVSHOT: MISSIONS tile -> ledger open %s (want true)"
		% str(_menu.menu_board != null))
	await get_tree().create_timer(0.4).timeout
	await _shot("45_ledger_missions")
	await _close_ledger()

	# The other three pages of the same plate, each with something on it worth
	# looking at: essence to spend, a road part walked, a few things earned.
	MetaManager.essence = 2600
	# Reset, or the shot inherits whatever the last run of this pass bought and
	# the row it presses is already at the top of its track.
	MetaManager.meta_upgrade_levels = {}
	MetaManager.fourth_card_unlocked = false
	MetaManager.discount_tier = 0
	MetaManager.units_seen = {"warrior": true, "knight": true, "archer": true,
		"apprentice_mage": true, "mage": true, "archmage": true, "hoplite": true}
	MetaManager.best_wave = 34
	MetaManager.achievements_seen = {"first_blood": true, "stonebreaker": true,
		"into_winter": true, "combo_master": true}
	for page in [["upgrades", _menu._on_upgrades], ["campaign", _menu._on_chapters],
			["achievements", _menu._on_achievements]]:
		(page[1] as Callable).call()
		await get_tree().create_timer(0.4).timeout
		await _shot("46_ledger_" + String(page[0]))
		if String(page[0]) == "upgrades":
			var spent: int = MetaManager.essence
			var l: Node = _menu.menu_board
			# The second row -- a branch mastery, always affordable here. Pressed by
			# the row's own rect rather than at a guessed fraction of the plate, so
			# it still lands when the plate changes height under it.
			var card: Control = l._list.get_child(1)
			var cr: Rect2 = card.get_global_rect()
			await _click(Vector2(cr.position.x + cr.size.x - l._sz(Vector2(120, 0)).x,
				cr.get_center().y))
			print("DEVSHOT: bought off the ledger, essence %d -> %d"
				% [spent, MetaManager.essence])
			await _shot("46b_ledger_bought")
		await _close_ledger()

func _close_ledger() -> void:
	if _menu.menu_board == null or not is_instance_valid(_menu.menu_board):
		return
	# Settled first: a press pushed into the frame the pop-in is still finishing
	# lands on a plate that is still moving under it.
	await get_tree().create_timer(0.15).timeout
	var l: Node = _menu.menu_board
	await _click(l._at(l.CLOSE_RECT).get_center())
	print("DEVSHOT: CLOSE -> ledger %s (want <null>)" % str(_menu.menu_board))
	await get_tree().process_frame

# ------------------------------------------- does the pick reach the field

func _run_pass() -> void:
	MetaManager.inventory = []
	MetaManager.squad = [{}, {}]
	MetaManager.add_to_inventory([
		{"id": "knight", "level": 4},
		{"id": "archmage", "level": 1},
		{"id": "warrior", "level": 1},
	])
	# Aurelia is behind essence now, so the shot has to own her before it can
	# stand her on the ring. A level with her, too, so the hero the run opens
	# with is visibly one the menu paid to grow.
	MetaManager.heroes_owned = ["hero_aurelia"]
	MetaManager.hero_levels = {"hero_venom_dartmaster": 4, "hero_aurelia": 12}
	MetaManager.select_hero("hero_aurelia")
	print("DEVSHOT: squad set %s / %s (want true true)"
		% [str(MetaManager.set_squad(0, "knight", 4)),
			str(MetaManager.set_squad(1, "archmage", 1))])
	var pack_before: int = MetaManager.inventory_count()
	print("DEVSHOT: before the run pack %d (want 3), squad %s"
		% [pack_before, str(MetaManager.squad)])
	_menu._refresh_all()
	await _shot("50_before_run")

	_menu._on_play()
	await get_tree().create_timer(1.6).timeout
	var scene: Node = get_tree().current_scene
	print("DEVSHOT: scene now %s" % (scene.name if scene != null else "<null>"))
	# The run does not actually begin until a blessing has been picked -- see
	# Main._show_blessing_selection -- so nothing is spawned and nothing is
	# spent before that card is pressed.
	if scene != null and scene.has_method("_on_blessing_card_pressed"):
		await _shot("50b_blessing")
		scene._on_blessing_card_pressed(0)
		await get_tree().create_timer(1.2).timeout

	var on_field: Array = []
	for d in CombatManager.defenders:
		on_field.append("%s lv%d" % [d.unit_id, d.unit_level])
	print("DEVSHOT: on the field %s (want the hero, a knight lv4 and an archmage)"
		% str(on_field))
	print("DEVSHOT: pack %d -> %d (want 1 left), squad %s (want two empties)"
		% [pack_before, MetaManager.inventory_count(), str(MetaManager.squad)])
	print("DEVSHOT: unit slots %d" % GameManager.unit_slots)
	await _shot("51_field")

	# What a hero earns on the field belongs to the run and to nothing else. The
	# menu bought level 12; level 12 is what the next run still opens on, however
	# far this one grew it. Guarded here because the only thing keeping it true is
	# that nothing writes MetaManager.hero_levels back -- an easy thing to undo by
	# accident, and a silent one.
	var hero_on_field: Node = scene.hero_unit
	if hero_on_field != null and is_instance_valid(hero_on_field):
		var menu_level: int = MetaManager.hero_level("hero_aurelia")
		hero_on_field.gain_xp(600)
		print("DEVSHOT: hero grew lv%d -> lv%d on the field; menu level still %d (want %d)"
			% [menu_level, hero_on_field.unit_level,
				MetaManager.hero_level("hero_aurelia"), menu_level])

# ------------------------------------------- the two boards a run stops on
#
# Both are the same plate (ui/ChoicePlate.gd) with different words in it, so
# they are shot together: three cards with a level to climb, then four, then
# the blessing board that has none.
func _choice_pass() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.has_method("_show_upgrade_selection"):
		print("DEVSHOT: no run on screen, skipping the choice boards")
		return

	UpgradeManager.levels["mage_aoe"] = 1
	UpgradeManager.levels["archer_aspd"] = 2
	MetaManager.fourth_card_unlocked = false
	WaveManager.current_wave = 4
	scene._show_upgrade_selection()
	await get_tree().create_timer(0.5).timeout
	await _shot("52_upgrade_three")
	print("DEVSHOT: upgrade cards %s" % str(scene.upgrade_card_ids))

	# Pressed where a thumb would land rather than by calling the handler: the
	# whole board is a painting with invisible hit boxes over it, so where the
	# boxes are is the thing worth checking.
	var want: String = String(scene.upgrade_card_ids[1])
	var before: int = UpgradeManager.get_level(want)
	var card: Control = scene.upgrade_panel._cards[1]
	await _click(card.get_global_rect().get_center())
	# Read after the card has finished its press, not during it.
	await get_tree().create_timer(0.5).timeout
	print("DEVSHOT: tapped card 2 (%s) %d -> %d (want +1), board up %s (want false)"
		% [want, before, UpgradeManager.get_level(want), str(scene.upgrade_panel.visible)])
	print("DEVSHOT: after the pick, paused %s (want false)" % str(get_tree().paused))

	MetaManager.fourth_card_unlocked = true
	WaveManager.current_wave = 40
	scene._show_upgrade_selection()
	await get_tree().create_timer(0.5).timeout
	await _shot("53_upgrade_four")
	scene._on_upgrade_card_pressed(1)
	await get_tree().create_timer(0.5).timeout

	scene._show_blessing_selection()
	await get_tree().create_timer(0.5).timeout
	await _shot("54_blessing_four")
	print("DEVSHOT: blessing cards %s" % str(scene.blessing_card_ids))
