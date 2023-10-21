extends Entity
class_name Goal

var filled = false

func _ready():
	moves = false
	blocks = false
	entity_sprite = $GoalSprite

func on_goal_filled(filling_gem):
	filled = true

func does_block(_other_entity):
	if filled: return false # Filled goals no longer block other gems
	if _other_entity:
		var other_ent_color_comp = _other_entity.get_node("ColorComponent")
		if $ColorComponent.color == other_ent_color_comp.color:
			return false
	return true

