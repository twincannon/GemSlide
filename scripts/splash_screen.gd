extends Node2D

func _ready():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")
