extends Node2D
class_name Game

var tile_scene = preload("res://scenes/tile.tscn")
# instead of tile blockers, maybe just don't spawn tiles?

var tiles = []
var entities:Array[Entity] = []

var icon_size:Vector2

# For click and drag/touch controls
var pressedPos : Vector2
var releasedPos : Vector2
var threshold := 5000

var existing_queue_timer : SceneTreeTimer

#var game_paused = false

var input_dir:int = 0
enum input_dir_mask { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 }

func _ready():
	get_tree().get_root().size_changed.connect(on_viewport_changed.bind())
	on_viewport_changed()
	
	# can i queue_free this after im done with it?
	Globals.current_level = Globals.current_level_scene.instantiate() as LevelBase
	
	if Globals.current_level.tutorial.is_empty() == false:
		%TutorialContainer.visible = true
		%TutorialLabel.text = Globals.current_level.tutorial
		set_game_paused(true)
	
	var grid_size = Globals.current_level.get_grid_size()
	var entities_to_load = Globals.current_level.get_entities()
	var currentNum = 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var tile_instance = tile_scene.instantiate()
			$GridAnchor.add_child(tile_instance)
			var tilenode = tile_instance.get_node("TileSprite")
			var texsize
			if tilenode is Sprite2D and tilenode.texture:
				texsize = tilenode.texture.get_size() * tilenode.transform.get_scale()
				icon_size = texsize
				tile_instance.position.x = (texsize.x * x) - ((texsize.x * grid_size.x) / 2) + (texsize.x/2)
				tile_instance.position.y = (texsize.y * y) - ((texsize.y * grid_size.y) / 2) + (texsize.y/2)
				tiles.append(tile_instance)
				
				if currentNum < entities_to_load.size():
					var entity = entities_to_load[currentNum]
					if entity:
						$GridAnchor.add_child(entity)
						entity.position = tile_instance.position
						#entity.scale = tilenode.transform.get_scale() # do we want this?
						entity.set_grid_pos(Vector2i(x,y))
						entities.append(entity)
			currentNum += 1
	check_goal()

func on_viewport_changed():
	$GridAnchor.position = %GridPos.position

func set_game_paused(paused):
	get_tree().paused = paused

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var dir:Vector2i = Vector2i.ZERO
		
	if input_dir & input_dir_mask.UP:
		dir = Vector2i.UP
	elif input_dir & input_dir_mask.DOWN:
		dir = Vector2i.DOWN
	elif input_dir & input_dir_mask.LEFT:
		dir = Vector2i.LEFT
	elif input_dir & input_dir_mask.RIGHT:
		dir = Vector2i.RIGHT
		
	if dir != Vector2i.ZERO:
		var queued_move = false
		var queue_duration = 0.0
		for e in entities:
			if e.is_tween_running():
				queued_move = true
				if e.is_ready_for_queued_move():
					# HACK: 0.01 added to ensure entity on_tween_done() is called... can I solve this with callbacks somehow?
					queue_duration = max(queue_duration, e.get_remaining_movement_time() + 0.01)
		if !queued_move and !existing_queue_timer:
			move_entities(dir)
		elif !existing_queue_timer and queue_duration > 0.0 and Input.is_action_just_released("click"): # Only queue for swipe gestures for now
			existing_queue_timer = get_tree().create_timer(queue_duration)
			existing_queue_timer.timeout.connect(move_entities.bind(dir))
	
	if Input.is_action_just_released("click"):
		input_dir = 0


