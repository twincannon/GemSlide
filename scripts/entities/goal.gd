extends Entity
class_name Goal

var filled = false
var filled_vfx_scene = preload("res://scenes/vfx/vfx_goal.tscn")

func _ready():
	moves = false
	if SaveGame.selected_skin == "Bowling Ball":
		$SkinBowling.visible = true
		$SkinDefault.visible = false
		entity_sprite = $SkinBowling/GoalSpriteBowling
	else:
		entity_sprite = $SkinDefault/GoalSprite
		var flag_tween = create_tween()
		flag_tween.set_ease(Tween.EASE_IN_OUT)
		flag_tween.set_trans(Tween.TRANS_CUBIC)
		flag_tween.tween_property($SkinDefault/FlagRot, "rotation", randf_range(-0.1, 0.1), randf_range(2.0, 4.0))
		flag_tween.tween_property($SkinDefault/FlagRot, "rotation", randf_range(-0.1, 0.1), randf_range(2.0, 4.0))
		flag_tween.set_loops(9999)

func _on_entity_entered(_other_entity):
	if !is_goal_filled() and _other_entity is Gem:
		if $ColorComponent.hue == _other_entity.get_node("ColorComponent").hue:
			on_goal_filled(_other_entity)
			_other_entity.on_goal_entered(self)

func on_goal_filled(_filling_gem):
	filled = true
	#%FlagSprite.visible = false
	Globals.get_game_node().on_goal_filled(self)
	var goal_tween = create_tween().set_parallel(true)
	goal_tween.tween_method(set_goal_color_scale, 1.0, 0.5, 1.0)
	
	var flag_tween = create_tween().set_parallel(true)
	flag_tween.tween_property(%FlagSprite, "position:y", -200, 0.5)
	flag_tween.tween_property(%FlagSprite, "modulate:a", 0, 0.5)
	
	if $SkinBowling.visible:
		var bowling_tween = create_tween().set_parallel(true)
		bowling_tween.tween_property($SkinBowling/GoalSpriteBowling, "position:y", -100, 0.5)
		bowling_tween.tween_property($SkinBowling/GoalSpriteBowling, "modulate:a", 0, 0.5)
		var rot = randf_range(-PI, PI)
		bowling_tween.tween_property($SkinBowling/GoalSpriteBowling, "rotation", rot, 0.5)
		bowling_tween.tween_property($SkinBowling/GoalSpriteBowlingShadow, "modulate:a", 0, 0.5)
	
	var filled_vfx = filled_vfx_scene.instantiate() as GPUParticles2D
	add_child(filled_vfx)
	filled_vfx.material.set_shader_parameter("hue_shift", $ColorComponent.hue)
	#filled_vfx.process_material.color = $ColorComponent.color
	
	#await get_tree().create_timer(_filling_gem.goal_tween_duration).timeout
	#entity_sprite.texture = filled_tex

func set_goal_color_scale(value:float):
	entity_sprite.material.set_shader_parameter("color_scale", value)

func is_goal_filled():
	return filled

func _does_block(_other_entity):
	if filled: return false # Filled goals no longer block other gems
	if _other_entity and _other_entity is Gem:
		var other_ent_color_comp = _other_entity.get_node("ColorComponent")
		if other_ent_color_comp and $ColorComponent.hue == other_ent_color_comp.hue:
			return false
	return true

func get_properties() -> Dictionary:
	var dict = super()
	dict["filled"] = filled
	return dict

func apply_properties(properties:Dictionary):
	super(properties)
	if properties.has("filled"):
		filled = properties["filled"]
		if filled:
			%FlagSprite.modulate.a = 0.0
			$SkinBowling/GoalSpriteBowling.modulate.a = 0.0
			$SkinBowling/GoalSpriteBowlingShadow.modulate.a = 0.0
			entity_sprite.modulate.r *= 0.5
			entity_sprite.modulate.g *= 0.5
			entity_sprite.modulate.b *= 0.5
