extends Node2D

const DictionaryHelper = preload("res://Scripts/DictionaryHelper.gd")

####
# An instance of a forest/dungeon/etc. generated by a *Generator class
# Pure data, no object (eg. player, slime, etc.) scenes
####

var entrance_position = []
var transitions = [] # warps to other maps. List of MapDestination instances.
var tiles_wide = 0
var tiles_high = 0
var map_type = "" # eg. forest
var tile_data = [] # 2D arrays of tile names
var tileset_path
var monsters = {} # Type => list of coordinates. Kept so we know what to restore when coming back after battle.
var treasure_chests = [] # instances of TreasureChest (class, not the scene)
var bosses = {} # Type => Boss instances created with .new

func _init(map_type, tileset_path, entrance_position, tiles_wide, tiles_high):
	self.tileset_path = tileset_path
	self.map_type = map_type
	self.entrance_position = entrance_position
	self.tiles_wide = tiles_wide
	self.tiles_high = tiles_high

func to_dict():
	return {
		"filename": "res://Entities/AreaMap.gd",
		"entrance_position": self.entrance_position,
		"transitions": DictionaryHelper.array_to_dictionary(self.transitions),
		"tiles_wide": self.tiles_wide,
		"tiles_high": self.tiles_high,
		"map_type": self.map_type,
		"tile_data": DictionaryHelper.array_to_dictionary(self.tile_data),
		"monsters": DictionaryHelper.dictionary_values_to_dictionary(self.monsters),
		"treasure_chests": DictionaryHelper.array_to_dictionary(self.treasure_chests),
		"bosses": DictionaryHelper.dictionary_values_to_dictionary(self.bosses),
		"tileset_path": self.tileset_path
	}

static func from_dict(dict):
	var map = new(dict["map_type"], dict["tileset_path"], dict["entrance_position"],
		dict["tiles_wide"], dict["tiles_high"])
	
	map.entrance_position = dict["entrance_position"]
	map.transitions = DictionaryHelper.array_from_dictionary(dict["transitions"])
	map.tiles_wide = dict["tiles_wide"]
	map.tiles_high = dict["tiles_high"]
	map.map_type = dict["map_type"]
	map.tile_data = DictionaryHelper.array_from_dictionary(dict["tile_data"])
	map.monsters = DictionaryHelper.dictionary_values_from_dictionary(dict["monsters"])
	map.treasure_chests = DictionaryHelper.array_from_dictionary(dict["treasure_chests"])
	map.bosses = DictionaryHelper.dictionary_values_from_dictionary(dict["bosses"])
	map.tileset_path = dict["tileset_path"]

	return map

func add_tile_data(tile_data):
	self.tile_data.append(tile_data)

