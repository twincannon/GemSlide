extends Node2D
class_name Game

const tile_scene = preload("res://scenes/tile.tscn")
const par_moves_indicator_scene = preload("res://scenes/ui/par_moves_indicator.tscn")
@onready var entity_icon_scene = load("res://scenes/level_editor/entity_icon.tscn")
const blank_level_scene = preload("res://scenes/levels/blank_level.tscn")

const VFX_FIREWORK = preload("res://scenes/vfx/vfx_firework.tscn")

var goal_sound = preload("res://assets/audio/goal.wav")
var goal_sound_bowling = preload("res://assets/audio/goal_bowling.wav")

var won_sound = preload("res://assets/audio/clap.wav")
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

var camera_target_zoom = 1.0
var camera_target_pos = Vector2.ZERO

func _ready():
	get_tree().get_root().size_changed.connect(on_viewport_changed.bind())
	
	undo_manager = UndoManager.new(self)	
	SoundManager.start_game_music()
	
	if Globals.current_level_data:
		data = Globals.current_level_data.get_data()
		var level_name:String = ""
		if data.has("LevelName"):
			level_name = data["LevelName"]
		%LevelNumLabel.text = "Hole " + str(Globals.get_current_world_index() + 1) \
			+ "-" + str(Globals.get_current_level_index() + 1) \
			+ ((": " + level_name) if level_name != "" else "")
		
		# Debug print
		var dict = SaveGame.level_dict[Globals.current_level_data.resource_path]
		var debugstr = ""
		if dict.has("score"):
			debugstr += "Score: "
			debugstr += str(int(dict.score))
		if dict.has("moves") and dict.moves.size() > 0:
			if debugstr != "":
				debugstr += ", "
			debugstr += "Best moves: \n"
			var count := 0
			for m in dict.moves: #Hackyness: why are we ever retrieving data as vector2i? (Happens when reloading a level after setting a new record in score, for example)
				count += 1
				if (m is Vector2i and m == Vector2i(1,0)) or (m is String and m == "(1, 0)"):
					debugstr += "→"
				elif (m is Vector2i and m == Vector2i(-1,0)) or (m is String and m == "(-1, 0)"):
					debugstr += "←"
				elif (m is Vector2i and m == Vector2i(0,1)) or (m is String and m == "(0, 1)"):
					debugstr += "↓"
				elif (m is Vector2i and m == Vector2i(0,-1)) or (m is String and m == "(0, -1)"):
					debugstr += "↑"
				if count % 3 == 0:
					debugstr += ", "
				else:
					debugstr += " "
				if count % 9 == 0:
					debugstr += "\n"
			if debugstr.ends_with("\n"):
				debugstr = debugstr.rstrip("\n")
			if debugstr.ends_with(", "):
				debugstr = debugstr.rstrip(", ")
			%BestMovesLabel.text = debugstr
		print(debugstr)
		#print(SaveGame.level_dict[Globals.current_level_data.resource_path])
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
				new_entity.name = Globals.EntityType.keys()[data["Entities"][i]]
			entities_to_load.append(new_entity) #add instantiated entity
			
	%ParLabel.text = "Par: " + str(int(data["ParMoves"]))
	
	if !Globals.did_retry and data.has("Tutorial"):
		if data["Tutorial"].is_empty() == false:
			%TutorialContainer.visible = true
			%TutorialLabel.text = data["Tutorial"]
			%TutOkButton.visible = false
			$TutOkButtonTimer.start()
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
						if entity is Gem:
							entity.on_gem_entered_goal.connect(on_gem_entered_goal.bind())
			currentNum += 1
	for e in entities:
		e._initialize_entity(self)
	on_viewport_changed()
		
	# Uncomment the following lines to enable automatic solving
	#var solver = PuzzleSolver.new(self)
	#var solution = solver.solve()
	#if solution.size() > 0:
		#print("Optimal solution found in ", solution.size(), " moves")
		#for i in range(solution.size()):
		#	var dir = solution[i]
		#	var dir_name = ""
		#	if dir == Vector2i.UP: dir_name = "UP"
		#	elif dir == Vector2i.DOWN: dir_name = "DOWN"
		#	elif dir == Vector2i.LEFT: dir_name = "LEFT"
		#	elif dir == Vector2i.RIGHT: dir_name = "RIGHT"
		#	print("Move ", i + 1, ": ", dir_name)
	#else:
		#print("Level is unsolvable or too complex")

