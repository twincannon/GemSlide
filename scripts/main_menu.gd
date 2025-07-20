extends Control

@onready var level_button_scene = preload("res://scenes/ui/level_button.tscn")

func _ready():
	Globals.current_level_data = null
	update_world()

func update_world():
	%ReturnToCourseButton.visible = false
	%CustomLevelsButton.visible = true
	
	%WorldLabel.text = "Course " + str(Globals.get_current_world_index() + 1)
	var world_idx = Globals.get_current_world_index()
	%WorldButtonLeft.visible = world_idx > 0
	%WorldButtonRight.visible = world_idx < Globals.world_datas.size() - 1
	populate_button_grid()

func populate_button_grid():
	# Clear anything in our level container
	for i in %LevelContainer.get_children():
		%LevelContainer.remove_child(i)
		i.queue_free()
	
	# Add buttons to level container for each level
	for i in Globals.current_world_data.level_data_json:
		%LevelContainer.add_child(level_button_scene.instantiate())
	
	var buttons = %LevelContainer.get_children()
	for i in range(buttons.size()):
		if buttons[i] is LevelButton:
			if Globals.current_world_data.level_data_json.size() > i:
				buttons[i].level_to_load = Globals.current_world_data.level_data_json[i]
				buttons[i].set_button_text("Hole " + str(i+1))#str(Globals.get_current_world_index()+1) + "-" + str(i+1))
				var level_path = Globals.current_world_data.level_data_json[i].resource_path
				buttons[i].set_button_score(SaveGame.get_level_score(level_path))
				var data = Globals.current_world_data.level_data_json[i].get_data()
				buttons[i].set_par_score(int(data["ParMoves"]))
				#if OS.has_feature("web") == false:
				if SaveGame.is_level_unlocked(level_path) == false:
					buttons[i].disabled = true
			else:
				buttons[i].visible = false

func _on_world_button_left_pressed():
	%LevelScrollContainer.scroll_vertical = 0
	var prev_idx = Globals.get_current_world_index() - 1
	if prev_idx >= 0:
		Globals.current_world_data = Globals.world_datas[prev_idx]
		update_world()


func _on_world_button_right_pressed():
	%LevelScrollContainer.scroll_vertical = 0
	var next_idx = Globals.get_current_world_index() + 1
	if next_idx < Globals.world_datas.size():
		Globals.current_world_data = Globals.world_datas[next_idx]
		update_world()


func _on_level_editor_button_pressed():
	get_tree().change_scene_to_file("res://scenes/level_editor/level_editor.tscn")


func _on_custom_levels_button_pressed():
	%WorldLabel.text = "Custom Levels"
	for i in %LevelContainer.get_children():
		%LevelContainer.remove_child(i)
		i.queue_free()
	#get each file that starts with "level_" in our Globals.SAVE_DIR
	for file in SaveGame.get_custom_level_files():
		var new_button = level_button_scene.instantiate()
		%LevelContainer.add_child(new_button)
		new_button.set_button_text(file.lstrip("level_").rstrip(".json"))
		var data = SaveGame.get_custom_level_data(Globals.SAVE_DIR + file)
		if Globals.is_valid_custom_level(data):
			new_button.custom_level_data = data
			new_button.set_button_score(0)
			new_button.set_par_score(data["ParMoves"])
		else:
			new_button.visible = false
			new_button.queue_free()
	%ReturnToCourseButton.visible = true
	%CustomLevelsButton.visible = false


func _on_return_to_course_button_pressed():
	update_world()


func _on_option_ball_r_pressed():
	%OptionBallG.set_pressed(false)
	%OptionBallB.set_pressed(false)
	%ColorPicker.color = %OptionBallR.modulate


func _on_option_ball_g_pressed():
	%OptionBallR.set_pressed(false)
	%OptionBallB.set_pressed(false)
	%ColorPicker.color = %OptionBallG.modulate


func _on_option_ball_b_pressed():
	%OptionBallR.set_pressed(false)
	%OptionBallG.set_pressed(false)
	%ColorPicker.color = %OptionBallB.modulate


func _on_color_picker_color_changed(color):
	var button_to_change = null
	if %OptionBallR.is_pressed():
		button_to_change = %OptionBallR
		Globals.COLOR_RED = color
		SaveGame.set_config_ball_color("R", color)
	elif %OptionBallG.is_pressed():
		button_to_change = %OptionBallG
		Globals.COLOR_GREEN = color
		SaveGame.set_config_ball_color("G", color)
	elif %OptionBallB.is_pressed():
		button_to_change = %OptionBallB
		Globals.COLOR_BLUE = color
		SaveGame.set_config_ball_color("B", color)
	
	if button_to_change:
		button_to_change.modulate = color


func _on_options_close_button_pressed():
	%OptionsContainer.visible = false


func _on_options_button_pressed():
	%OptionsContainer.visible = true
	%OptionBallR.modulate = Globals.COLOR_RED
	%OptionBallG.modulate = Globals.COLOR_GREEN
	%OptionBallB.modulate = Globals.COLOR_BLUE
