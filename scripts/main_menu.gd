extends Control

var current_world

@onready var level_button_scene = preload("res://scenes/level_editor/level_button.tscn")

func _ready():
	if Globals.current_world_data:
		current_world = Globals.current_world_data #if we're coming from a level, use that world
	elif Globals.world_datas.size() > 0:
		current_world = Globals.world_datas[0]
		Globals.current_world_data = Globals.world_datas[0]
	var current_world_idx = Globals.world_datas.find(current_world)
	
	# Clear anything in our level container
	for i in %LevelContainer.get_children():
		i.queue_free()
	
	# Add buttons to level container for each level
	for i in current_world.level_data:
		%LevelContainer.add_child(level_button_scene.instantiate())
	
	var buttons = %LevelContainer.get_children()
	for i in range(buttons.size()):
		if buttons[i] is LevelButton:
			if Globals.current_world_data.level_data.size() > i:
				buttons[i].level_to_load = Globals.current_world_data.level_data[i]
				buttons[i].set_button_text(str(current_world_idx+1) + "-" + str(i+1))
				var level_path = Globals.current_world_data.level_data[i].resource_path
				buttons[i].set_button_score(SaveGame.get_level_score(level_path))
				if SaveGame.is_level_unlocked(level_path) == false:
					buttons[i].disabled = true
			else:
				buttons[i].visible = false
