extends Node2D
class_name Game

const tile_scene = preload("res://scenes/tile.tscn")
const par_moves_indicator_scene = preload("res://scenes/ui/par_moves_indicator.tscn")
@onready var entity_icon_scene = load("res://scenes/level_editor/entity_icon.tscn")
const blank_level_scene = preload("res://scenes/levels/blank_level.tscn")

var goal_sound = preload("res://assets/audio/goal.wav")
var won_sound = preload("res://assets/audio/clap.wav")
var move_sounds = [preload("res://assets/audio/putt1.wav"), preload("res://assets/audio/putt3.wav")] # Removed preload("res://assets/audio/putt2.wav"), for now due to extra bass in it
@onready var move_queue_timer = $MoveQueueTimer as Timer
@onready var move_cooldown_timer = $MoveCooldownTimer as Timer

enum GameState { PLAYING, END }
var game_state = GameState.PLAYING

var tiles = []
var entities:Array[Entity] = []
var entities_to_remove:Array[Entity] = [] # Store entities to remove at end of current move operation so we don't mess with order of entities during iteration

var tile_size:Vector2
var grid_size:Vector2i

# For click and drag/touch controls
var pressedPos : Vector2
var releasedPos : Vector2
var threshold := 5000

var moves := 0
var moves_array:Array[Vector2i] = []

var bottom_buttons_visible := false
var bottom_buttons_tween:Tween

#var game_paused = false

var input_dir:int = 0
enum input_dir_mask { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 }

var data:Dictionary = { }

var undo_manager:UndoManager

func _ready():
	get_tree().get_root().size_changed.connect(on_viewport_changed.bind())
	
	undo_manager = UndoManager.new()
	undo_manager.game = self
	
	if Globals.current_level_data:
		data = Globals.current_level_data.get_data()
		%LevelNumLabel.text = "Hole " + str(Globals.get_current_world_index() + 1) + "-" + str(Globals.get_current_level_index() + 1)
		print(SaveGame.level_dict[Globals.current_level_data.resource_path])
	elif !Globals.custom_level_data.is_empty() and Globals.is_valid_custom_level(Globals.custom_level_data):
		data = Globals.custom_level_data
		%LevelNumLabel.text = data["LevelName"]
	else:
		printerr("Entered game scene with no valid level data")
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	
	grid_size = str_to_var(data["GridSize"])
	var entities_to_load = []
	for i in range(data["Entities"].size()):
		var new_icon = entity_icon_scene.instantiate()
		if new_icon:
			new_icon.set_entity_type(data["Entities"][i] as Globals.EntityType)
			new_icon.set_entity_id(data["EntityIDs"][i]) #What is this for?
			var new_entity = new_icon.get_entity()
			if new_entity: #check for null as we intend to have null entries
				new_entity.entity_type = data["Entities"][i] as Globals.EntityType
				new_entity.entity_id = data["EntityIDs"][i]
			entities_to_load.append(new_entity) #get instantiated entity
			
	%ParLabel.text = "Par: " + str(int(data["ParMoves"]))
	
	if !Globals.did_retry and data.has("Tutorial"):
		if data["Tutorial"].is_empty() == false:
			%TutorialContainer.visible = true
			%TutorialLabel.text = data["Tutorial"]
			set_game_paused(true)
	Globals.did_retry = false
	
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
						tile_instance.on_entity_spawned_on_tile()
						add_entity_to_grid(entity, Vector2i(x,y))
			currentNum += 1
	for e in entities:
		e._initialize_entity(self)
	on_viewport_changed()
	undo_manager.push_game_state()

func add_entity_to_grid(entity:Entity, grid_pos:Vector2i):
	$GridAnchor.add_child(entity)
	entity.position = get_position_at_grid_pos(grid_pos)
	#entity.scale = tilenode.transform.get_scale() # do we want this?
	entity.set_grid_pos(grid_pos)
	entities.append(entity)

