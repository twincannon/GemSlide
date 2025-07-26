extends Node2D

var frames := 0

#func _ready():
#	get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")

func _process(_delta):
	if frames >= 1:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")
	frames += 1
