extends Entity
class_name Teleporter

var teleport_vfx_scene = preload("res://scenes/vfx/vfx_teleport.tscn")

func _ready():
	moves = false

func _initialize_entity(_game:Game):
	var other_teleporter = find_next_teleporter()
	if other_teleporter:
		$Arrow.look_at(other_teleporter.global_position)
	# Code for disabling the teleporter if a button is present?

func _does_block(_other_entity):
	return false

func find_next_teleporter() -> Teleporter:
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

#_on_entity_entered works here so we just need to do the queued teleport after this
func _on_entity_finished_entering(_other_entity):
	var other_teleporter:Teleporter = find_next_teleporter()
	
	if !other_teleporter:
		printerr("Failed to find destination teleporter")
		return
	
	add_teleport_vfx()
	other_teleporter.add_teleport_vfx()
	
	Globals.get_game_node().on_teleport()
	
	# We do a fake teleport here as well as the real one (which is queued) in _entity_post_all_movement so that we can visibly instantly teleport when delayed by ice movement etc.
	_other_entity.fake_teleport_to(other_teleporter.grid_pos)
	
	_other_entity.queue_teleport_to(other_teleporter.grid_pos)

func add_teleport_vfx():
	var game_node = Globals.get_game_node()
	var vfx = teleport_vfx_scene.instantiate()
	vfx.process_material.set("scale", game_node.get_grid_scale())
	add_child(vfx)
