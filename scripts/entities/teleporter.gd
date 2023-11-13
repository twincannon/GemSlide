extends Entity
class_name Teleporter

var teleport_vfx_scene = preload("res://scenes/vfx/vfx_teleport.tscn")

func _ready():
	moves = false

func _does_block(_other_entity):
	return false

func _on_entity_finished_entering(_other_entity):
	var other_teleporter = null
	
	# Try to find a teleporter with a matching id
	for e in Globals.get_game_node().entities:
		if e is Teleporter and e != self and e.entity_id == entity_id:
			other_teleporter = e
			break
	
	# Try to find a teleporter with an id of one higher than ours
	if !other_teleporter:
		for e in Globals.get_game_node().entities:
			if e is Teleporter and e != self and e.entity_id == entity_id + 1:
				other_teleporter = e
				break
	
	# Find the teleporter with the lowest id
	if !other_teleporter:
		var lowest_tele = null
		for e in Globals.get_game_node().entities:
			if e is Teleporter and e != self:
				if lowest_tele == null or e.entity_id < lowest_tele.entity_id:
					lowest_tele = e
		other_teleporter = lowest_tele
	
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
