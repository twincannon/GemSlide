@tool
extends GridContainer
class_name LevelBase

@export_multiline var tutorial:String
@export var par_moves:int
@export var dev_best:int
@export var num_buttons:int : set = set_num_buttons

@onready var icon_scene = preload("res://scenes/level_editor/entity_icon.tscn")

func get_grid_size():
	if columns > 0:
		return Vector2i(columns, get_child_count() / columns)
	return Vector2i(0,0)

func get_entities():
	var entities = []
	for i in get_children():
		if i is EntityIconBase:
			entities.append(i.get_entity())
	return entities

func set_num_buttons(new_num_buttons):
	num_buttons = new_num_buttons
	if icon_scene and Engine.is_editor_hint():
		var old_children = get_children()
		for i in range(old_children.size() - 1, -1, -1):
			remove_child(old_children[i])
			old_children[i].queue_free()
		for i in range(new_num_buttons):
			var new_icon = icon_scene.instantiate()
			add_child(new_icon)
			new_icon.set_owner(self) # Makes the nodes show up in the scene tree and be editable
