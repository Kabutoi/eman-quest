extends Node2D

const AreaMap = preload("res://Entities/AreaMap.gd")
const AreaType = preload("res://Scripts/Enums/AreaType.gd")
const AudioManager = preload("res://Scripts/AudioManager.gd")
const Boss = preload("res://Entities/Battle/Boss.gd")
const CaveGenerator = preload("res://Scripts/Generators/CaveGenerator.gd")
const DungeonGenerator = preload("res://Scripts/Generators/DungeonGenerator.gd")
const EndGameMap = preload("res://Scenes/Maps/EndGameMap.tscn")
const ForestGenerator = preload("res://Scripts/Generators/ForestGenerator.gd")
const HomeMap = preload("res://Scenes/Maps/Home.tscn")
const KeyItem = preload("res://Entities/KeyItem.gd")
const MapDestination = preload("res://Entities/MapDestination.gd")
const MapLayoutGenerator = preload("res://Scripts/Generators/MapLayoutGenerator.gd")
const OverworldGenerator = preload("res://Scripts/Generators/OverworldGenerator.gd")
const Quest = preload("res://Entities/Quest.gd")
const SceneFadeManager = preload("res://Scripts/Effects/SceneFadeManager.gd")

# Moving to (map.width / 2, map.height - 1) takes us below the bottom-most tile.
# Moving up one tile takes us directly on the transition; two tiles, now we're talking.
# Now we're one tile above the transition back down.
const _TRANSITION_UP_BUFFER_TILES = 2
# Three areas per game
const _NUM_AREAS = 3
const _SUBMAPS_PER_AREA = 4

const _GENERATOR_CLASSES = {
	"Forest": ForestGenerator,
	"Cave": CaveGenerator,
	"Dungeon": DungeonGenerator
}

const ForestVariations = ["Slime", "Frost", "Death"]
const CaveVariations = ["River", "Lava"] # Crystal
const DungeonVariations = ["Castle", "Desert"]

var delay_to_display = true

func _ready():
	$StartButton.visible = false
	var game_number = self._print_and_set_seed()
	
	if not Globals.is_testing:
		var tree = get_tree()
		SceneFadeManager.fade_in(tree, Globals.SCENE_TRANSITION_TIME_SECONDS)
		yield(tree.create_timer(Globals.SCENE_TRANSITION_TIME_SECONDS), 'timeout')
	
	Globals.quest = Quest.new()
	self._generate_world()
	$Status.text = "World #" + str(game_number) + " generated!"
	$StartButton.visible = true
	
	AudioManager.new().add_click_noise_to_controls(self)

func _start_game():
	var tree = get_tree()
	SceneFadeManager.fade_out(tree, Globals.SCENE_TRANSITION_TIME_SECONDS)
	yield(tree.create_timer(Globals.SCENE_TRANSITION_TIME_SECONDS), 'timeout')
	tree.change_scene("res://Scenes/QuranScene.tscn")
	
func _generate_world():
	var world_areas = _pick_dungeons_and_variations()
	Globals.world_areas = world_areas
#
	for area in world_areas:
		var divider_index = area.find('/')
		var map_type = area.substr(0, divider_index)
		var variation = area.substr(divider_index + 1, len(area))
		var generator_class = _GENERATOR_CLASSES[map_type]
		var maps = _generate_subarea_maps(variation, generator_class, _SUBMAPS_PER_AREA)
		Globals.maps[map_type + "/" + variation] = maps
	
	# Add fixed maps: end-game / "Final", Overworld, Home, etc.
	# NB: these are destroyed (GCed) and recreated (.instance()) as needed.
	# They should be stateless.
	Globals.maps["Final"] = EndGameMap.instance()
	Globals.maps["Home"] = HomeMap.instance()
	
	# Generate last; generating the entrance into the first sub-map
	# of each dungeon eg. the forest, requires Globals.maps.
	var overworld = OverworldGenerator.new().generate(Globals.maps.keys())
	Globals.maps["Overworld"] = overworld
	
func _generate_subarea_maps(variation, generator_class, num_submaps):
	var layout = MapLayoutGenerator.generate_layout(num_submaps)
	var submaps = []
	
	for submap in layout:
		# Generate transitions here, used for path generation. Reusing generators leads
		# to weird stateful business, like forest map 1 having clearings and the boss
		# being generated at those clearing coordinates in forest map 2. Erp.
		# I don't think generators were ever supposed to be reused.
		var generator = generator_class.new()
		var data = self._generate_transitions(submap, generator.map_width, generator.map_height)
		var transitions = data["transitions"]
		var entrance = data["entrance"]
		
		var map = generator.generate(submap, transitions, variation)
		map.grid_x = submap.grid_x
		map.grid_y = submap.grid_y
		map.entrance_from_overworld = entrance
		
		Globals.quest.add_quest_content_if_applicable(map, variation)
		
		submaps.append(map)
	
	return submaps

