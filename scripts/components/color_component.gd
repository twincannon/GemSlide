extends Node2D
class_name ColorComponent

@export var color:Color = Color(1,1,1)
@export var node_to_colorize:Sprite2D

func set_color(new_color):
	color = new_color
	if node_to_colorize:
		node_to_colorize.modulate = color
