extends Node2D
class_name Entity

var movement_tween : Tween
var blocked_tween : Tween

var movement_tween_duration := 0.25
var movement_tween_queue_time := 0.2

var queue_free_timer_length = 1.0

var grid_pos:Vector2i : set = set_grid_pos # Position on game grid
var old_grid_pos:Vector2i
@onready var distance_to_move := Globals.get_entity_movement_distance() # I want this to be const

var queued_teleport_pos:Vector2i = Vector2i(-1,-1)

var entity_sprite:Sprite2D # Sprite for moving, rotating intended to be at 0,0 with 0 rotation by default
var entity_id := 0
var entity_type:int #enum EntityType

var moving := false

var pending_move_dir:Vector2i = Vector2i(0,0)

var moves := false # If this entity moves when input is pressed
var forces_movement := false # For ice slicks etc.
var grid_pos_prior_to_forced_movement:Vector2i = Vector2i(-1,-1)
var is_forcibly_moving := false
var stuck := false

signal on_movement_done
signal on_entity_pre_move(entity:Entity, dir:Vector2i)

func _initialize_entity(_game:Game):
	# Called after all entiites have been added and had their ready() called
	pass

func set_grid_pos(new_pos:Vector2i):
	grid_pos = new_pos

func _entity_pre_move(dir:Vector2i):
	on_entity_pre_move.emit(self, dir)

func _entity_post_all_movement():
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
	var in_bounds = game_node.is_in_grid_bounds(grid_pos + dir)
	if !in_bounds: return false
	var neighbors = game_node.get_entities_blocking_at_pos(grid_pos + dir, self)
	if neighbors.size() <= 0: return true
	elif neighbors.size() >= 1:
		return false
		var can_all_neighbors_move = true
		for i in neighbors:
			if i.can_move_in_dir(dir, ignore_stuck) == false:
				can_all_neighbors_move = false
			# Prevent forced movers from sliding into a neighbour that won’t get out of the way.
			#if is_forcibly_moving and !i.is_forcibly_moving:
				#var neighbour_will_vacate:bool = i.pending_move_dir == dir and i.can_move_in_dir(dir, ignore_stuck)
				#if !neighbour_will_vacate:
					#can_all_neighbors_move = false
				## If the neighbour has no planned move, it cannot be assumed to vacate the tile
				#if i.pending_move_dir == Vector2i.ZERO:
					#can_all_neighbors_move = false
		return can_all_neighbors_move
	return false


func on_try_move(dir): # Returns whether or not the move was successful
	var tried_to_move := false
	if can_move_in_dir(dir):
		#print(str(self) + " -> " + str(dir.x)+","+str(dir.y))
		var game_node = Globals.get_game_node()
		for e in game_node.get_entities_at_pos(grid_pos):
			e._on_entity_exited(self)
			if e.forces_movement:
				var move_map = collect_forced_movement_chain(dir)
				for entity in move_map.keys():
					var final_pos = move_map[entity]
					#entity.move_to_with_tween(final_pos)
					grid_pos = final_pos
					return true
			else:
				grid_pos += dir
		#grid_pos += dir
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

func try_recursively_move_entities_in_dir(dir):
	for e in Globals.get_game_node().get_entities_at_pos(grid_pos + dir):
		if e.moves and e.can_move_in_dir(dir):
			e.on_try_move(dir)
			e.try_recursively_move_entities_in_dir(dir)
	for e in Globals.get_game_node().get_entities_blocking_at_pos(grid_pos + dir, self):
		e.on_try_move(dir)

func collect_forced_movement_chain(dir: Vector2i, visited = null) -> Dictionary:
	if visited == null:
		visited = {}
	if self in visited:
		return visited
	visited[self] = grid_pos
	var next_pos = grid_pos + dir
	var game_node = Globals.get_game_node()
	for e in game_node.get_entities_at_pos(next_pos):
		if e.forces_movement:
			e.collect_forced_movement_chain(dir, visited)
	return visited

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
		if on_try_move(dir):
			moving = true
		else:
			is_forcibly_moving = false
	if !moving:
		on_movement_done.emit(self)

func _on_activated():
	# Called when an associated pressure plate is pressed
	pass

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

func get_properties() -> Dictionary:
	var dict = {"moves":moves, "stuck":stuck}
	return dict

func apply_properties(properties:Dictionary):
	if properties.has("moves"):
		moves = properties["moves"]
	if properties.has("stuck"):
		stuck = properties["stuck"]

func start_free_timer():
	#if needed, add an "is dead" var here so we know the entity is headed for the dumpster
	get_tree().create_timer(queue_free_timer_length).timeout.connect(_on_free_timer_done.bind())

func _on_free_timer_done():
	queue_free()
	Globals.get_game_node().check_goal()
	
func push_entity_recursively(entity: Entity, direction: Vector2i):
	# Check if there are entities blocking the path in the direction we're pushing
	var target_pos = entity.grid_pos + direction
	var blocking_entities = Globals.get_game_node().get_entities_blocking_at_pos(target_pos, entity)
	
	# First, recursively push any blocking entities
	for blocking_entity in blocking_entities:
		if blocking_entity.moves:
			push_entity_recursively(blocking_entity, direction)
	
	# Now try to move the original entity
	if entity.on_try_move(direction):
		# The entity moved successfully
		pass