func _enable_tutorial_ok_button():
	%TutOkButton.visible = true

func add_entity_to_grid(entity:Entity, grid_pos:Vector2i):
	$GridAnchor.add_child(entity)
	entity.position = get_position_at_grid_pos(grid_pos)
	#entity.scale = tilenode.transform.get_scale() # do we want this?
	entity.set_grid_pos(grid_pos)
	entities.append(entity)

func on_viewport_changed():
	$GridAnchor.position = %GridPos.position
	var viewport_size = get_viewport_rect().size #key here is to use get_viewport_rect() as opposed to get_viewport()
	
	# Calculate the total grid size in pixels
	var grid_pixel_size = tile_size * Vector2(grid_size)
	
	# padding to ensure the grid doesn't touch the edges or overlap UI
	var padding = Vector2(100, 200)
	var available_size = viewport_size - padding
	
	var scale_x = available_size.x / grid_pixel_size.x
	var scale_y = available_size.y / grid_pixel_size.y
	
	# Use the smaller scale to ensure the grid fits in both dimensions
	var final_scale = min(scale_x, scale_y)
	final_scale = clamp(final_scale, 0.2, 3.0)
	
	# Apply the scale
	$GridAnchor.scale = Vector2(final_scale, final_scale)

	%BackgroundImageRoot.position.x = viewport_size.x/2
	#%BackgroundImageRoot.position.x = viewport_size.x
	#%BackgroundImageRoot.position.y = viewport_size.y
	var bushoffset = 75
	$BushRight.position = %BottomRightPos.position + Vector2(-bushoffset,-bushoffset)
	$BushLeft.position = %BottomLeftPos.position + Vector2(bushoffset,-bushoffset)
	
	#%Camera2D.offset = viewport_size/2
	#%TutorialContainer.add_theme_constant_override("margin_right", 20 if viewport_size.x < 1000 else 300)
	#%TutorialContainer.add_theme_constant_override("margin_left", 20 if viewport_size.x < 1000 else 300)


func set_game_paused(paused):
	get_tree().paused = paused

func _process(_delta):
	# Process our entities queued for removal - do this here instead of during movement so we don't cause bugs with iteration
	for e in entities_to_remove:
		entities.erase(e)
		e.start_free_timer()
	entities_to_remove.clear()
	
	#if camera_target_zoom == 2.0:
	%Camera2D.zoom = %Camera2D.zoom.lerp(Vector2(camera_target_zoom, camera_target_zoom), _delta * 10)
	%Camera2D.position = %Camera2D.position.lerp(camera_target_pos, _delta * 10)
	#else:
	#	Engine.time_scale = 1.0
	
	if !check_goals_and_winnable()[1]:
		return
	
	if !move_cooldown_timer.is_stopped(): return
	var all_goals_filled = true
	for e in entities:
		var goal = e as Goal
		if goal and !goal.is_goal_filled():
			all_goals_filled = false

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
			move_entities(dir, entities)
			move_cooldown_timer.start()
		elif move_queue_timer.is_stopped() and queue_duration > 0.0 and Input.is_action_just_released("click"): # Only queue for swipe gestures for now
			if move_queue_timer.timeout.is_connected(move_entities):
				move_queue_timer.timeout.disconnect(move_entities)
			move_queue_timer.timeout.connect(move_entities.bind(dir, entities))
			move_queue_timer.start(queue_duration)
	
	if !Input.is_action_pressed("up") and !Input.is_action_pressed("down") and !Input.is_action_pressed("left") and !Input.is_action_pressed("right"):
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
		

func sort_ents_by_grid_pos(a, b):
	var pos1 = a.grid_pos.x + a.grid_pos.y * grid_size.y
	var pos2 = b.grid_pos.x + b.grid_pos.y * grid_size.y
	if pos1 < pos2:
		return true
	return false

