extends Node

const AreaMap = preload("res://Entities/AreaMap.gd")
const Boss = preload("res://Entities/Battle/Boss.gd")
const EquipmentGenerator = preload("res://Scripts/Generators/EquipmentGenerator.gd")
const KeyItem = preload("res://Entities/KeyItem.gd")
const MapDestination = preload("res://Entities/MapDestination.gd")
const AreaType = preload("res://Scripts/Enums/AreaType.gd")
const SpotFinder = preload("res://Scripts/Maps/SpotFinder.gd")
const StatType = preload("res://Scripts/Enums/StatType.gd")
const TreasureChest = preload("res://Entities/TreasureChest.gd")
const TwoDimensionalArray = preload("res://Scripts/TwoDimensionalArray.gd")

const _BOSS_DATA = {
	"Castle": {
	}
}

const _VARIANT_TILESETS = {
	"Castle": "auto:CastleDungeon",
}

const _PATHS_BUFFER_FROM_EDGE = 5
const _NUM_ROOMS = [10, 15]
const _NUM_CHESTS = [0, 1]
const _ROOM_SIZE = [8, 10] # tiles
const _ITEM_POWER = [30, 50]
const _ROOM_WALL_HEIGHT = 5 # in tiles
const _NUM_CEILING_TILES = 3 # in tiles
const _MAX_TORCHES_PER_ROOM = 2 # inclusive

const ENTITY_TILES = {
	"Door": preload("res://Entities/MapEntities/Door.tscn")
}

var map_width = Globals.SUBMAP_WIDTH_IN_TILES
var map_height = Globals.SUBMAP_HEIGHT_IN_TILES

var _ground_map = []
var _wall_map = []

# Called once per game
func generate(submap, transitions, variation_name):
	var tileset = _VARIANT_TILESETS[variation_name]
	var map = AreaMap.new("Dungeon", variation_name, tileset, map_width, map_height, submap.area_type)

	var tile_data = self._generate_dungeon(submap.area_type, transitions) # generates paths too
	self._ground_map = tile_data[0]
	self._wall_map = tile_data[1]

	map.transitions = transitions
	map.treasure_chests = self._generate_treasure_chests()

	# TODO: generate boss
	#if submap.area_type == AreaType.BOSS:
	#	map.bosses = self._generate_boss(variation_name)

	for data in tile_data:
		map.add_tile_data(data)

	return map

func _generate_boss(variation_name):
	# TODO: place boss
	var coordinates = [0, 0] # self._clearings_coordinates[0]
	var pixel_coordinates = [coordinates[0] * Globals.TILE_WIDTH, coordinates[1] * Globals.TILE_HEIGHT]

	#var kufi = KeyItem.new()
	#kufi.initialize("Bloody Kufi", "A white kufi (skull-cap) stained with blood ...")

	var boss = Boss.new()
	boss.initialize(pixel_coordinates[0], pixel_coordinates[1], _BOSS_DATA[variation_name], null)
	return { boss.data.type: [boss] }

func _generate_dungeon(area_type, transitions):
	var to_return = []

	var ground_map = TwoDimensionalArray.new(self.map_width, self.map_height)
	to_return.append(ground_map)
	self._fill_with("Ground", ground_map)

	var wall_map = TwoDimensionalArray.new(self.map_width, self.map_height)
	to_return.append(wall_map)
	self._fill_with("Ceiling", wall_map)
	
	var decoration_map = TwoDimensionalArray.new(self.map_width, self.map_height)
	to_return.append(decoration_map)

	self._generate_rooms(transitions, ground_map, wall_map, decoration_map)

	return to_return

