extends WindowDialog

# List just takes strings. Keep references to items.
var _all_items = []
var _selected_item = null

func _ready():
	self._clear_selected_display()
	self._populate_item_list()

func _populate_item_list():
	$ItemList.clear()
	self._all_items = []
	
	for item in Globals.player_data.key_items:
		self._add_item(item)

func _add_item(item):
	var name = item.item_name
	$ItemList.add_item(name)
	self._all_items.append(item)

func _on_ItemList_nothing_selected():
	$ItemList.clear()
	self._selected_item = null
	self._clear_selected_display()

func _on_ItemList_item_selected(index):
	var item = self._all_items[index]
	# $Sprite.visible = true
	# Sprite.Texture/Region = ...
	$ItemName.text = item.item_name
	$Description.text = item.description
	self._selected_item = item

func _clear_selected_display():
	$Sprite.visible = false
	$ItemName.text = ""
	$Description.text = ""