func sort_ents_by_push_direction(a, b):
	# For bomb explosions, sort entities based on their push direction
	# Entities moving in the same direction should be sorted by their position
	if a.pending_move_dir == b.pending_move_dir:
		var pos1 = a.grid_pos.x + a.grid_pos.y * grid_size.y
		var pos2 = b.grid_pos.x + b.grid_pos.y * grid_size.y
		# For RIGHT and DOWN directions, reverse the order so entities further in that direction move first
		if a.pending_move_dir == Vector2i.RIGHT or a.pending_move_dir == Vector2i.DOWN:
			return pos1 > pos2
		else:
			return pos1 < pos2
	else:
		# Different directions, sort by direction priority (arbitrary but consistent)
		var dir1_priority = a.pending_move_dir.x + a.pending_move_dir.y * 2
		var dir2_priority = b.pending_move_dir.x + b.pending_move_dir.y * 2
		return dir1_priority < dir2_priority

func move_entities(dir:Vector2i, ents_to_move:Array[Entity]):
	if ents_to_move.size() == 0:
		return
	
	var is_bomb_explosion = dir == Vector2i.ZERO
	
	move_queue_timer.stop()
	
	if !is_bomb_explosion:
		undo_manager.push_game_state()
	
	var moving_entities = []
	for ent in ents_to_move:
		if ent.moves:
			moving_entities.append(ent)
	
	# Get sorted array of entities based on which dir we're moving
	var sorted_ent_array = moving_entities
	if is_bomb_explosion:
		# For bomb explosions, use push direction sorting
		sorted_ent_array.sort_custom(sort_ents_by_push_direction)
	else:
		# For normal movement, use grid position sorting
		sorted_ent_array.sort_custom(sort_ents_by_grid_pos)
		if dir == Vector2i.RIGHT or dir == Vector2i.DOWN:
			sorted_ent_array.reverse()

	for e in sorted_ent_array:
		e.old_grid_pos = e.grid_pos
		if e.moves and !is_bomb_explosion:
			e.pending_move_dir = dir
		# If dir is Vector2i.ZERO, entities should already have their pending_move_dir set
	
	for e in sorted_ent_array:
		if e.pending_move_dir != Vector2i.ZERO:
			if !e.can_move_in_dir(e.pending_move_dir):
				e.pending_move_dir = Vector2i.ZERO
				continue
			else:
				e.grid_pos += e.pending_move_dir
			
			for ent in get_entities_at_pos(e.grid_pos):
				if ent.forces_movement:
					var is_force_moving = true
					while is_force_moving:
						if e.can_move_in_dir(e.pending_move_dir):
							e.grid_pos += e.pending_move_dir
							is_force_moving = false
							for cur_ent in get_entities_at_pos(e.grid_pos):
								if cur_ent.forces_movement:
									is_force_moving = true
						else:
							is_force_moving = false
	
	var did_any_entity_move = false
	var any_move_blocked = false
	
	#Seems weird to have this after movement, but we need to have it here for
	#sand traps to work properly - since they check can_move_in_dir, we need
	#to have up to date grid_pos's (also sand trap is the only entity that uses this)
	for i in sorted_ent_array:
		if i._should_increment_moves(dir):
			did_any_entity_move = true
		i._entity_pre_move(dir)
	
	for e in sorted_ent_array:
		if e.pending_move_dir != Vector2i.ZERO:
			for start_ent in get_entities_at_pos(e.grid_pos - e.pending_move_dir): #or e.old_grid_pos?
				start_ent._on_entity_exited(e)
			did_any_entity_move = true
			for dest_ent in get_entities_at_pos(e.grid_pos):
				dest_ent._on_entity_entered(e)
			e.pending_move_dir = Vector2i.ZERO
		else:
			e._on_movement_blocked(dir)
			any_move_blocked = true
		if e.grid_pos != e.old_grid_pos:
			e._on_movement(e.grid_pos - e.old_grid_pos)
	
	if any_move_blocked and !did_any_entity_move:
		$Audio/BonkAudioPlayer.play() #play a "bump" sfx
	
	if did_any_entity_move:
		var move_sounds:Array[Resource]
		for e in sorted_ent_array:
			if e is Gem: #this is probably pointless: if we have custom goals etc for skins, then we can't have random gem selection
				move_sounds.append(e.get_move_sound())
		if move_sounds.size() > 0:
			$Audio/MoveAudioPlayer.stream = move_sounds[randi() % move_sounds.size()]
			$Audio/MoveAudioPlayer.pitch_scale = randf_range(0.9, 1.2)
			$Audio/MoveAudioPlayer.play()
		if !is_bomb_explosion:
			increment_moves()
			moves_array.append(dir)
		for e in sorted_ent_array:
			if e.moving:
				e.on_movement_done.connect(check_for_last_movement)
		#Experimental skew tween
		for t in tiles:
			var tween = create_tween()
			var skew_strength = 0.025
			var skew_amount = skew_strength if (dir == Vector2i.UP or dir == Vector2i.RIGHT) else -skew_strength
			tween.tween_property(t, "skew", skew_amount, 0.08)
			tween.tween_property(t, "skew", 0.0, 0.08)
	elif !is_bomb_explosion:
		undo_manager.remove_newest_game_state() #Nothing moved, so pop the added gamestate.

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
	# do bomb explode logic here?
	# Check for bomb explosions and handle them simultaneously
	var entity_push_directions: Dictionary = {} # entity -> array of push directions
	
	# Collect all push directions from all exploding bombs
	for e in entities:
		if e is Bomb and e.should_explode_now():
			var exploded_entities = e.explode()
			for entity in exploded_entities:
				if !entity_push_directions.has(entity):
					entity_push_directions[entity] = []
				entity_push_directions[entity].append(entity.pending_move_dir)
	
	# Resolve conflicting forces and set final push directions
	var ents_to_move: Array[Entity] = []
	for entity in entity_push_directions:
		var directions = entity_push_directions[entity]
		var net_direction = Vector2i.ZERO
		
		# Sum all push directions
		for dir in directions:
			net_direction += dir
		
		# Only move if there's a net force
		if net_direction != Vector2i.ZERO:
			entity.pending_move_dir = net_direction
			ents_to_move.append(entity)
		else:
			# Cancel out the movement
			entity.pending_move_dir = Vector2i.ZERO
	
	move_entities(Vector2i.ZERO, ents_to_move)

