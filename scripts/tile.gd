extends Node2D

var grass_alt_texture = preload("res://assets/art/grass2.png")

func _ready():
	$Grass.visible = randi_range(0,2) > 1
	$Grass.flip_h = randi_range(0,1) > 0
	if randi() % 2 == 0:
		$Grass.texture = grass_alt_texture
	var mat = $Grass.material as ShaderMaterial
	mat.set_shader_parameter("offset", randf_range(-1,1))
	mat.set_shader_parameter("speed", randf_range(1,3))

func on_entity_spawned_on_tile():
	$Grass.visible = false
