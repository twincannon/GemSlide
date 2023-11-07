@tool
extends Control

@onready var icon_scene = preload("res://scenes/level_editor/entity_icon.tscn")

@onready var grid_container = $GridContainer
@onready var colstext = $Cols
@onready var rowstext = $Rows
@onready var option_button = $OptionButton
@onready var level_name = $LevelName


func _ready():
	for key in Globals.EntityType.keys():
		option_button.add_item(key)



func _on_cols_text_changed(_new_text):
	generate_new_grid()

func _on_rows_text_changed(_new_text):
	generate_new_grid()
	
func generate_new_grid():
	var cols = int(colstext.text)
	var rows = int(rowstext.text)
	if colstext.text.is_valid_int() and rowstext.text.is_valid_int() and cols > 0 and rows > 0:
		var children = grid_container.get_children()
		for i in range(children.size() - 1, -1, -1):
			grid_container.remove_child(children[i])
			children[i].queue_free()
		grid_container.columns = cols
		for c in cols:
			for r in rows:
				var new_icon = icon_scene.instantiate()
				grid_container.add_child(new_icon)
		

func _on_option_button_item_selected(index):
	for child in grid_container.get_children():
		if child is EntityIconBase:
			if child.button and child.button.button_pressed:
				child.set_entity_type(index)
				child.button.set_pressed(false)
	option_button.select(0)
	save_level()

func get_grid_size() -> Vector2i:
	if grid_container.columns > 0:
		return Vector2i(grid_container.columns, grid_container.get_child_count() / grid_container.columns)
	return Vector2i.ZERO

func save_level():
	if level_name.text.is_empty():
		# Show an error about level name must not be empty here
		return
	var dict = { "GridSize": var_to_str(get_grid_size()), "LevelName": "", "Entities": [] }
	var children = grid_container.get_children()
	for i in children.size():
		if children[i] is EntityIconBase:
			dict["Entities"].append(children[i].entity_type)
	dict["LevelName"] = level_name.text
	print(dict)
	
	var file = FileAccess.open(Globals.SAVE_DIR + "level_" + dict["LevelName"] + ".json", FileAccess.WRITE)
	if file == null:
		printerr(FileAccess.get_open_error())
		return
	
	var json_string = JSON.stringify(dict, "\t")
	file.store_string(json_string)
	file.close()


func _on_level_name_text_changed(new_text):
	# Use regex to only allow A-z and numeric, dash and underscore
	var allowed_characters = "[A-Za-z0-9_-]"
	var old_caret_pos = level_name.caret_column
	var word := ""
	var regex = RegEx.new()
	regex.compile(allowed_characters)
	for valid_character in regex.search_all(new_text):
		word += valid_character.get_string()
	level_name.set_text(word)
	level_name.caret_column = old_caret_pos


func _on_save_button_pressed():
	save_level()