func _generate_transitions(submap, map_width, map_height):
	var transitions = []
	var entrance_from_overworld = null
	
	if submap.area_type == AreaType.AREA_TYPE.ENTRANCE:
		var position = Vector2(0, 0)
		
		# Caves use this to paint the tile with the correct light-showing tile
		var direction_back = null
		
		###
		# NB: maps are generated independently. The only way we get both sides of a
		# transition to line up (eg. bottom of map (0, 0) connects to top of map (0,1)
		# is to hard-code the center x/y appropriately.
		if submap.connections.has("right") or submap.connections.has("left"):
			position.y = floor(map_height / 2)
			position.x = 0
			direction_back = "left"
			
			# Offset y by 1 to correctly enter on the right position
			entrance_from_overworld = Vector2(1, position.y - 1)
			
			if submap.connections.has("left"):
				# Left side is already taken, generate entrance on RHS
				position.x = map_width - 1
				direction_back = "right"
				entrance_from_overworld = Vector2(position.x - 1, position.y - 1)
				
		elif submap.connections.has("up") or submap.connections.has("down"):
			position.x = floor(map_width / 2)
			position.y = 0
			direction_back = "up"
			entrance_from_overworld = Vector2(position.x, 1)
			
			if submap.connections.has("up"):
				# Top side is already taken, generate entrance on bottom
				position.y = map_height - 1
				direction_back = "down"
				entrance_from_overworld = Vector2(position.x, position.y - 2)
				
		transitions.append(MapDestination.new(position, "Overworld", null, direction_back))
	
	for direction in submap.connections.keys():
		var destination = submap.connections[direction]
		var my_position = Vector2(0, 0)
		var target_position = Vector2(0, 0)
		
		# Lots of magic numbers here, +- 1 to position correctly when transitioning
		if direction == "left":
			my_position = Vector2(0, floor(map_height / 2)) 
			target_position = Vector2(map_width - 2, floor(map_height / 2) - 1)
		elif direction == "right":
			my_position = Vector2(map_width - 1, floor(map_height / 2))
			target_position = Vector2(1, floor(map_height / 2) - 1)
		elif direction == "up":
			my_position = Vector2(floor(map_width / 2), 0)
			target_position = Vector2(floor(map_width / 2), map_height - 1 - _TRANSITION_UP_BUFFER_TILES)
		elif direction == "down":
			my_position = Vector2(floor(map_width / 2), map_height - 1)
			target_position = Vector2(floor(map_width / 2), 0)
			
		transitions.append(MapDestination.new(my_position, destination, target_position, direction))
	
	return { "transitions": transitions, "entrance": entrance_from_overworld }

# Given: slime/forest, frost/forest, death/forest, lava/cave, river/cave, castle/dungeon, desert/dungeon
# Return a list of three of these, but no two adjacent ones can be the same type
# eg. slime/forest, river/cave, frost/forest is valid, but
# slime/forest, frost/forest, river?cave is not.
func _pick_dungeons_and_variations():
	# Man, this is inefficient and ugly, but it does the job.	
	var all_types = []
	
	for variation in ForestVariations:
		all_types.append(["Forest", variation])
	for variation in CaveVariations:
		all_types.append(["Cave", variation])
	for variation in DungeonVariations:
		all_types.append(["Dungeon", variation])
			
	var previous = all_types[randi() % len(all_types)]
	var picked = [previous]
	
	while len(picked) < _NUM_AREAS:
		var next = all_types[randi() % len(all_types)]
		# Not already picked and not the same type as the previous one
		if not next in picked and next[0] != previous[0]:
			picked.append(next)
			previous = next
	
	var to_return = []
	for map_and_variation in picked:
		# ["Forest", "Death"] => "Forest/Death"
		to_return.append(map_and_variation[0] + "/" + map_and_variation[1])
	
	print(to_return)
	return to_return
	
func _print_and_set_seed():
	# Random seed, BUT print it out so we know what it is.
	# Without this ... we always get the same seed. Wut?
	randomize()
	var seed_value = randi()
	print("Game #" + str(seed_value))
	seed(seed_value)
	Globals.seed_value = seed_value
	return seed_value

func _on_Button_pressed():
	$StartButton.disabled = true
	var audio_player = AudioManager.new()
	add_child(audio_player)
	audio_player.play_sound("button-click")
	
	self._start_game()
