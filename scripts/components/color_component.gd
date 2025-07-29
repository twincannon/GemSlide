extends Node2D
class_name ColorComponent

#@export var color:Color = Color(1,1,1) : set = set_color
var hue:float = 0.0 : set = set_hue
@export var nodes_to_colorize:Array[Sprite2D]

func set_hue(new_hue):
	hue = new_hue
	for node in nodes_to_colorize:
		if node and node.material:
			node.material.set_shader_parameter("hue_shift", hue)
