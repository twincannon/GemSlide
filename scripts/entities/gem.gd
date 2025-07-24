extends Entity
class_name Gem


var gem_in_goal := false
var gem_goal_anim_done := false
signal on_goal_animation_finished

var goal_tween:Tween
var goal_tween_duration := 1.0

var gem_rotates = true

#@onready var floating_text_scene = preload("res://scenes/floating_text.tscn")

func _ready():
	entity_sprite = %GemSprite
	moves = true
	%GemSpriteRotAnchor.rotation = randf_range(-PI, PI)
	add_to_group("gems") #is this used?

func _initialize_entity(game:Game):
	connect("on_goal_animation_finished", game.on_gem_goal_anim_finished.bind())
	
func _process(_delta):
	$Control/LabelGridPos.text = str(grid_pos.x, ",", grid_pos.y)

func _on_movement(_dir):
	super(_dir)
	if movement_tween:
		movement_tween.stop()
		movement_tween.kill()
	
	movement_tween = create_tween().set_parallel(true)
	#movement_tween.set_ease(Tween.EASE_OUT)
	#movement_tween.set_trans(Tween.TRANS_ELASTIC)
	var offset = (Vector2(_dir.x, _dir.y) * distance_to_move)
	
	var tween_dur = movement_tween_duration

	movement_tween.tween_property(self, "position", offset, tween_dur).as_relative()
	var rot_dir = 1.5 if (_dir == Vector2i.RIGHT or _dir == Vector2i.DOWN) else -1.5
	if gem_rotates:
		movement_tween.tween_property(%GemSpriteRotAnchor, "rotation", rot_dir, tween_dur).as_relative()
	movement_tween.chain().tween_callback(_on_movement_tween_done.bind(_dir))
	
	#movement_tween.finished.connect(_on_movement_tween_done.bind(_dir))
	#get_tree().create_timer(movement_tween_duration).timeout.connect(_on_movement_tween_done.bind(_dir))

func _on_movement_tween_done(dir):
	if gem_in_goal:
		#if !goal_tween or goal_tween.is_running() == false: # I've encountered a bug where the goal fills twice
		goal_tween = create_tween().set_parallel(true)
		goal_tween.set_trans(Tween.TRANS_ELASTIC)
		goal_tween.set_ease(Tween.EASE_OUT)
		goal_tween.tween_property(entity_sprite, "scale", entity_sprite.scale * 0.66, goal_tween_duration)
		goal_tween.tween_property(entity_sprite, "modulate:r", entity_sprite.modulate.r * 0.5, goal_tween_duration)
		goal_tween.tween_property(entity_sprite, "modulate:g", entity_sprite.modulate.g * 0.5, goal_tween_duration)
		goal_tween.tween_property(entity_sprite, "modulate:b", entity_sprite.modulate.b * 0.5, goal_tween_duration)
		goal_tween.tween_property(entity_sprite, "z_index", -10, goal_tween_duration).as_relative()
		goal_tween.chain().tween_callback(goal_animation_finished)
	super(dir)
	
func on_goal_entered(_goal):
	moves = false
	gem_in_goal = true
	%ShadowSprite.visible = false

func goal_animation_finished():
	goal_tween.stop() # Ensure our Tween doesn't report as running this frame
	gem_goal_anim_done = true
	on_goal_animation_finished.emit()

func is_gem_goal_anim_done():
	return gem_goal_anim_done
	#if gem_in_goal:
	#	if !goal_tween or goal_tween.is_valid() == false or goal_tween.is_running() == false:
	#		return true
	#return false
	
func _on_movement_blocked(_dir):
	if blocked_tween and blocked_tween.is_running():
		return
	
	reset_blocked_anchor_position()
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
		blocked_tween.chain().tween_callback(reset_blocked_anchor_position)

func _does_block(_other_entity):
	return !gem_in_goal

func reset_blocked_anchor_position():
	$BlockedAnchor.position = Vector2(0,0)
	$BlockedAnchor.rotation = 0

func get_properties() -> Dictionary:
	var dict = super()
	dict["gem_in_goal"] = gem_in_goal
	return dict

func apply_properties(properties:Dictionary):
	super(properties)
	if properties.has("gem_in_goal"):
		gem_in_goal = properties["gem_in_goal"]
	if gem_in_goal:
		gem_goal_anim_done = true
		entity_sprite.scale *= 0.66
		entity_sprite.modulate.r *= 0.5
		entity_sprite.modulate.g *= 0.5
		entity_sprite.modulate.b *= 0.5
		entity_sprite.z_index -= 10

#func on_number_squished():
#	$GemSprite.z_index += 1
#	death_tween = create_tween().set_parallel(true)
#	death_tween.set_ease(Tween.EASE_OUT)
#	death_tween.set_trans(Tween.TRANS_CUBIC)
#	death_tween.tween_property(self, "scale", Vector2(0.1,0.1), 0.5)
#	death_tween.tween_property(self, "rotation", PI, 0.5)
#	death_tween.chain().tween_callback(queue_free)
