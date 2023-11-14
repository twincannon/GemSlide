extends Node2D
class_name Entity

var movement_tween : Tween
var blocked_tween : Tween

var movement_tween_duration := 0.25
var movement_tween_queue_time := 0.2

var grid_pos:Vector2i : set = set_grid_pos # Position on game grid
@onready var distance_to_move := Globals.get_entity_movement_distance() # I want this to be const

var queued_teleport_pos:Vector2i = Vector2i(-1,-1)

var entity_sprite:Sprite2D # Sprite for moving, rotating intended to be at 0,0 with 0 rotation by default
var entity_id := 0

var moving := false

var moves := false # If this entity moves when input is pressed
var is_forcibly_moving := false
var stuck := false

signal on_movement_done
signal on_entity_pre_move(entity:Entity, dir:Vector2i)

func _initialize_entity():
	# Called after all entiites have been added and had their ready() called
	pass

func set_grid_pos(new_pos:Vector2i):
	grid_pos = new_pos

func _entity_pre_move(dir:Vector2i):
	on_entity_pre_move.emit(self, dir)

func _entity_post_move():
	if queued_teleport_pos != Vector2i(-1,-1):
		for e in Globals.get_game_node().get_entities_at_pos(queued_teleport_pos):
			if !(e is Teleporter):
				e.teleport_to(grid_pos)
	
		teleport_to(queued_teleport_pos)
		
		queued_teleport_pos = Vector2i(-1,-1)


func can_move_in_dir(dir:Vector2i, ignore_stuck = false) -> bool:
	var game_node := Globals.get_game_node() as Game
	if !game_node: return false # Sanity check: entities should only exist with a valid game scene
	if !moves: return false
	if stuck and !ignore_stuck: return false
	var neighbors = game_node.get_entities_blocking_at_pos(grid_pos + dir, self)
	var in_bounds = game_node.is_in_grid_bounds(grid_pos + dir)
	if !in_bounds: return false
	elif neighbors.size() <= 0: return true
	elif neighbors.size() >= 1:
		var can_all_neighbors_move = true
		for i in neighbors:
			if i.can_move_in_dir(dir, ignore_stuck) == false:
				can_all_neighbors_move = false
			if is_forcibly_moving and !i.is_forcibly_moving: # We're forcibly moving but our neighbor isn't and won't move out of the way for us
				can_all_neighbors_move = false
		return can_all_neighbors_move
	return false


func on_try_move(dir): # Returns whether or not the move was successful
	var tried_to_move := false
	if can_move_in_dir(dir):
		#print(str(self) + " -> " + str(dir.x)+","+str(dir.y))
		var game_node = Globals.get_game_node()
		for e in game_node.get_entities_at_pos(grid_pos):
			e._on_entity_exited(self)
		grid_pos += dir
		for e in game_node.get_entities_at_pos(grid_pos):
			e._on_entity_entered(self)
		if movement_tween:
			movement_tween.kill()
			movement_tween = null
		_on_movement(dir)
		if !movement_tween: # If our movement call didn't start a tween, just teleport
			_on_movement_tween_done(dir)
		tried_to_move = true
	elif moves:
		_on_movement_blocked(dir)
	return tried_to_move

func _should_increment_moves(dir):
	return stuck and moves and can_move_in_dir(dir, true)# Should take into account "can ever un-stuck" somehow. Basically this is hardcoded for sandtraps atm

func _on_movement(_dir):
	moving = true
	# Do move tween here, make sure to call _on_movement_tween_done via tween callback!
	
	#does this make sense? I kind of hate inheritance for this
	#I could store the tween as a var and use it to circumvent the above gotcha too
	#var tween_comp = get_node("TweenComponent")
	pass

func _on_movement_blocked(_dir):
	# Do blocked movement tween here
	pass
	
func _on_entity_exited(_other_entity):
	pass
	
func _on_entity_entered(_other_entity):
	pass

func _on_entity_finished_entering(_other_entity):
	pass

func _on_entity_finished_exiting(_other_entity):
	pass
	
func _does_block(_other_entity):
	return true

func _on_movement_tween_done(dir):
	moving = false
	teleport_to(grid_pos)
	for e in Globals.get_game_node().get_entities_at_pos(grid_pos - dir):
		e._on_entity_finished_exiting(self)
	for e in Globals.get_game_node().get_entities_at_pos(grid_pos):
		e._on_entity_finished_entering(self)
	if is_forcibly_moving:
		if !on_try_move(dir):
			is_forcibly_moving = false
	if !is_forcibly_moving:
		on_movement_done.emit(self)
			
func queue_teleport_to(pos:Vector2i):
	queued_teleport_pos = pos

func fake_teleport_to(pos:Vector2i):
	position = Globals.get_game_node().get_position_at_grid_pos(pos)

func teleport_to(pos:Vector2i):
	if movement_tween and movement_tween.is_valid():
		movement_tween.stop()
		movement_tween = null
	grid_pos = pos
	position = Globals.get_game_node().get_position_at_grid_pos(pos)

func is_tween_running():
	return movement_tween is Tween and movement_tween.is_running()

func is_ready_for_queued_move():
	if is_forcibly_moving:
		return false
	if !movement_tween:
		return true
	elif is_tween_running() == false:
		return true
	if get_remaining_movement_time() < movement_tween_queue_time:
		return true
	return false

func get_remaining_movement_time():
	return movement_tween_duration - movement_tween.get_total_elapsed_time() if movement_tween is Tween else 0.0

func reset_sprite_position():
	if entity_sprite:
		entity_sprite.position = Vector2(0,0)
		entity_sprite.rotation = 0