func _generate_rooms(transitions, ground_map, wall_map, decoration_map):
	
	var to_generate = Globals.randint(_NUM_ROOMS[0], _NUM_ROOMS[1])
	var min_room_distance = _ROOM_SIZE[1] + _PATHS_BUFFER_FROM_EDGE # max size = min distance
	var rooms = [] # Array of Rect2s
	var previous = null
	var tries = 0
	var paths_to_generate = [] # Array of [source, target] pairs

	while to_generate > 0 and tries < 1000:
		tries += 1
		var width = Globals.randint(_ROOM_SIZE[0], _ROOM_SIZE[1])
		var height = Globals.randint(_ROOM_SIZE[0], _ROOM_SIZE[1])
		var x = Globals.randint(_PATHS_BUFFER_FROM_EDGE, map_width - width - _PATHS_BUFFER_FROM_EDGE - 1)
		var y = Globals.randint(_PATHS_BUFFER_FROM_EDGE, map_height - height - _PATHS_BUFFER_FROM_EDGE - 1)
		
		if previous != null and sqrt(pow(x - previous.position.x, 2) + pow(y - previous.position.y, 2)) <= min_room_distance:
			continue
			
		var current_room = Rect2(x, y, width, height)
		var generate = true

		for node in rooms:
			# Not too close to previous rooms. Implicitly, doesn't overlap.
			if sqrt(pow(x - node.position.x, 2) + pow(y - node.position.y, 2)) <= min_room_distance:
				generate = false
				continue
			
			# Doesn't overlap previous rooms
			if current_room.intersects(node):
				generate = false
				continue
		
		if generate:
			self._generate_room(current_room, ground_map, wall_map, decoration_map)
			rooms.append(current_room)
			if previous != null:
				var source = _center_of(previous)
				var target = _center_of(current_room)
				paths_to_generate.append([source, target])
			previous = current_room
			to_generate -= 1

	# Generate paths later so they don't add 2x2 walls over the floor
	for data in paths_to_generate:
		var source = data[0]
		var target = data[1]
		self._generate_straight_path(source, target, ground_map, wall_map, decoration_map)
	
	# Generate a node close to entrances (5-10 tiles "in" from the entrance).
	# Then, connect entrance => new node => closest path node
	for transition in transitions:

		var entrance = [transition.my_position.x, transition.my_position.y]
		var destination = [transition.my_position.x, transition.my_position.y]
		var offset = Globals.randint(5, 10)

		if entrance[0] == 0:
			# left entrance
			destination[0] += offset
		elif entrance[0] == map_width - 1:
			# right entrance
			destination[0] -= offset
		elif entrance[1] == 0:
			# top entrance
			destination[1] += offset
		elif entrance[1] == map_height - 1:
			# bottom entrance
			destination[1] -= offset
		
		self._generate_straight_path(entrance, destination, ground_map, wall_map, decoration_map)
		var closest_node = self._find_closest_room_to(destination, rooms)
		self._generate_straight_path(destination, _center_of(closest_node), ground_map, wall_map, decoration_map)

func _center_of(room):
	var x = room.position.x + floor(room.size.x / 2)
	var y = room.position.y + floor(room.size.y / 2)
	return [x, y]

func _generate_straight_path(point1, point2, ground_map, wall_map, decoration_map):
	var start_x = point1[0]
	var start_y = point1[1]
	var stop_x = point2[0]
	var stop_y = point2[1]
	
	var dx = stop_x - start_x
	var dy = stop_y - start_y
		
	if randi() % 100 <= 50:
		# horizontal, then vertical
		self._generate_path([start_x, start_y], [stop_x, start_y], ground_map, wall_map, decoration_map)
		self._generate_path([stop_x, start_y], [stop_x, stop_y], ground_map, wall_map, decoration_map)
		self._generate_door(start_x + ((stop_x - start_x) / 2), start_y, wall_map, decoration_map)
	else:
		# vertical, then horizontal
		self._generate_path([start_x, start_y], [start_x, stop_y], ground_map, wall_map, decoration_map)
		self._generate_path([start_x, stop_y], [stop_x, stop_y], ground_map, wall_map, decoration_map)
		self._generate_door(start_x, start_y + ((stop_y - start_y) / 2), wall_map, decoration_map)

func _find_closest_room_to(room, rooms):
	var closest_node = rooms[0]
	var closest_distance = pow(closest_node.position.x - room[0], 2) + pow(closest_node.position.y - room[1], 2)

	for candidate in rooms:
		var distance = pow(candidate.position.x - room[0], 2) + pow(candidate.position.y - room[1], 2)
		if distance < closest_distance:
			closest_node = candidate
			closest_distance = distance
	
	return closest_node

func _generate_door(x, y, wall_map, decoration_map):
	var adjacent_ground = 0
	
	if wall_map.get(x - 1, y - 1) == null:
		adjacent_ground += 1
	if wall_map.get(x, y - 1) == null:
		adjacent_ground += 1
	if wall_map.get(x + 1, y - 1) == null:
		adjacent_ground += 1
	if wall_map.get(x - 1, y) == null:
		adjacent_ground += 1
	if wall_map.get(x + 1, y) == null:
		adjacent_ground += 1
	if wall_map.get(x - 1, y + 1) == null:
		adjacent_ground += 1
	if wall_map.get(x, y + 1) == null:
		adjacent_ground += 1
	if wall_map.get(x + 1, y + 1) == null:
		adjacent_ground += 1
	
	# Must have two adjacent wall tiles
	if adjacent_ground == 2:
		self._set_tile([x, y], "Door", decoration_map)

