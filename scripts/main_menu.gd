extends Control

@export var world_datas:Array[WorldData] = []
var current_world

@onready var level_button_scene = preload("res://scenes/level_editor/level_button.tscn")

func _ready():
	if Globals.world_data:
		current_world = Globals.world_data #if we're coming from a level, use that world
	elif world_datas.size() > 0:
		current_world = world_datas[0]
		Globals.world_data = world_datas[0]
	var current_world_idx = world_datas.find(current_world)
	
	# Clear anything in our level container
	for i in %LevelContainer.get_children():
		i.queue_free()
	
	# Add buttons to level container for each level
	for i in current_world.level_data:
		%LevelContainer.add_child(level_button_scene.instantiate())
	
	var buttons = %LevelContainer.get_children()
	for i in range(buttons.size()):
		if buttons[i] is LevelButton:
			if Globals.world_data.level_data.size() > i:
				buttons[i].level_to_load = Globals.world_data.level_data[i]
				buttons[i].text = str(current_world_idx+1) + "-" + str(i+1)
			else:
				buttons[i].visible = false
