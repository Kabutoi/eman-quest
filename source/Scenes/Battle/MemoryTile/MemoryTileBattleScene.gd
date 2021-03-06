extends Node2D

const ActionButton = preload("res://Scenes/Battle/MemoryTile/ActionButton.tscn")
const BattleResolution = preload("res://Scripts/Battle/BattleResolution.gd")
const MonsterScaler = preload("res://Scripts/Battle/MonsterScaler.gd")

const MAX_MESSAGES = 12 # with wrap, 15 lines max, 10 -11is safe
# Pick N tiles to get a bonus for consecutive picks
const _MULTIPLIER_BONUS = 0.25 # 0.1 means, multipliers are 1.0x => 1.1x => 1.2x ...

var _monster_data = {}

var player = preload("res://Entities//Battle/BattlePlayer.gd").new()
var _action_resolver = preload("res://Scripts/Battle/ActionResolver.gd").new()
var _consecutive_checker = preload("res://Scripts/Battle/ConsecutiveActionsChecker.gd").new()

var _action_buttons = []
var _history_messages = []
var _size = [5, 5]
var _advanced_mode = false
var _actions_picked = 0
var _multipliers = 0

func _ready():
	$MemoryGrid.initialize(_size[0], _size[1], _advanced_mode, self.player.num_pickable_tiles)
	$MemoryGrid.connect("all_tiles_picked", self, "_show_turn_options")
	$MemoryGrid.connect("tile_picked", self, "_check_for_consecutive_picks_bonus")
	
	if Features.is_enabled("consecutive picks battle bonus"):
		self._consecutive_checker.connect("picked_consecutives", self, "_consecutive_tiles_bonus")
	
	if not Features.is_enabled("actions require energy"):
		$EnergyControls.visible = false
	
	if Features.is_enabled("instant actions"):
		$MemoryGrid.connect("instant_action", self, "_on_instant_action")
	
	$History.text = ""
	
	# Monster health bar max + monster sprite
	var image_name = self._monster_data["type"].replace(' ', '')
	$MonsterControls/MonsterHealth.max_value = self._monster_data["max_health"]
	$MonsterControls/MonsterSprite.texture = load("res://assets/images/monsters/" + image_name + ".png")
	self._update_health_displays()

func set_monster_data(data):
	MonsterScaler.scale_monster_data(data)
	data["next_round_turns"] = data["turns"]
	data["max_health"] = data["health"]
	self._monster_data = data

func go_turbo():
	# Advanced mode ENABLED.
	self._size = [8, 6]
	self._advanced_mode = true

func _check_for_consecutive_picks_bonus(action):
	self._consecutive_checker.action_picked(action)

func _consecutive_tiles_bonus(action):
	self._multipliers += 1
	var multiplier_effect = 1 + (self._multipliers * self._MULTIPLIER_BONUS)
	$MultiplierLabel.text = "Multiplier: " + str(multiplier_effect) + "x"

func _show_turn_options(tiles_picked):
	if len(tiles_picked) == 0:
		tiles_picked.append("attack")
		tiles_picked.append("energy")
		tiles_picked.append("energy")
	
	for action in tiles_picked:
		var action_button = ActionButton.instance()
		action_button.initialize(action)
		self.add_child(action_button)
		
		action_button.position.x = $MemoryGrid.position.x + (64 * len(self._action_buttons))
		action_button.position.y = $MemoryGrid.position.y + ($MemoryGrid.tiles_high * 64)
		
		action_button.connect("action_selected", self, "_on_action")
		
		self._action_buttons.append(action_button)

func _on_instant_action(action):
	if action == "wrong":
		self._finish_turn()
	else:
		var action_button = ActionButton.instance()
		action_button.initialize(action)
		# Glorious hack: create an action button and it gets removed immediatley
		# There's no other easy way to refactor this code though, so ... :/
		self._on_action(action_button)

func _on_action(action_button):
	var multiplier_effect = 1 + (self._multipliers * self._MULTIPLIER_BONUS)
	var message = self._action_resolver.resolve(action_button.action, self.player, self._monster_data, multiplier_effect)
	if message != null:
		# Action went through. Had enough energy.
		self._add_message(message)
		self._actions_picked += 1
		
		self._update_health_displays()
		
		if self._monster_data["health"] <= 0:
			self._show_battle_end(true)
		
		var index = self._action_buttons.find(action_button)
		if index > -1: # guaranteed
			self._action_buttons.remove(index)
		self.remove_child(action_button)
		action_button.queue_free()
		
		
		if (
			(Features.is_enabled("instant actions") and self._actions_picked == self.player.num_actions) or
			# If non-instant actions, zero action buttons means picked wrong-only
			(not Features.is_enabled("instant actions") and (len(self._action_buttons) == 0 or self._actions_picked == self.player.num_actions))
		):
			self._finish_turn()

# health and energy
func _update_health_displays():
	self._update_player_health_displays()
	self._update_monster_health_displays()

func _update_player_health_displays():
	$YourHpLabel.text = Globals.PLAYER_NAME + ": " + str(self.player.current_health)
	$EnergyControls/EnergyLabel.text = str(self.player.energy)
	$EnergyControls/EnergyBar.value = round(100 * self.player.energy / self.player.max_energy)

func _update_monster_health_displays():
	var monster_health = self._monster_data["health"]
	$MonsterControls/MonsterHealth.value = monster_health
	$MonsterControls/MonsterHealth/Label.text = str(monster_health)

func _finish_turn():
	self._actions_picked = 0
	self._multipliers = 0
	$MultiplierLabel.text = "Multiplier: 1x"
	self._consecutive_checker.reset()
	
	for action_button in self._action_buttons:
		self.remove_child(action_button)
		action_button.queue_free()
		
	self._action_buttons = []
	
	if self._monster_data["health"] > 0:
		
		for n in range(self._monster_data["next_round_turns"]):
			
			var boost_amount = 0
			if Features.is_enabled("sequence battle triggers") or Features.is_enabled("n-back battle triggers"):
				var popup = null
				
				self.add_child(popup)
				popup.popup_centered()
				
				yield(popup, "popup_hide")
				boost_amount = popup.num_correct
				
			var message = self._action_resolver.monster_attacks(self._monster_data, self.player, boost_amount, $MemoryGrid)
			self._add_message(message)
		
		self._monster_data["next_round_turns"] = self._monster_data["turns"]
		
	if self.player.current_health <= 0:
		self._add_message(Globals.PLAYER_NAME + " faints!")
		self._show_battle_end(false)
		
	# Round done
	self.player.reset()
	$MemoryGrid.reset()
	self._update_health_displays()

func _show_battle_end(is_victory):
	$MemoryGrid.visible = false
	
	for button in self._action_buttons:
		self.remove_child(button)
		button.queue_free()
	
	$EnergyControls.queue_free()

	var popup = BattleResolution.end_battle(is_victory, self._monster_data)
	self.add_child(popup)
	popup.popup_centered()

func _add_message(message):
	$History.text = ""
	
	self._history_messages.append(message)
	# trim
	while len(self._history_messages) > MAX_MESSAGES:
		self._history_messages.remove(0) # oldest first
	
	for message in self._history_messages:
		$History.text += message + "\n"

func _on_EndTurnButton_pressed():
	self._finish_turn()
	
