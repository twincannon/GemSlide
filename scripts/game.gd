extends Node2D
class_name Game

var tile_scene = preload("res://scenes/tile.tscn")
var par_moves_indicator_scene = preload("res://scenes/ui/par_moves_indicator.tscn")

var move_sound = preload("res://assets/audio/move.wav")
var goal_sound = preload("res://assets/audio/goal.wav")
var won_sound = preload("res://assets/audio/clap.wav")
var move_sounds = [preload("res://assets/audio/putt1.wav"), preload("res://assets/audio/putt2.wav"), preload("res://assets/audio/putt3.wav")]
@onready var move_queue_timer = $MoveQueueTimer as Timer

var tiles = []
var entities:Array[Entity] = []

var tile_size:Vector2
var grid_size:Vector2i

# For click and drag/touch controls
var pressedPos : Vector2
var releasedPos : Vector2
var threshold := 5000

var moves := 0
var moves_array:Array[Vector2i] = []

#var game_paused = false

var input_dir:int = 0
enum input_dir_mask { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 }

func _ready():
	get_tree().get_root().size_changed.connect(on_viewport_changed.bind())
	
	# can i queue_free this after im done with it?
	Globals.current_level = Globals.current_level_scene.instantiate() as LevelBase
	
	if Globals.current_level.tutorial.is_empty() == false:
		%TutorialContainer.visible = true
		%TutorialLabel.text = Globals.current_level.tutorial
		set_game_paused(true)
	
	%LevelNumLabel.text = "Level " + str(Globals.get_current_world_index() + 1) + "-" + str(Globals.get_current_level_index() + 1)
	
	grid_size = Globals.current_level.get_grid_size()
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
				tile_size = texsize
				tile_instance.position = get_position_at_grid_pos(Vector2i(x,y))
				#tile_instance.position.x = (texsize.x * x) - ((texsize.x * grid_size.x) / 2) + (texsize.x/2)
				#tile_instance.position.y = (texsize.y * y) - ((texsize.y * grid_size.y) / 2) + (texsize.y/2)
				tiles.append(tile_instance)
				
				if currentNum < entities_to_load.size():
					var entity = entities_to_load[currentNum]
					if entity:
						$GridAnchor.add_child(entity)
						entity.position = tile_instance.position
						#entity.scale = tilenode.transform.get_scale() # do we want this?
						entity.set_grid_pos(Vector2i(x,y))
						entities.append(entity)
						if entity is Gem:
							entity.on_goal_animation_finished.connect(on_gem_goal_anim_finished)
			currentNum += 1
	on_viewport_changed()


func on_viewport_changed():
	$GridAnchor.position = %GridPos.position
	#var padding = Vector2(100,100)
	#var viewport_size = get_viewport().size
	#var scaled = Vector2(viewport_size) / ((tile_size * Vector2(grid_size)) + padding)
	#$GridAnchor.scale = Vector2(min(scaled.x, scaled.y),min(scaled.x, scaled.y))
	var new_scale = 3.0 / float(max(grid_size.x, grid_size.y))
	$GridAnchor.scale = Vector2(new_scale, new_scale) #Hacky... but the above solution no longer works with stretch mode, for some reason?
	#$Background.position.x = viewport_size.x/2
	
	#%TutorialContainer.add_theme_constant_override("margin_right", 20 if viewport_size.x < 1000 else 300)
	#%TutorialContainer.add_theme_constant_override("margin_left", 20 if viewport_size.x < 1000 else 300)


func set_game_paused(paused):
	get_tree().paused = paused

func _process(_delta):
	var all_goals_filled = true
	for e in entities:
		var goal = e as Goal
		if goal and !goal.is_goal_filled():
			all_goals_filled = false
		if e.is_forcibly_moving:
			move_queue_timer.stop()
			return
	if all_goals_filled: return # Don't allow further input after all goals have been filled (but are awaiting animation for game pause)
	
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
		if !queued_move and move_queue_timer.is_stopped():
			move_entities(dir)
		elif move_queue_timer.is_stopped() and queue_duration > 0.0 and Input.is_action_just_released("click"): # Only queue for swipe gestures for now
			if move_queue_timer.timeout.is_connected(move_entities):
				move_queue_timer.timeout.disconnect(move_entities)
			move_queue_timer.timeout.connect(move_entities.bind(dir))
			move_queue_timer.start(queue_duration)
	
	if Input.is_action_just_released("click"):
		input_dir = 0


