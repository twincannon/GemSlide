extends Entity
class_name Gem




#@onready var floating_text_scene = preload("res://scenes/floating_text.tscn")

func _ready():
	entity_sprite = %GemSprite
	moves = true
	blocks = true
	movement_tween_duration = 0.25
	movement_tween_queue_time = 0.2


func _process(_delta):
	$Control/LabelGridPos.text = str(grid_pos.x, ",", grid_pos.y)

func on_movement():
	movement_tween = create_tween().set_parallel(true)
	#movement_tween.set_ease(Tween.EASE_OUT)
	#movement_tween.set_trans(Tween.TRANS_ELASTIC)
	movement_tween.tween_property(self, "position", target_position, movement_tween_duration)
	movement_tween.tween_property(%GemSpriteRotAnchor, "rotation", 0.9, movement_tween_duration).as_relative()
	movement_tween.tween_callback(on_tween_done)

func on_tween_done():
	for i in Globals.get_game_node().get_entities_at_pos(grid_pos):
		if i is Goal:
			if $ColorComponent.color == i.get_node("ColorComponent").color:
				on_goal_entered(i)

func on_goal_entered(goal):
	moves = false
	blocks = false
	entity_sprite.z_index -= 2
	var goal_tween = create_tween().set_parallel(true)
	goal_tween.tween_property(entity_sprite, "scale", Vector2(0.75, 0.75), 1.0)
	goal_tween.tween_property(entity_sprite, "modulate", entity_sprite.modulate * 0.5, 1.0)
	goal.on_goal_filled(self)

func on_movement_blocked(_dir):
	reset_sprite_position()
	# Check for neighbor and play a failed to move animation
	var any_blocking_ents = Globals.get_game_node().get_entities_blocking_at_pos(grid_pos + _dir, self).size() > 0
	if any_blocking_ents:
		if blocked_tween:
			blocked_tween.kill()
			blocked_tween = null
		var tween_dur = 0.05
		var rot_dir = 0.5 if (_dir == Vector2i.RIGHT or _dir == Vector2i.DOWN) else -0.5
		blocked_tween = create_tween().set_parallel(true)
		blocked_tween.tween_property($BlockedAnchor, "position", Vector2(_dir.x, _dir.y) * distance_to_move * 0.25, tween_dur).as_relative()
		blocked_tween.tween_property($BlockedAnchor, "rotation", rot_dir, tween_dur).as_relative()
		blocked_tween.chain().tween_property($BlockedAnchor, "position", Vector2(-_dir.x, -_dir.y) * distance_to_move * 0.25, tween_dur).as_relative()
		blocked_tween.tween_property($BlockedAnchor, "rotation", -rot_dir, tween_dur).as_relative()
		blocked_tween.chain().tween_callback(reset_sprite_position)

func reset_sprite_position():
	$BlockedAnchor.position = Vector2(0,0)
	$BlockedAnchor.rotation = 0

#func on_number_squished():
#	$GemSprite.z_index += 1
#	death_tween = create_tween().set_parallel(true)
#	death_tween.set_ease(Tween.EASE_OUT)
#	death_tween.set_trans(Tween.TRANS_CUBIC)
#	death_tween.tween_property(self, "scale", Vector2(0.1,0.1), 0.5)
#	death_tween.tween_property(self, "rotation", PI, 0.5)
#	death_tween.chain().tween_callback(queue_free)


