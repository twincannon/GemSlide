extends Button
class_name LevelButton

@export var level_to_load:PackedScene

func _on_pressed():
	if !level_to_load:
		return
	Globals.current_level_scene = level_to_load
	get_tree().change_scene_to_file("res://scenes/game.tscn")