func _input(event):
	if event.is_action("click") and Input.is_action_just_pressed("click"):
		pressedPos = event.position
	if event.is_action("click") and Input.is_action_just_released("click"):
		releasedPos = event.position
		input_dir = calculate_gesture()
		for e in entities:
			if e.is_forcibly_moving:
				input_dir = 0 # Hacky
	
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
	move_queue_timer.stop()
	
	var did_any_entity_move = false
	
	# Iterate forwards or backwards depending on our direction, probably a better way to do this? The reason for this is to prevent wrong-order iteration on our entities
	if dir == Vector2i.UP or dir == Vector2i.LEFT:
		for i in entities:
			if i.on_try_move(dir):
				did_any_entity_move = true
	elif dir == Vector2i.DOWN or dir == Vector2i.RIGHT:
		for i in range(entities.size() - 1, -1, -1):
			if entities[i].on_try_move(dir):
				did_any_entity_move = true
	
	if did_any_entity_move:
		$Audio/MoveAudioPlayer.stream = move_sounds[randi() % move_sounds.size()]
		$Audio/MoveAudioPlayer.play()
		increment_moves()
		moves_array.append(dir)


func increment_moves():
	moves += 1
	%MovesLabel.text = "Moves: " + str(moves)

func on_gem_goal_anim_finished():
	for e in entities:
		var gem = e as Gem
		if gem and gem.gem_in_goal and !gem.is_gem_goal_anim_done():
			return
			
	check_goal()

func get_entities_at_pos(pos):
	var temp_ents = []
	for i in entities:
		if i.grid_pos == pos:
			temp_ents.append(i)
	return temp_ents

func get_entities_blocking_at_pos(pos, blocked_entity):
	var temp_ents = []
	for i in entities:
		if i.grid_pos == pos and i._does_block(blocked_entity):
			temp_ents.append(i)
	return temp_ents

func get_position_at_grid_pos(grid_pos:Vector2i) -> Vector2:
	return Vector2((tile_size.x * grid_pos.x) - ((tile_size.x * grid_size.x) / 2) + (tile_size.x/2), \
				   (tile_size.y * grid_pos.y) - ((tile_size.y * grid_size.y) / 2) + (tile_size.y/2))

func is_in_grid_bounds(pos:Vector2i) -> bool:
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
	var all_goals_filled = true
	for e in entities:
		var goal = e as Goal
		if goal:
			if goal.is_goal_filled() == false:
				all_goals_filled = false
	
	if all_goals_filled:
		do_par_moves_anim()

func do_par_moves_anim():
	if moves <= Globals.current_level.par_moves:
		var par_moves_indicator = par_moves_indicator_scene.instantiate()
		if moves == Globals.current_level.par_moves:
			par_moves_indicator.result = Globals.ResultType.Par
		elif moves <= Globals.current_level.par_moves - 5:
			par_moves_indicator.result = Globals.ResultType.SuperEagle
		elif moves <= Globals.current_level.par_moves - 3:
			par_moves_indicator.result = Globals.ResultType.Eagle
		elif moves <= Globals.current_level.par_moves - 1:
			par_moves_indicator.result = Globals.ResultType.Birdie
		%HUD.add_child(par_moves_indicator)
		par_moves_indicator.on_indicator_done.connect(on_game_over.bind(true))
	else:
		on_game_over(true)
	
func on_goal_filled(_goal):
	$Audio/GoalAudioPlayer.stream = goal_sound
	$Audio/GoalAudioPlayer.play()

func on_game_over(won):
	if won:
		$Audio/WonAudioPlayer.stream = won_sound
		$Audio/WonAudioPlayer.play()
	set_game_paused(true)
	%ResultContainer.visible = true
	%TutorialContainer.visible = false
	if won:
		%WinLabel.visible = true
		if get_next_level():
			%ContinueButton.visible = true
		var current_score = SaveGame.get_level_score(Globals.current_level_scene.resource_path)
		if current_score > 0 and moves < current_score or current_score == 0:
			SaveGame.set_level_score(Globals.current_level_scene.resource_path, moves)
			SaveGame.set_level_moves(Globals.current_level_scene.resource_path, moves_array)
		var next_level = get_next_level()
		if next_level:
			SaveGame.set_level_unlocked(next_level.resource_path)
		SaveGame.save_game()
	else:
		%LoseLabel.visible = true
		%RetryButton.visible = true

func _on_tut_ok_button_pressed():
	set_game_paused(false)
	%TutorialContainer.visible = false

func _on_main_menu_button_pressed():
	set_game_paused(false)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func get_next_level():
	var cur_idx = Globals.get_current_level_index()
	if cur_idx != -1 and Globals.current_world_data.level_data.size() > cur_idx + 1:
		return Globals.current_world_data.level_data[cur_idx + 1]

func _on_continue_button_pressed():
	set_game_paused(false)
	var next_level = get_next_level()
	if next_level:
		Globals.change_level(next_level)
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_retry_button_pressed():
	set_game_paused(false)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_hud_retry_button_pressed():
	set_game_paused(false)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_hud_main_menu_button_pressed():
	set_game_paused(false)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
