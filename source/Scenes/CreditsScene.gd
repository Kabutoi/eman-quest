extends Node2D

const PlayerData = preload("res://Entities/PlayerData.gd")
const SceneFadeManager = preload("res://Scripts/Effects/SceneFadeManager.gd")

const _CREDITS_TIME_SECONDS = 3
const _CONGRATS_FADE_TIME_SECONDS = 3
const _WAIT_TIME = 1
const _VISIBLE = Color(1, 1, 1, 1)
const _INVISIBLE = Color(1, 1, 1, 0)

func _ready():
	$ThanksLabel.text = "Game completed in " + PlayerData.seconds_to_time(Globals.player_data.play_time_seconds) + "\n" + $ThanksLabel.text
	
	$CreditsLabel.modulate.a = 0
	$ThanksLabel.modulate.a = 0
	
	yield(get_tree().create_timer(_WAIT_TIME), 'timeout')
	
	# Credits fade in ~3s
	var tween = Tween.new()
	self.add_child(tween)
	tween.interpolate_property($CreditsLabel, "modulate", _INVISIBLE, _VISIBLE, _CREDITS_TIME_SECONDS, Tween.TRANS_LINEAR, Tween.EASE_IN)
	tween.start()

	yield(get_tree().create_timer(_CREDITS_TIME_SECONDS), 'timeout')

	yield(get_tree().create_timer(_WAIT_TIME), 'timeout')

	# Thanks fade in ~3s
	tween = Tween.new()
	add_child(tween)
	tween.interpolate_property($ThanksLabel, "modulate", _INVISIBLE, _VISIBLE, _CONGRATS_FADE_TIME_SECONDS, Tween.TRANS_LINEAR, Tween.EASE_IN)
	tween.start()
	yield(get_tree().create_timer(_CREDITS_TIME_SECONDS), 'timeout')
	
	# Make sure on new game, stuff is not messed up
	self._clear_globals()
	
func _clear_globals():
		# This fixes lots of interesting bugs, that happen after game complete.
	Globals.bosses_defeated = 0
	Globals.showed_final_events = false
	Globals.beat_last_boss = false
	# To be on the safe side...
	Globals.player_data = PlayerData.new()
	Globals.overworld_position = null
	Globals.current_map = null

func _on_QuitButton_pressed():
	get_tree().change_scene("res://Scenes/Title.tscn")