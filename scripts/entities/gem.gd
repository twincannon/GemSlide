extends Entity
class_name Gem

var gem_in_goal := false
var gem_goal_anim_done := false
signal on_gem_entered_goal
signal on_goal_animation_finished

var goal_tween:Tween
var goal_tween_duration := 1.0

var gem_rotates := true
var gem_squishes := false
var gem_bounces := true
var gem_sinks_in_goal := true

static var move_sounds_default = [preload("res://assets/audio/putt1.wav"), preload("res://assets/audio/putt3.wav")] # Removed preload("res://assets/audio/putt2.wav"), for now due to extra bass in it
static var move_sound_cat = preload("res://assets/audio/move_meow.wav")
static var move_sound_bowling = preload("res://assets/audio/move_bowling.wav")

static var ball_cat_texture = preload("res://assets/art/golfball_cat.png")
static var ball_bowling_texture = preload("res://assets/art/bowlingball.png")

var celebrating := false

func _ready():
	entity_sprite = %GemSprite
	moves = true
	
	match SaveGame.selected_skin:
		SkinManager.SkinType.DEFAULT: pass
		SkinManager.SkinType.CAT:
			entity_sprite.texture = ball_cat_texture
			gem_rotates = false
			gem_squishes = true
			gem_bounces = true
			gem_sinks_in_goal = true
		SkinManager.SkinType.BOWLINGBALL:
			entity_sprite.texture = ball_bowling_texture
			gem_rotates = true
			gem_squishes = false
			gem_bounces = false
			gem_sinks_in_goal = false
	
	if gem_rotates:
		%GemSpriteRotAnchor.rotation = randf_range(-PI, PI)
	add_to_group("gems") #id
	
func _initialize_entity(game:Game):
	connect("on_goal_animation_finished", game.on_gem_goal_anim_finished.bind())

func get_move_sound() -> Resource:
	match SaveGame.selected_skin:
		SkinManager.SkinType.DEFAULT:
			return move_sounds_default[randi() % move_sounds_default.size()]
		SkinManager.SkinType.CAT:
			return move_sound_cat
		SkinManager.SkinType.BOWLINGBALL:
			return move_sound_bowling
	return null

#func _process(_delta):
	#$Control/LabelGridPos.text = str(grid_pos.x, ",", grid_pos.y)

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
	
	if gem_bounces:
		var bounce_tween = create_tween()
		bounce_tween.set_trans(Tween.TRANS_SINE)
		bounce_tween.set_ease(Tween.EASE_OUT)
		bounce_tween.tween_property(%GemSpriteRotAnchor, "position:y", -25, tween_dur * 0.5).as_relative()
		bounce_tween.set_ease(Tween.EASE_IN)
		bounce_tween.tween_property(%GemSpriteRotAnchor, "position:y", 25, tween_dur * 0.5).as_relative()
	
	if gem_squishes:
		var squish_tween = create_tween()
		squish_tween.tween_property(%GemSpriteRotAnchor, "scale:y", -0.15, tween_dur * 0.5).as_relative()
		squish_tween.tween_property(%GemSpriteRotAnchor, "scale:y", 0.15, tween_dur * 0.5).as_relative()
	#movement_tween.finished.connect(_on_movement_tween_done.bind(_dir))
	#get_tree().create_timer(movement_tween_duration).timeout.connect(_on_movement_tween_done.bind(_dir))

func _on_movement_tween_done(dir):
	if gem_in_goal:
		#if !goal_tween or goal_tween.is_running() == false: # I've encountered a bug where the goal fills twice
		goal_tween = create_tween().set_parallel(true)
		if !celebrating and gem_sinks_in_goal:
			goal_tween.set_trans(Tween.TRANS_ELASTIC)
			goal_tween.set_ease(Tween.EASE_OUT)
		if gem_sinks_in_goal:
			goal_tween.tween_property(entity_sprite, "scale", entity_sprite.scale * 0.66, goal_tween_duration)
		if !celebrating:
			#goal_tween.tween_property(entity_sprite, "modulate:r", entity_sprite.modulate.r * 0.5, goal_tween_duration)
			#goal_tween.tween_property(entity_sprite, "modulate:g", entity_sprite.modulate.g * 0.5, goal_tween_duration)
			#goal_tween.tween_property(entity_sprite, "modulate:b", entity_sprite.modulate.b * 0.5, goal_tween_duration)
			goal_tween.tween_method(set_gem_color_scale, 1.0, 0.5, goal_tween_duration)
		goal_tween.tween_property(entity_sprite, "z_index", -10, goal_tween_duration).as_relative()
		goal_tween.tween_property(%ShadowSprite, "z_index", -10, goal_tween_duration).as_relative()
		goal_tween.chain().tween_callback(goal_animation_finished)
	super(dir)

func set_gem_color_scale(value:float): #Modulate also works with updated shader
	entity_sprite.material.set_shader_parameter("color_scale", value)

func on_goal_entered(_goal):
	moves = false
	gem_in_goal = true
	
	if gem_sinks_in_goal:
		var shadow_tween = create_tween()
		shadow_tween.tween_property(%ShadowSprite, "modulate:a", 0.0, 0.33)
	
	on_gem_entered_goal.emit(self)

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
		blocked_tween.tween_property(%GemSpriteRotAnchor, "rotation", rot_dir, tween_dur).as_relative()
		blocked_tween.chain().tween_property($BlockedAnchor, "position", Vector2(-_dir.x, -_dir.y) * distance_to_move * 0.25, tween_dur).as_relative()
		blocked_tween.tween_property(%GemSpriteRotAnchor, "rotation", -rot_dir, tween_dur).as_relative()
		blocked_tween.chain().tween_callback(reset_blocked_anchor_position)

func _does_block(_other_entity):
	return !gem_in_goal

func reset_blocked_anchor_position():
	$BlockedAnchor.position = Vector2(0,0)
	$BlockedAnchor.rotation = 0

func do_goal_celebration():
	get_tree().create_timer(movement_tween_duration).timeout.connect(do_celebration_anim.bind())
	celebrating = true

func do_celebration_anim():
	var bounce_tween = create_tween().set_loops(99999)
	bounce_tween.set_trans(Tween.TRANS_SINE)
	bounce_tween.set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(%GemSpriteRotAnchor, "position:y", -25, 0.25).as_relative()
	bounce_tween.set_ease(Tween.EASE_IN)
	bounce_tween.tween_property(%GemSpriteRotAnchor, "position:y", 25, 0.25).as_relative()

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
		set_gem_color_scale(0.5)
		entity_sprite.z_index -= 10
		%ShadowSprite.z_index -= 10
		if gem_sinks_in_goal:
			entity_sprite.scale *= 0.66
			%ShadowSprite.visible = false

#func on_number_squished():
#	$GemSprite.z_index += 1
#	death_tween = create_tween().set_parallel(true)
#	death_tween.set_ease(Tween.EASE_OUT)
#	death_tween.set_trans(Tween.TRANS_CUBIC)
#	death_tween.tween_property(self, "scale", Vector2(0.1,0.1), 0.5)
#	death_tween.tween_property(self, "rotation", PI, 0.5)
#	death_tween.chain().tween_callback(queue_free)