func _input(event):
	if event.is_action("click") and Input.is_action_just_pressed("click"):
		pressedPos = event.position
	if event.is_action("click") and Input.is_action_just_released("click"):
		releasedPos = event.position
		input_dir = calculate_gesture()
	
	if event.is_action_pressed("up"):
		input_dir |= input_dir_mask.UP
	elif event.is_action_released("up"):
		input_dir &= ~input_dir_mask.UP
	
	if event.is_action_pressed("down"):
		input_dir |= input_dir_mask.DOWN
	elif event.is_action_released("down"):
		input_dir &= ~input_dir_mask.DOWN
	
	if event.is_action_pressed("left"):
		input_dir |= input_dir_mask.LEFT
	elif event.is_action_released("left"):
		input_dir &= ~input_dir_mask.LEFT
	
	if event.is_action_pressed("right"):
		input_dir |= input_dir_mask.RIGHT
	elif event.is_action_released("right"):
		input_dir &= ~input_dir_mask.RIGHT
		

func move_entities(dir:Vector2i):
	existing_queue_timer = null
	#emit_signal("signal_on_move", dir)
	
	# Iterate forwards or backwards depending on our direction, probably a better way to do this?
	if dir == Vector2i.UP or dir == Vector2i.LEFT:
		for i in entities:
			i.on_try_move(dir)
	
	if dir == Vector2i.DOWN or dir == Vector2i.RIGHT:
		for i in range(entities.size() - 1, -1, -1):
			entities[i].on_try_move(dir)
	
	# Replace with gem logic
	#for i in gems: #i feel like this should be a reverse for loop, but it doesn't seem possible for multidimensional reverse loop?!
	#	for j in gems:
	#		if i != j and i.grid_pos == j.grid_pos:
	#			if !i.is_dying() and !j.is_dying():
	#				assert(i.number != j.number, "numbers are stacked and equal - shouldn't happen")
	#				if i.number > j.number:
	#					i.on_number_eaten(j)
	#					j.on_number_squished()
	#				else:
	#					j.on_number_eaten(i)
	#					i.on_number_squished()
	
	#check for zeroes
	#for i in numbers:
	#	if i.number == 0:
	#		i.on_number_squished()
	
	#remove dead numbers
	#for i in range(entities.size() - 1, -1, -1):
	#	if entities[i].is_dying():
	#		entities.remove_at(i)
	
	check_goal()
	pass

func get_entities_at_pos(pos):
	var temp_ents = []
	for i in entities:
		if i.grid_pos == pos:
			temp_ents.append(i)
	return temp_ents

func get_entities_blocking_at_pos(pos, blocked_entity):
	var temp_ents = []
	for i in entities:
		if i.grid_pos == pos and i.does_block(blocked_entity):
			temp_ents.append(i)
	return temp_ents


func is_in_grid_bounds(pos:Vector2i) -> bool:
	var grid_size = Globals.current_level.get_grid_size()
	return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y


func calculate_gesture():
	var d := releasedPos - pressedPos
	if d.length_squared() > threshold:
		if abs(d.x) > abs(d.y):
			if d.x < 0:
				return input_dir_mask.LEFT
			else:
				return input_dir_mask.RIGHT
		else:
			if d.y > 0:
				return input_dir_mask.DOWN
			else:
				return input_dir_mask.UP
	return 0
	
func check_goal():
	#todo: write gem in goal logic here
	pass

func on_game_over(won):
	set_game_paused(true)
	%ResultContainer.visible = true
	%TutorialContainer.visible = false
	if won:
		%WinLabel.visible = true
		if get_next_level():
			%ContinueButton.visible = true
	else:
		%LoseLabel.visible = true
		%RetryButton.visible = true

func _on_tut_ok_button_pressed():
	set_game_paused(false)
	%TutorialContainer.visible = false

func _on_main_menu_button_pressed():
	get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")

func get_next_level():
	var cur_idx = Globals.world_data.level_data.find(Globals.current_level_scene)
	if cur_idx != -1 and Globals.world_data.level_data.size() > cur_idx + 1:
		return Globals.world_data.level_data[cur_idx + 1]

func _on_continue_button_pressed():
	var next_level = get_next_level()
	if next_level:
		Globals.current_level_scene = next_level
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_retry_button_pressed():
	get_tree().change_scene_to_file("res://scenes/game.tscn")
