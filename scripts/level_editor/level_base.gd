@tool
extends GridContainer
class_name LevelBase

@export var level_name:String
@export_multiline var tutorial:String
@export var par_moves:int
@export var dev_best:int
@export var num_buttons:int : set = set_num_buttons

@onready var icon_scene = preload("res://scenes/level_editor/entity_icon.tscn")

@export var export_level:bool : set = set_export_level

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
			new_icon.name = "EntityButton" + str(i)
			add_child(new_icon)
			new_icon.set_owner(self) # Makes the nodes show up in the scene tree and be editable

func set_export_level(_export):
	export_level = false
	# Do export logic here
	var path = get_tree().edited_scene_root.scene_file_path
	print("Exported to " + path.trim_suffix(".tscn") + ".json")
	var file = FileAccess.open(path.trim_suffix(".tscn") + ".json", FileAccess.WRITE)
	if file == null:
		printerr(FileAccess.get_open_error())
		return

	var dict = { "GridSize": var_to_str(get_grid_size()), "Entities": [], "EntityIDs": [], "ParMoves": par_moves, "DevBest": dev_best, "Tutorial": tutorial, "LevelName": level_name }
	var children = get_children()
	for i in children.size():
		if children[i] is EntityIconBase:
			dict["Entities"].append(int(children[i].entity_type))
			dict["EntityIDs"].append(int(children[i].entity_id))
	
	var json_string = JSON.stringify(dict, "\t")
	file.store_string(json_string)
	file.close()
