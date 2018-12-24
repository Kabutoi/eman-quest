extends Node2D

const PlayerData = preload("res://Entities/PlayerData.gd")

const TILE_WIDTH = 64
const TILE_HEIGHT = 64
# 1920x1080 / 64x64 => 30/17
const SUBMAP_WIDTH_IN_TILES = 60
const SUBMAP_HEIGHT_IN_TILES = 40
const WORLD_WIDTH_IN_TILES = 30 # 1920/64
const WORLD_HEIGHT_IN_TILES = 18 # 1080/64

signal clicked_on_map(position)

var player # current player instance. Used for collision detection mostly.

####
# Start: persist to save game. Set in world generator.
var maps = {} # eg. "forest/frost" => forest (AreaMap/data class) instance
var player_data = PlayerData.new() # the actual player data.
var story_data = {} # set in GenerateWorldScene; boss type, village name, etc.
# Vector2. come back to these coordinates after leaving the current dungeon. 
var overworld_position
var current_map # AreaMap instance
var transition_used # MapDestination instance
var sequence_trigger_difficulty = 4 # Number of tiles to show in sequence, eg. 4
# End: persist
####

# Used for positioning when changing maps. Probably does not need to be persisted
# because the value is only set very momentarily when the player steps on a
# transition to change rooms/maps.

var current_map_scene # PopulatedMapScene instance

### State to persist on area map after battles
# TODO: move into a separate autoload?
var pre_battle_position = [0, 0]
var won_battle = false
var battle_spoils = null # KeyItem
# Coordinates of monsters on-map before battle
var previous_monsters = null # type => pixel positions
var current_monster = null # monster.data_object
var current_monster_type = ""

func _ready():
	# Debugging code. Random seed, BUT print it out so we know what it is.
	var seed_value = randi()
	print("Universe #" + str(seed_value))
	randomize(seed_value)
	#seed(708369640446) 
	# slime forest => abcdef
	# frost forest => abc
	# river cave => 9, 99, 999, 999
	# lava cave => 321
	# castle dungeon => 4864
	# desert dungeon => 123321
	#seed("abcdef".hash())
	
# https://docs.godotengine.org/en/3.0/tutorials/inputs/inputevent.html#how-does-it-work
# Fires if nothing else handled the event, it seems.
func _unhandled_input(event):
	if (event is InputEventMouseButton and event.pressed) or (OS.has_feature("Android") and event is InputEventMouseMotion):
		var position = get_global_mouse_position()
		# Clicks seem ... off for some reason. Not sure why. Adjust manually.
		position.x -= Globals.TILE_WIDTH / 2
		position.y -= Globals.TILE_HEIGHT
		Globals.emit_signal("clicked_on_map", position)
	
# Returns integer value from min to max inclusive
# Source: https://godotengine.org/qa/2539/how-would-i-go-about-picking-a-random-number
func randint(minimum, maximum):
	return range(minimum, maximum + 1)[randi() % range(minimum, maximum + 1).size()]