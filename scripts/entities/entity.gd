extends Node2D
class_name Entity

var movement_tween : Tween
var blocked_tween : Tween

var movement_tween_duration := 0.5
var movement_tween_queue_time := 0.35

var grid_pos:Vector2i # Position on game grid
@onready var target_position:Vector2 = position # Position in 2D space on screen
@onready var distance_to_move := Globals.get_entity_movement_distance() # I want this to be const

var entity_sprite:Sprite2D # Sprite for moving, rotating intended to be at 0,0 with 0 rotation by default

var moves := false # If this entity moves when input is pressed
var blocks := true


func set_grid_pos(new_pos:Vector2i):
	grid_pos = new_pos


func can_move_in_dir(dir:Vector2i) -> bool:
	var game_node = Globals.get_game_node()
	if !game_node: return false # Sanity check: entities should only exist with a valid game scene
	if !moves: return false
	var neighbors = game_node.get_entities_blocking_at_pos(grid_pos + dir, self)
	var in_bounds = game_node.is_in_grid_bounds(grid_pos + dir)
	if !in_bounds: return false
	elif neighbors.size() <= 0: return true
	elif neighbors.size() >= 1:
		var can_all_neighbors_move = true
		for i in neighbors:
			if i.can_move_in_dir(dir) == false:
				can_all_neighbors_move = false
		return can_all_neighbors_move
	return false


func on_try_move(dir):
	if can_move_in_dir(dir):
		grid_pos += dir
		if movement_tween:
			movement_tween.kill()
			movement_tween = null
		target_position = position + (Vector2(dir.x, dir.y) * distance_to_move)
		on_movement()
		if !movement_tween: # If our movement call didn't start a tween, just teleport
			position = target_position
	elif moves:
		on_movement_blocked(dir)

func on_movement():
	# Do move tween here
	
	#does this make sense? I kind of hate inheritance for this
	#var tween_comp = get_node("TweenComponent")
	pass

func on_movement_blocked(_dir):
	# Do blocked movement tween here
	pass

func does_block(_other_entity):
	return blocks

func on_tween_done():
	pass

func is_tween_running():
	return movement_tween is Tween and movement_tween.is_running()


func is_ready_for_queued_move():
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

