extends Node

var item_name = ""
var description = ""

func initialize(item_name, description):
	self.item_name = item_name
	self.description = description

func to_dict():
	return {
		"item_name": self.item_name,
		"description": self.description
	}