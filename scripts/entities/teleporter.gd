extends Entity
class_name Teleporter

var teleport_vfx_scene = preload("res://scenes/vfx/vfx_teleport.tscn")

func _ready():
	moves = false

func _initialize_entity():
	var other_teleporter = find_next_teleporter()
	if other_teleporter:
		$Arrow.look_at(other_teleporter.global_position)

func _does_block(_other_entity):
	return false

func find_next_teleporter():
	# Try to find a teleporter with a matching id
	for e in Globals.get_game_node().entities:
		if e is Teleporter and e != self and e.entity_id == entity_id:
			return e
	
	# Else, try to find a teleporter with an id of one higher than ours
	for e in Globals.get_game_node().entities:
		if e is Teleporter and e != self and e.entity_id == entity_id + 1:
			return e
	
	# Else, find the teleporter with the lowest id
	var lowest_tele = null
	for e in Globals.get_game_node().entities:
		if e is Teleporter and e != self:
			if lowest_tele == null or e.entity_id < lowest_tele.entity_id:
				lowest_tele = e
	return lowest_tele

func _on_entity_finished_entering(_other_entity):
	var other_teleporter = find_next_teleporter()
	
	if !other_teleporter:
		printerr("Failed to find destination teleporter")
		return
	
	for e in Globals.get_game_node().get_entities_at_pos(other_teleporter.grid_pos):
		if !(e is Teleporter):
			e.teleport_to(grid_pos)
	
	var vfx = teleport_vfx_scene.instantiate()
	add_child(vfx)
	vfx = teleport_vfx_scene.instantiate()
	other_teleporter.add_child(vfx)

	$Audio.play()
	
	_other_entity.teleport_to(other_teleporter.grid_pos)
