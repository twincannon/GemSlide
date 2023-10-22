extends Entity
class_name BlackGem

func _ready():
	entity_sprite = %GemSprite
	moves = true

func _does_block(_other_entity):
	return true

func _on_movement(_dir):
	movement_tween = create_tween().set_parallel(true)
	movement_tween.tween_property(self, "position", target_position, movement_tween_duration)
	var rot_dir = 1.5 if (_dir == Vector2i.RIGHT or _dir == Vector2i.DOWN) else -1.5
	movement_tween.tween_property(%GemSpriteRotAnchor, "rotation", rot_dir, movement_tween_duration).as_relative()
	movement_tween.tween_callback(_on_tween_done)