func on_viewport_changed():
	$GridAnchor.position = %GridPos.position
	var viewport_size = get_viewport().size
	
	# Calculate the total grid size in pixels
	var grid_pixel_size = tile_size * Vector2(grid_size)
	
	# padding to ensure the grid doesn't touch the edges or overlap UI
	var padding = Vector2i(200, 500)
	
	# Calculate available space (accounting for UI elements)
	var available_size = viewport_size - padding
	
	# Calculate scale factors for both dimensions
	var scale_x = available_size.x / grid_pixel_size.x
	var scale_y = available_size.y / grid_pixel_size.y
	
	# Use the smaller scale to ensure the grid fits in both dimensions
	var final_scale = min(scale_x, scale_y)
	
	# Apply a maximum scale to prevent the grid from becoming too large
	var max_scale = 3.0
	final_scale = min(final_scale, max_scale)
	
	# Apply the scale
	$GridAnchor.scale = Vector2(final_scale, final_scale)
	
	%BackgroundImageRoot.position.x = viewport_size.x/2
	#%BackgroundImageRoot.position.x = viewport_size.x
	#%BackgroundImageRoot.position.y = viewport_size.y
	var bushoffset = 75
	$BushRight.position = %BottomRightPos.position + Vector2(-bushoffset,-bushoffset)
	$BushLeft.position = %BottomLeftPos.position + Vector2(bushoffset,-bushoffset)
	
	#%TutorialContainer.add_theme_constant_override("margin_right", 20 if viewport_size.x < 1000 else 300)
	#%TutorialContainer.add_theme_constant_override("margin_left", 20 if viewport_size.x < 1000 else 300)


func set_game_paused(paused):
	get_tree().paused = paused

func _process(_delta):
	# Process our entities queued for removal - do this here instead of during movement so we don't cause bugs with iteration
	for e in entities_to_remove:
		entities.erase(e)
	entities_to_remove.clear()
	
	if !move_cooldown_timer.is_stopped(): return
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
			move_cooldown_timer.start()
		elif move_queue_timer.is_stopped() and queue_duration > 0.0 and Input.is_action_just_released("click"): # Only queue for swipe gestures for now
			if move_queue_timer.timeout.is_connected(move_entities):
				move_queue_timer.timeout.disconnect(move_entities)
			move_queue_timer.timeout.connect(move_entities.bind(dir))
			move_queue_timer.start(queue_duration)
	
	if !Input.is_action_pressed("up") and !Input.is_action_pressed("down") and !Input.is_action_pressed("left") and !Input.is_action_pressed("right"):
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
	
	for i in entities:
		i._entity_pre_move(dir)
	
	# Iterate forwards or backwards depending on our direction, probably a better way to do this? The reason for this is to prevent wrong-order iteration on our entities
	# Wait does this even make sense? The order of entities doesn't correlate to their position on the grid
	#if dir == Vector2i.UP or dir == Vector2i.LEFT:
	for i in entities:
		if i.on_try_move(dir) or i._should_increment_moves(dir):
			did_any_entity_move = true
	#elif dir == Vector2i.DOWN or dir == Vector2i.RIGHT:
	#	for i in range(entities.size() - 1, -1, -1):
	#		if entities[i].on_try_move(dir) or entities[i]._should_increment_moves(dir):
	#			did_any_entity_move = true
		
	if did_any_entity_move:
		$Audio/MoveAudioPlayer.stream = move_sounds[randi() % move_sounds.size()]
		$Audio/MoveAudioPlayer.pitch_scale = randf_range(0.9, 1.2)
		$Audio/MoveAudioPlayer.play()
		increment_moves()
		moves_array.append(dir)
		for e in entities:
			if e.moving:
				e.on_movement_done.connect(check_for_last_movement)
		undo_manager.push_game_state()

func check_for_last_movement(entity:Entity):
	entity.on_movement_done.disconnect(check_for_last_movement)
	var any_entity_moving = false
	for e in entities:
		if e.moving:
			any_entity_moving = true
	if !any_entity_moving:
		on_all_movement_finished()

func on_all_movement_finished():
	for i in entities:
		i._entity_post_all_movement()

func increment_moves():
	moves += 1
	%MovesLabel.text = "Moves: " + str(moves)

func on_gem_goal_anim_finished():
	for e in entities:
		var gem = e as Gem
		if gem and gem.gem_in_goal and !gem.is_gem_goal_anim_done():
			return
	
	#var all_goals_filled = true
	#for e in entities:
	#	var goal = e as Goal
	#	if goal and !goal.is_goal_filled():
	#		all_goals_filled = false
	#if !all_goals_filled: return
			
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

