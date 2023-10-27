extends Entity
class_name WaterHazard

@onready var timer := $Timer

func _ready():
	moves = false

func _does_block(_other_entity):
	return false
	
func _on_entity_entered(_other_entity):
	_other_entity.moves = false
	Globals.get_game_node().remove_entity(_other_entity)
	$Audio.play()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(_other_entity, "modulate:a", 0.0, 1.0)
	tween.tween_property(_other_entity, "scale", Vector2(-0.5, -0.5), 1.0).as_relative()
	
	for e in Globals.get_game_node().entities:
		var water = e as WaterHazard
		if water:
			water.timer.stop()
	timer.start()

func _on_timer_timeout():
	Globals.get_game_node().check_goal()
