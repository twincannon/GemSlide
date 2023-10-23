extends Control

@onready var level_button_scene = preload("res://scenes/level_editor/level_button.tscn")

func _ready():
	update_world()

func update_world():
	%WorldLabel.text = "World " + str(Globals.get_current_world_index() + 1)
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
				buttons[i].set_button_text(str(Globals.get_current_world_index()+1) + "-" + str(i+1))
				var level_path = Globals.current_world_data.level_data[i].resource_path
				buttons[i].set_button_score(SaveGame.get_level_score(level_path))
				#if OS.has_feature("web") == false:
				if SaveGame.is_level_unlocked(level_path) == false:
					buttons[i].disabled = true
			else:
				buttons[i].visible = false

func _on_world_button_left_pressed():
	var prev_idx = Globals.get_current_world_index() - 1
	if prev_idx >= 0:
		Globals.current_world_data = Globals.world_datas[prev_idx]
		update_world()


func _on_world_button_right_pressed():
	var next_idx = Globals.get_current_world_index() + 1
	if next_idx < Globals.world_datas.size():
		Globals.current_world_data = Globals.world_datas[next_idx]
		update_world()
