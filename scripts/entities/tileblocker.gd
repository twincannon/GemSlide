extends Entity
class_name TileBlocker



# Called when the node enters the scene tree for the first time.
func _ready():
	moves = false
	entity_sprite = $TileSprite
	var mat = entity_sprite.material as ShaderMaterial
	mat.set_shader_parameter("offset", randf_range(-1,1))

func _does_block(_other_entity):
	return true
