extends GridContainer
class_name LevelBase

@export var goal_sum = 0
@export_multiline var tutorial:String

func get_grid_size():
	if columns > 0:
		return Vector2i(columns, get_child_count() / columns)
	return Vector2i(0,0)

func get_entities():
	var entities = []
	for i in get_children():
		if i is EntityIconBase:
			entities.append(i.get_entity())
	return entities
