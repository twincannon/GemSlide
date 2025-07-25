extends Entity
class_name SandTrap

var moves_to_escape := 0
var sand_vfx_scene = preload("res://scenes/vfx/vfx_sand.tscn")

func _ready():
	moves = false

func _does_block(_other_entity):
	return false
	
func _on_entity_entered(_other_entity):
	_other_entity.stuck = true
	_other_entity.on_entity_pre_move.connect(pre_move)
	moves_to_escape = 1
	$Audio.play()
	$Fill.visible = true
	var vfx = sand_vfx_scene.instantiate()
	add_child(vfx)
	
func pre_move(entity:Entity, dir:Vector2i):
	if entity.can_move_in_dir(dir, true):
		moves_to_escape -= 1
		if moves_to_escape <= 1:
			$Fill.visible = false
		if moves_to_escape <= 0:
			entity.stuck = false
			entity.on_entity_pre_move.disconnect(pre_move)

func get_properties() -> Dictionary:
	var dict = super()
	dict["moves_to_escape"] = moves_to_escape
	dict["fill_visible"] = $Fill.visible #Maybe this is unnecessary: if moves_to_escape is 0, the fill is not visible
	return dict

func apply_properties(properties:Dictionary):
	super(properties)
	if properties.has("moves_to_escape"):
		moves_to_escape = properties["moves_to_escape"]
	if properties.has("fill_visible"):
		$Fill.visible = properties["fill_visible"]

func reconnect_to_stuck_entities():
	# Find entities that are stuck and should be connected to this sand trap
	var game = Globals.get_game_node()
	if game:
		for entity in game.entities:
			if entity.stuck and entity.grid_pos == grid_pos:
				# Reconnect the signal
				if !entity.on_entity_pre_move.is_connected(pre_move):
					entity.on_entity_pre_move.connect(pre_move)
