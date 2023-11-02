extends Control

@onready var level_button_scene = preload("res://scenes/ui/level_button.tscn")

func _ready():
	update_world()

func update_world():
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
	for i in Globals.current_world_data.level_data:
		%LevelContainer.add_child(level_button_scene.instantiate())
	
	var buttons = %LevelContainer.get_children()
	for i in range(buttons.size()):
		if buttons[i] is LevelButton:
			if Globals.current_world_data.level_data.size() > i:
				buttons[i].level_to_load = Globals.current_world_data.level_data[i]
				buttons[i].set_button_text("Hole " + str(i+1))#str(Globals.get_current_world_index()+1) + "-" + str(i+1))
				var level_path = Globals.current_world_data.level_data[i].resource_path
				buttons[i].set_button_score(SaveGame.get_level_score(level_path))
				# This is real gross - instantiating the whole scene for a single var. Bleh
				# Make a level data resource or something? Actually this isn't as bad as it seems since it's only the level scene and not the game scene. But still
				var level_temp = Globals.current_world_data.level_data[i].instantiate()
				buttons[i].set_par_score(level_temp.par_moves)
				level_temp.queue_free()
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
