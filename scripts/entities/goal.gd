extends Entity
class_name Goal

var filled = false
var filled_tex = preload("res://assets/art/goal_filled.png")

func _ready():
	moves = false
	entity_sprite = $GoalSprite

func on_goal_filled(_filling_gem):
	filled = true
	Globals.get_game_node().on_goal_filled(self)
	await get_tree().create_timer(_filling_gem.goal_tween_duration).timeout
	entity_sprite.texture = filled_tex

func is_goal_filled():
	return filled

func _does_block(_other_entity):
	if filled: return false # Filled goals no longer block other gems
	if _other_entity and _other_entity is Gem:
		var other_ent_color_comp = _other_entity.get_node("ColorComponent")
		if other_ent_color_comp and $ColorComponent.color == other_ent_color_comp.color:
			return false
	return true

