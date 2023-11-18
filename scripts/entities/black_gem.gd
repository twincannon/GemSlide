extends Entity
class_name BlackGem

func _ready():
	entity_sprite = %GemSprite
	moves = true
	%GemSpriteRotAnchor.rotation = randf_range(-PI, PI)
	
#func _process(_delta):
#	$Control/LabelGridPos.text = str(grid_pos.x, ",", grid_pos.y)

func _does_block(_other_entity):
	return true

func _on_movement(_dir):
	super(_dir)
	#This is copypasted from Gem... gross
	if movement_tween:
		movement_tween.stop()
		movement_tween.kill()
	movement_tween = create_tween().set_parallel(true)
	var offset = (Vector2(_dir.x, _dir.y) * distance_to_move)
	var coming_from_ice = false
	for e in Globals.get_game_node().get_entities_at_pos(grid_pos + -_dir):
		if e is IceSlick:
			coming_from_ice = true
	var tween_dur = movement_tween_duration if !is_forcibly_moving and !coming_from_ice else 0.1
	movement_tween.tween_property(self, "position", offset, tween_dur).as_relative()
	var rot_dir = 1.5 if (_dir == Vector2i.RIGHT or _dir == Vector2i.DOWN) else -1.5
	movement_tween.tween_property(%GemSpriteRotAnchor, "rotation", rot_dir, tween_dur).as_relative()
	movement_tween.chain().tween_callback(_on_movement_tween_done.bind(_dir))
