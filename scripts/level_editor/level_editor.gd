extends Control

@onready var icon_scene = preload("res://scenes/level_editor/entity_icon.tscn")
@onready var fader_scene = preload("res://scenes/ui/text_fader.tscn")

@onready var grid_container = %GridContainer
@onready var colstext = %Cols
@onready var rowstext = %Rows
@onready var option_button = %OptionButton
@onready var level_name = %LevelName
@onready var par_moves_text:LineEdit = %ParMoves

var old_cols := -1
const GRID_MAX_SIZE := 20

func _ready():
	option_button.clear()
	for key in Globals.EntityType.keys():
		option_button.add_item(key)

func _on_cols_text_changed(_new_text):
	if int(_new_text) > GRID_MAX_SIZE:
		colstext.text = str(GRID_MAX_SIZE)
	generate_new_grid()

func _on_rows_text_changed(_new_text):
	if int(_new_text) > GRID_MAX_SIZE:
		rowstext.text = str(GRID_MAX_SIZE)
	generate_new_grid()
	
func update_grid_scale():
	var cols = float(colstext.text)
	var rows = float(rowstext.text)
	if cols > 0 and rows > 0:
		if cols == rows:
			$AspectRatioContainer.scale = Vector2(1, 1)
		elif cols > rows:
			$AspectRatioContainer.scale.y = rows / cols
			$AspectRatioContainer.scale.x = 1.0
		else:
			$AspectRatioContainer.scale.y = 1.0
			$AspectRatioContainer.scale.x = cols / rows
			
#		if cols == rows:
#			$AspectRatioContainer.size = Vector2(460, 460)
#		elif cols > rows:
#			$AspectRatioContainer.size.y = (rows / cols) * 460
#			$AspectRatioContainer.size.x = 460
#		else:
#			$AspectRatioContainer.size.y = 460
#			$AspectRatioContainer.size.x = (cols / rows) * 460
#		print($AspectRatioContainer.size)

func generate_new_grid(reset := false):
	var cols = min(int(colstext.text), GRID_MAX_SIZE)
	var rows = min(int(rowstext.text), GRID_MAX_SIZE)
	
	if cols <= 0 or rows <= 0:
		return
	
	if reset:
		old_cols = -1
	
	# Try to preserve entities
	var entities = []
	var children = grid_container.get_children()
	if old_cols > 0:
		for i in range(children.size()):
			if children[i] is EntityIconBase:
				entities.append({ "GridLoc": Vector2i(i % old_cols, i / old_cols), "Entity": children[i].entity_type })
	#y = i / cols
	#x = i % cols
	
	# Generate the new grid
	if colstext.text.is_valid_int() and rowstext.text.is_valid_int() and cols > 0 and rows > 0:
		var old_children = grid_container.get_children()
		for i in range(old_children.size() - 1, -1, -1):
			grid_container.remove_child(old_children[i])
			children[i].queue_free()
		grid_container.columns = cols
		for c in cols:
			for r in rows:
				var new_icon = icon_scene.instantiate()
				grid_container.add_child(new_icon)
	
	# Restore entities
	children = grid_container.get_children()
	for i in range(entities.size()):
		var target_idx = entities[i]["GridLoc"].x + (entities[i]["GridLoc"].y * cols)
		if children.size() > target_idx:
			children[target_idx].set_entity_type(entities[i]["Entity"])
	
	old_cols = int(colstext.text)
	update_grid_scale()


func _on_option_button_item_selected(index):
	for child in grid_container.get_children():
		if child is EntityIconBase:
			if child.button and child.button.button_pressed:
				child.set_entity_type(index as Globals.EntityType)
				child.button.set_pressed(false)
	option_button.select(0)

func get_grid_size() -> Vector2i:
	if grid_container.columns > 0:
		return Vector2i(grid_container.columns, grid_container.get_child_count() / grid_container.columns)
	return Vector2i.ZERO

func get_level_dict() -> Dictionary:
	var dict = { "GridSize": var_to_str(get_grid_size()), "LevelName": level_name.text, "Entities": [], "ParMoves": int(par_moves_text.text) }
	var children = grid_container.get_children()
	for i in children.size():
		if children[i] is EntityIconBase:
			dict["Entities"].append(children[i].entity_type)
	return dict

func save_level():
	if level_name.text.is_empty():
		# Show an error about level name must not be empty here
		return
	var dict = get_level_dict()
	print(dict)
	
	var file = FileAccess.open(Globals.SAVE_DIR + "level_" + dict["LevelName"] + ".json", FileAccess.WRITE)
	if file == null:
		printerr(FileAccess.get_open_error())
		return
	
	var json_string = JSON.stringify(dict, "\t")
	file.store_string(json_string)
	file.close()
	add_fader("Level saved")

func add_fader(text):
	var fader = fader_scene.instantiate()
	fader.label_text = text
	$FaderContainer.add_child(fader)
	
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


func _on_load_button_pressed():
	$LoadFileDialog.show()


func _on_load_file_dialog_file_selected(path):
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			printerr(FileAccess.get_open_error())
			return
		
		var content = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(content)
		if data == null:
			printerr("Cannot parse %s as a json string (%s)" % [path, content])
			add_fader("Failed to open level")
			return
		
		if !Globals.is_valid_custom_level(data):
			printerr("Loadad an invalid level")
			add_fader("Failed to open level, data is invalid")
			return
			
		load_data(data)
		
	else:
		printerr("Cannot open file at %s" % [path])

func load_data(data:Dictionary, reset_entities := true):
	colstext.text = str(str_to_var(data["GridSize"]).x)
	rowstext.text = str(str_to_var(data["GridSize"]).y)
	generate_new_grid(reset_entities)
	level_name.text = data["LevelName"]
	par_moves_text.text = str(data["ParMoves"])
	var children = grid_container.get_children()
	for i in range(data["Entities"].size()):
		if children.size() > i and children[i] is EntityIconBase:
			children[i].set_entity_type(data["Entities"][i] as Globals.EntityType)
			children[i].button.set_pressed(false)

func _on_main_menu_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_copy_button_pressed():
	if OS.has_feature("web") == false and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(JSON.stringify(get_level_dict()))
		add_fader("Level copied to clipboard")
	else:
		%LevelStringContainer.visible = true
		%LevelStringTextEdit.text = JSON.stringify(get_level_dict())
		


func _on_paste_button_pressed():
	var data = JSON.parse_string(DisplayServer.clipboard_get())
	if !Globals.is_valid_custom_level(data):
		printerr("Tried to paste an invalid level string")
		add_fader("Tried to paste an invalid level string")
		return
	load_data(data)


func _on_close_level_string_button_pressed():
	%LevelStringContainer.visible = false
