extends Entity
class_name Goal

var filled = false
var filled_vfx_scene = preload("res://scenes/vfx/vfx_goal.tscn")

func _ready():
	moves = false
	entity_sprite = $GoalSprite
	%FlagSprite.modulate = entity_sprite.modulate
	var flag_tween = create_tween()
	flag_tween.set_ease(Tween.EASE_IN_OUT)
	flag_tween.set_trans(Tween.TRANS_CUBIC)
	flag_tween.tween_property($FlagRot, "rotation", randf_range(-0.1, 0.1), randf_range(2.0, 4.0))
	flag_tween.tween_property($FlagRot, "rotation", randf_range(-0.1, 0.1), randf_range(2.0, 4.0))
	flag_tween.set_loops(9999)

func _on_entity_entered(_other_entity):
	if !is_goal_filled() and _other_entity is Gem:
		if $ColorComponent.color == _other_entity.get_node("ColorComponent").color:
			on_goal_filled(_other_entity)
			_other_entity.on_goal_entered(self)

func on_goal_filled(_filling_gem):
	filled = true
	%FlagSprite.visible = false
	Globals.get_game_node().on_goal_filled(self)
	var goal_tween = create_tween().set_parallel(true)
	var dur = 1.0
	goal_tween.tween_property(entity_sprite, "modulate:r", entity_sprite.modulate.r * 0.5, dur)
	goal_tween.tween_property(entity_sprite, "modulate:g", entity_sprite.modulate.g * 0.5, dur)
	goal_tween.tween_property(entity_sprite, "modulate:b", entity_sprite.modulate.b * 0.5, dur)
	
	var filled_vfx = filled_vfx_scene.instantiate() as GPUParticles2D
	add_child(filled_vfx)
	filled_vfx.process_material.color = $ColorComponent.color
	
	#await get_tree().create_timer(_filling_gem.goal_tween_duration).timeout
	#entity_sprite.texture = filled_tex

func is_goal_filled():
	return filled

func _does_block(_other_entity):
	if filled: return false # Filled goals no longer block other gems
	if _other_entity and _other_entity is Gem:
		var other_ent_color_comp = _other_entity.get_node("ColorComponent")
		if other_ent_color_comp and $ColorComponent.color == other_ent_color_comp.color:
			return false
	return true
