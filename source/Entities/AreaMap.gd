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

func add_tile_data(tile_data):
	self.tile_data.append(tile_data)

