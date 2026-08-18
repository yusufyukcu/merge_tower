extends Node

signal state_changed(new_state: int)
signal coins_changed(total: int)

enum State { PLAYING, UPGRADE_SELECTION, GAME_OVER }

var state: int = State.PLAYING

# Gold banked this run. Enemies pay out when the coin they dropped reaches the
# HUD counter, not the instant they die, so the number in the corner and the
# coin on screen always agree.
var coins: int = 0

# How many units may stand on the field at once. Room on the field is the thing
# gold is really for, so the run starts with a board too small to hold a full
# defense and every extra slot is bought from the shop at a price that climbs
# steeply -- the fourth one costs ten times the first. The full list runs all
# the way to Main.MAX_DEFENDERS (20): the four-lane formation was always meant
# to be reachable, not a decoration behind a shelf that sells out at twelve.
const BASE_UNIT_SLOTS := 8
const SLOT_PRICES := [100, 200, 500, 1000, 1600, 2600, 4200, 6800, 11000, 18000, 29000, 47000]

var unit_slots: int = BASE_UNIT_SLOTS

# The merge upgrade, earned once at wave 20: from then on the tray stops
# dropping wood, bows and crystals and drops gold, emeralds and totems instead.
var merge_upgraded: bool = false

func slots_bought() -> int:
	return unit_slots - BASE_UNIT_SLOTS

# What the next slot costs, or 0 once the list is exhausted -- the shop reads
# that as sold out rather than as free. Run down further still by whatever
# discount MetaManager's own shop has sold the player, permanently, in gold
# this run will never see again.
func next_slot_price() -> int:
	var i: int = slots_bought()
	if i >= SLOT_PRICES.size():
		return 0
	return int(round(float(SLOT_PRICES[i]) * MetaManager.discount_mult()))

func buy_unit_slot() -> bool:
	var price: int = next_slot_price()
	if price <= 0 or not spend_coins(price):
		return false
	unit_slots += 1
	return true

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)

# Reports whether the purchase went through, so callers can charge and act in
# one step without checking the balance themselves first.
func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

func is_playing() -> bool:
	return state == State.PLAYING

func enter_upgrade_selection() -> void:
	if state == State.GAME_OVER:
		return
	state = State.UPGRADE_SELECTION
	state_changed.emit(state)

func resume_playing() -> void:
	if state == State.GAME_OVER:
		return
	state = State.PLAYING
	state_changed.emit(state)

func trigger_game_over() -> void:
	if state == State.GAME_OVER:
		return
	state = State.GAME_OVER
	state_changed.emit(state)

func reset() -> void:
	state = State.PLAYING
	coins = 0
	# Permanent slots bought with essence never reset -- that is the entire
	# point of spending a currency the run itself cannot touch.
	unit_slots = BASE_UNIT_SLOTS + MetaManager.bonus_base_slots()
	merge_upgraded = false
	state_changed.emit(state)
	coins_changed.emit(coins)
