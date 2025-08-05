extends Control

@onready var level_button_scene = preload("res://scenes/ui/level_button.tscn")

#Gross that these are duplicated here and in gem.gd - consider moving to SkinManager
var ball_default_texture = preload("res://assets/art/golfball.png")
var ball_cat_texture = preload("res://assets/art/golfball_cat.png")
var ball_bowling_texture = preload("res://assets/art/bowlingball.png")

var options_balls:Array[TextureRect] = []

func _ready():
	SoundManager.stop_game_music()
	Globals.current_level_data = null
	Globals.set_custom_level_data({})
	update_world()
	populate_skin_list()
	
	options_balls.append(%OptionBallR)
	options_balls.append(%OptionBallG)
	options_balls.append(%OptionBallB)

func update_world():
	%ReturnToCourseButton.visible = false
	%CustomLevelsButton.visible = true
	
	%WorldLabel.text = "Course " + str(Globals.get_current_world_index() + 1) + ": " + Globals.current_world_data.world_name
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

func _on_options_close_button_pressed():
	%OptionsContainer.visible = false
	SaveGame.set_config_ball_hue("R", Globals.hue_red)
	SaveGame.set_config_ball_hue("G", Globals.hue_green)
	SaveGame.set_config_ball_hue("B", Globals.hue_blue)

func _on_options_button_pressed():
	%OptionsContainer.visible = true
	%OptionBallR.material.set_shader_parameter("hue_shift", Globals.hue_red)
	%OptionBallG.material.set_shader_parameter("hue_shift", Globals.hue_green)
	%OptionBallB.material.set_shader_parameter("hue_shift", Globals.hue_blue)
	%OptionBallRSlider.value = Globals.hue_red
	%OptionBallGSlider.value = Globals.hue_green
	%OptionBallBSlider.value = Globals.hue_blue
	var optionbutton = %SkinOptionButton
	match SaveGame.selected_skin:
		SkinManager.SkinType.DEFAULT:
			for i in range(optionbutton.item_count):
				if optionbutton.get_item_text(i) == SkinManager.get_skin_string(SkinManager.SkinType.DEFAULT):
					optionbutton.select(i)
					for ball in options_balls:
						ball.texture = ball_default_texture
		SkinManager.SkinType.CAT:
			for i in range(optionbutton.item_count):
				if optionbutton.get_item_text(i) == SkinManager.get_skin_string(SkinManager.SkinType.CAT):
					optionbutton.select(i)
					for ball in options_balls:
						ball.texture = ball_cat_texture
		SkinManager.SkinType.BOWLINGBALL:
			for i in range(optionbutton.item_count):
				if optionbutton.get_item_text(i) == SkinManager.get_skin_string(SkinManager.SkinType.BOWLINGBALL):
					optionbutton.select(i)
					for ball in options_balls:
						ball.texture = ball_bowling_texture

func populate_skin_list():
	%SkinOptionButton.add_item(SkinManager.get_skin_string(SkinManager.SkinType.DEFAULT))
	for skin in UnlockManager.get_unlocked_skins():
		%SkinOptionButton.add_item(skin)

func _on_skin_option_button_item_selected(index: int) -> void:
	var skin_type = SkinManager.get_skin_type_from_string(%SkinOptionButton.get_item_text(index))
	SaveGame.selected_skin = skin_type
	if skin_type == SkinManager.SkinType.DEFAULT:
		for ball in options_balls:
			ball.texture = ball_default_texture
	elif skin_type == SkinManager.SkinType.CAT:
		for ball in options_balls:
			ball.texture = ball_cat_texture
	elif skin_type == SkinManager.SkinType.BOWLINGBALL:
		for ball in options_balls:
			ball.texture = ball_bowling_texture
		

func _on_option_ball_r_slider_value_changed(value: float) -> void:
	%OptionBallR.material.set_shader_parameter("hue_shift", value)
	Globals.hue_red = value

func _on_option_ball_g_slider_value_changed(value: float) -> void:
	%OptionBallG.material.set_shader_parameter("hue_shift", value)
	Globals.hue_green = value

func _on_option_ball_b_slider_value_changed(value: float) -> void:
	%OptionBallB.material.set_shader_parameter("hue_shift", value)
	Globals.hue_blue = value
