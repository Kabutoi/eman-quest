extends KinematicBody2D

const SceneManagement = preload("res://Scripts/SceneManagement.gd")

const data = {
	"type": "SlimeBoss",
	"health": 100,
	"strength": 13,
	"defense": 4,
	"turns": 1,
	"experience points": 150,
	
	"skill_probability": 60, # 40 = 40%
	"skills": {
		# These should add up to 100
		"chomp": 100 # 20%,
	}
}

const IS_BOSS = true

var x = 0
var y = 0
var is_alive = true
var data_object = null # Boss.new() instance if we're a packed scene
var key_item

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	pass

func initialize(x, y, key_item):
	self.x = x
	self.y = y
	self.key_item = key_item

func initialize_from(data_object):
	self.data_object = data_object
	self.position.x = data_object.x
	self.position.y = data_object.y
	self.key_item = data_object.key_item
	
func to_dict():
	return {
		"data": self.data,
		"x": self.x,
		"y": self.y,
		"is_alive": self.is_alive,
		"key_item": self.key_item.to_dict(),
	}

func _on_Area2D_body_entered(body):
	SceneManagement.switch_to_battle_if_touched_player(self, body)