func queue_entity_for_removal(entity_to_remove):
	entities_to_remove.append(entity_to_remove)

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
	if game_state == GameState.END:
		return # Prevent stuff like water hazards triggering a second check_goal() call after winning
	
	var goal_dict = { "Red":0, "Green":0, "Blue":0 }
	var gem_dict = { "Red":0, "Green":0, "Blue":0  }
	var all_goals_filled = true
	for e in entities:
		var goal = e as Goal
		if goal:
			if goal.is_goal_filled() == false:
				all_goals_filled = false
			match goal.get_node("ColorComponent").color:
				Globals.COLOR_RED:
					goal_dict["Red"] += 1
				Globals.COLOR_GREEN:
					goal_dict["Green"] += 1
				Globals.COLOR_BLUE:
					goal_dict["Blue"] += 1
		var gem = e as Gem
		if gem:
			match gem.get_node("ColorComponent").color:
				Globals.COLOR_RED:
					gem_dict["Red"] += 1
				Globals.COLOR_GREEN:
					gem_dict["Green"] += 1
				Globals.COLOR_BLUE:
					gem_dict["Blue"] += 1
	
	var can_win = gem_dict["Red"] >= goal_dict["Red"] and gem_dict["Green"] >= goal_dict["Green"] and gem_dict["Blue"] >= goal_dict["Blue"]

	if all_goals_filled:
		game_state = GameState.END
		#print("all goals filled @ " + Time.get_time_string_from_system())
		save_game()
		do_par_moves_anim()
	elif !can_win:
		on_game_over(false)
		
func save_game():
	if Globals.current_level_data:
		var current_score = SaveGame.get_level_score(Globals.current_level_data.resource_path)
		if current_score > 0 and moves < current_score or current_score == 0:
			SaveGame.set_level_score(Globals.current_level_data.resource_path, moves)
			SaveGame.set_level_moves(Globals.current_level_data.resource_path, moves_array)
		var next_level = get_next_level()
		if next_level:
			SaveGame.set_level_unlocked(next_level.resource_path)
		SaveGame.save_game()

func do_par_moves_anim():
	if data:
		if moves <= data["ParMoves"]:
			var par_moves_indicator = par_moves_indicator_scene.instantiate()
			if moves == data["ParMoves"]:
				par_moves_indicator.result = Globals.ResultType.Par
			elif data.has("DevBest") and moves < data["DevBest"]:
				par_moves_indicator.result = Globals.ResultType.BeatDev
			elif moves <= data["ParMoves"] - 5:
				par_moves_indicator.result = Globals.ResultType.SuperEagle
			elif moves <= data["ParMoves"] - 3:
				par_moves_indicator.result = Globals.ResultType.Eagle
			elif moves <= data["ParMoves"] - 1:
				par_moves_indicator.result = Globals.ResultType.Birdie
			%HUD.add_child(par_moves_indicator)
			par_moves_indicator.on_indicator_done.connect(on_game_over.bind(true))
		else:
			on_game_over(true)
	else:
		on_game_over(true)
	
func on_goal_filled(_goal):
	$Audio/GoalAudioPlayer.stream = goal_sound
	$Audio/GoalAudioPlayer.play()

func on_game_over(won):
	game_state = GameState.END
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
	if cur_idx != -1 and Globals.current_world_data.level_data_json.size() > cur_idx + 1:
		return Globals.current_world_data.level_data_json[cur_idx + 1]

func _on_continue_button_pressed():
	set_game_paused(false)
	var next_level = get_next_level()
	if next_level:
		Globals.change_level(next_level)
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_retry_button_pressed():
	set_game_paused(false)
	Globals.did_retry = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_hud_retry_button_pressed():
	set_game_paused(false)
	Globals.did_retry = true
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_hud_main_menu_button_pressed():
	set_game_paused(false)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_expand_hud_button_pressed():
	if bottom_buttons_tween and bottom_buttons_tween.is_running():
		return
	bottom_buttons_visible = !bottom_buttons_visible
	%ExpandHUDButton/ExpandHUDButtonTex.flip_h = bottom_buttons_visible
	bottom_buttons_tween = create_tween()
	bottom_buttons_tween.set_trans(Tween.TRANS_CUBIC)
	bottom_buttons_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if bottom_buttons_visible:
		bottom_buttons_tween.tween_property(%BottomButtonsContainer, "position:y", -100, 0.5).as_relative()
	else:
		bottom_buttons_tween.tween_property(%BottomButtonsContainer, "position:y", 100, 0.5).as_relative()


func _on_undo_button_pressed() -> void:
	undo_manager.pop_game_state()