func _generate_room(room_rect, ground_map, wall_map, decoration_map):
	var wall_tiles = _ROOM_WALL_HEIGHT - _NUM_CEILING_TILES
	
	for v in range(room_rect.size.y):
		for u in range(room_rect.size.x):
			var x = room_rect.position.x + u
			var y = room_rect.position.y + v
			self._convert_to_ground([x, y], ground_map, wall_map, decoration_map)
	
	for v in range(0, _ROOM_WALL_HEIGHT): # five tiles tall
		for u in range(room_rect.size.x):
			var x = room_rect.position.x + u
			var y = room_rect.position.y - (_ROOM_WALL_HEIGHT - 1) + v
			var type = "Wall"
			# Three rows ceiling, then two of wall
			if v < _NUM_CEILING_TILES:
				type = "Ceiling"
			self._set_tile([x, y], type, wall_map)
	
	var num_torches = randi() % (_MAX_TORCHES_PER_ROOM + 1)
	var x_per_torch = round(room_rect.size.x / (num_torches + 1))
	
	for i in range(num_torches):
		self._add_torch(room_rect.position.x + ((i + 1) * x_per_torch), room_rect.position.y - 1, wall_map, decoration_map)
	
func _add_torch(x, y, wall_map, decoration_map):
	# Place only on walls
	if wall_map.get(x, y) == "Wall":
		decoration_map.set(x, y, "Torch")

func _generate_path(point1, point2, ground_map, wall_map, decoration_map):
	var from_x = point1[0]
	var from_y = point1[1]

	var to_x = point2[0]
	var to_y = point2[1]

	self._convert_to_ground([from_x, from_y], ground_map, wall_map, decoration_map)

	while from_x != to_x or from_y != to_y:
		# If we're farther away on x-axis, move horizontally.
		if abs(from_x - to_x) > abs(from_y - to_y):
			from_x += sign(to_x - from_x)
		else:
			from_y += sign(to_y - from_y)

		self._convert_to_ground([from_x, from_y], ground_map, wall_map, decoration_map)
		
		# Decorate any paths with 2-tile high walls
		# This shortens ceilings and shows awesome walls instead
		if wall_map.get(from_x, from_y - 1) == "Ceiling":
			self._set_tile([from_x, from_y - 1], "Wall", wall_map)
		if wall_map.get(from_x, from_y - 2) == "Ceiling":
			self._set_tile([from_x, from_y - 2], "Wall", wall_map)

func _generate_treasure_chests():
	var num_chests = Globals.randint(_NUM_CHESTS[0], _NUM_CHESTS[1])
	var chests = []
	var chests_coordinates = []
	var types = ["weapon", "armour"]
	var stats = {"weapon": StatType.Strength, "armour": StatType.Defense}

	while num_chests > 0:
		var spot = SpotFinder.find_empty_spot(map_width, map_height,
			self._ground_map, self._wall_map, ["Ground"], chests_coordinates)

		var type = types[randi() % len(types)]
		var power = Globals.randint(_ITEM_POWER[0], _ITEM_POWER[1])
		var stat = stats[type]
		var item = EquipmentGenerator.generate(type, stat, power)
		var treasure = TreasureChest.new()
		treasure.initialize(spot[0], spot[1], item)
		chests.append(treasure)
		chests_coordinates.append(spot)
		num_chests -= 1

	return chests

# Almost common with OverworldGenerator
func _fill_with(tile_name, map_array):
	for y in range(0, map_height):
		for x in range(0, map_width):
			map_array.set(x, y, tile_name)

func _convert_to_ground(position, ground_map, wall_map, decoration_map):
	self._convert_to(position, "Ground", ground_map, wall_map, decoration_map)

func _convert_to(position, type, ground_map, wall_map, decoration_map):
	# Draws dirt at the specified position. Also clears trees for
	# one tile in all directions surrounding the dirt (kind of like
	# drawing with a 3x3 grass brush around the dirt).
	var x = position[0]
	var y = position[1]

	if x >= 0 and x < map_width and y >= 0 and y < map_height:
		ground_map.set(x, y, type)
		wall_map.set(x, y, null) # remove wall
		decoration_map.set(x, y, null) # remove decoration

func _set_tile(position, type, map):
	# Draws dirt at the specified position. Also clears trees for
	# one tile in all directions surrounding the dirt (kind of like
	# drawing with a 3x3 grass brush around the dirt).
	var x = position[0]
	var y = position[1]

	if x >= 0 and x < map_width and y >= 0 and y < map_height:
		map.set(x, y, type)

func _clear_if_wall(wall_map, x, y):
	if x >= 0 and x < map_width:
		if y >= 0 and y < map_height:
			if wall_map.get(x, y) != null:
				wall_map.set(x, y, null)