func increment_moves():
	moves += 1
	update_moves_text()

func update_moves_text():
	%MovesLabel.text = "Moves: " + str(moves)

func on_gem_entered_goal(gem):
	var status = check_goals_and_winnable()
	if status[0]:
		camera_target_zoom = 2.0
		camera_target_pos = get_position_at_grid_pos(gem.grid_pos)
		$Audio/VictoryAudioPlayer.play()
		SoundManager.set_music_ducked(true)
		Engine.time_scale = 0.1
		get_tree().create_timer(0.25).timeout.connect(restore_engine_timescale.bind())
		gem.do_goal_celebration()

func restore_engine_timescale():
	Engine.time_scale = 1.0

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
	
	var goals_win_state_array = check_goals_and_winnable()
	var all_goals_filled = goals_win_state_array[0]
	var can_win = goals_win_state_array[1]
	
	if all_goals_filled:
		game_state = GameState.END
		#print("all goals filled @ " + Time.get_time_string_from_system())
		var unlock_str = UnlockManager.on_level_beat(Globals.get_current_world_index() + 1, Globals.get_current_level_index() + 1)
		if unlock_str != "":
			%UnlockContainer.visible = true
			%UnlockLabel.text = unlock_str
		save_game()
		do_par_moves_anim()
	elif !can_win:
		on_game_over(false)

func check_goals_and_winnable():
	var goal_dict = { "Red":0, "Green":0, "Blue":0 }
	var gem_dict = { "Red":0, "Green":0, "Blue":0  }
	var all_goals_filled = true
	for e in entities:
		var goal = e as Goal
		if goal:
			if goal.is_goal_filled() == false:
				all_goals_filled = false
			match goal.get_node("ColorComponent").hue:
				Globals.hue_red:
					goal_dict["Red"] += 1
				Globals.hue_green:
					goal_dict["Green"] += 1
				Globals.hue_blue:
					goal_dict["Blue"] += 1
		var gem = e as Gem
		if gem:
			match gem.get_node("ColorComponent").hue:
				Globals.hue_red:
					gem_dict["Red"] += 1
				Globals.hue_green:
					gem_dict["Green"] += 1
				Globals.hue_blue:
					gem_dict["Blue"] += 1
	
	var can_win = gem_dict["Red"] >= goal_dict["Red"] and gem_dict["Green"] >= goal_dict["Green"] and gem_dict["Blue"] >= goal_dict["Blue"]
	return [all_goals_filled, can_win]

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
	Engine.time_scale = 1.0
	if data:
		if moves <= data["ParMoves"]:
			var par_moves_indicator = par_moves_indicator_scene.instantiate()
			if moves == data["ParMoves"]:
				par_moves_indicator.result = Globals.ResultType.Par
				#do_fireworks(1)
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
	$Audio/GoalAudioPlayer.stream = get_goal_sound()
	$Audio/GoalAudioPlayer.play()
	#Handle bomb ignite logic
	for e in entities:
		if e is Bomb and ((e.gem_in_goal == false and _goal.matches_color(e)) or e.moves_until_explosion >= 0):
			e.ignite_fuse() #Ignite for first time, or re-ignite so it doesn't explode

func get_goal_sound() -> Resource:
	if SaveGame.selected_skin == SkinManager.SkinType.BOWLINGBALL:
		return goal_sound_bowling
	else:
		return goal_sound

func on_bomb_explode():
	$Audio/BombExplodeAudioPlayer.play()

func on_bomb_ignite():
	$Audio/BombIgniteAudioPlayer.play()

func on_bomb_defuse():
	$Audio/BombDefuseAudioPlayer.play()

func on_teleport():
	$Audio/TeleportAudioPlayer.play()

func on_game_over(won):
	SoundManager.set_music_ducked(false)
	game_state = GameState.END
	if won:
		$Audio/WonAudioPlayer.stream = won_sound
		$Audio/WonAudioPlayer.play()
	set_game_paused(true)
	%ResultContainer.visible = true
	%TutorialContainer.visible = false
	if won:
		%LoseLabel.visible = false
		%WinLabel.visible = true
		if get_next_level():
			%ContinueButton.visible = true
		elif Globals.custom_level_data.is_empty(): # Don't want to show this for custom levels
			%WinLabel.text = "Congratulations, you finished the course!\nCheck out more levels at the main menu!"
	else:
		%LoseLabel.visible = true
		%WinLabel.visible = false
		%ContinueButton.visible = false
		%UndoResultButton.visible = true

func _on_tut_ok_button_pressed():
	set_game_paused(false)
	%TutorialContainer.visible = false

func _on_main_menu_button_pressed():
	set_game_paused(false)
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func get_next_level():
	var cur_idx = Globals.get_current_level_index()
	if cur_idx != -1 and Globals.current_world_data.level_data_json.size() > cur_idx + 1:
		return Globals.current_world_data.level_data_json[cur_idx + 1]
	return null

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

func _on_hud_solver_button_pressed():
	# Create solver and find solution
	var solver = PuzzleSolver.new(self)
	var solution = solver.solve()
	
	if solution.size() > 0:
		# Show solution in UI (you could add a popup or overlay here)
		# For now, just show a simple message
		%LevelNumLabel.text = "Solution: " + str(solution.size()) + " moves found!"
	else:
		print("No solution found!")
		%LevelNumLabel.text = "No solution found!"


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
	var best_moves_has_text = %BestMovesLabel.text != ""
	%BestMovesContainer.visible = bottom_buttons_visible and best_moves_has_text

func _on_undo_button_pressed() -> void:
	if check_goals_and_winnable()[0]:
		return
	if undo_manager.pop_game_state():
		set_game_paused(false)
		game_state = GameState.PLAYING
		%ResultContainer.visible = false
		%TutorialContainer.visible = false
		%UndoResultButton.visible = false
		$PixelCanvas.do_pixelation()
		$Audio/UndoAudioPlayer.play()

func get_grid_scale() -> Vector2:
	return $GridAnchor.scale

func do_fireworks(num:int) -> void:
	camera_target_zoom = 1.0
	camera_target_pos = Vector2.ZERO
	$WorldEnvironment.environment.glow_blend_mode = Environment.GlowBlendMode.GLOW_BLEND_MODE_ADDITIVE
	$Fader.modulate = Color(1,1,1,0)
	$Fader.visible = true
	var tween = create_tween()
	tween.tween_property($Fader, "modulate:a", 0.75, 0.5)
	for i in range(num):
		var new_firework = VFX_FIREWORK.instantiate()
		var spacing = 25.0  # Distance between objects
		var offset = (num - 1) * spacing / 2.0
		var x_position = (i * spacing) - offset
	
		new_firework.position.x = x_position
		$FireworkRoot.add_child(new_firework)
