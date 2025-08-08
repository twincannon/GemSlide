extends Node
class_name PuzzleSolver

# Enhanced game state representation
class GameState:
	var grid_size: Vector2i
	var entity_positions: Dictionary = {} # entity_id -> position
	var entity_states: Dictionary = {} # entity_id -> state_data
	var moves: int = 0
	var parent_state: GameState = null
	var last_move: Vector2i = Vector2i.ZERO
	
	func _init(size: Vector2i, ents: Array[Entity] = [], move_count: int = 0):
		grid_size = size
		moves = move_count
		
		# Store entity positions and states
		for entity in ents:
			# Create unique entity ID using position to avoid collisions
			var entity_id = str(entity.entity_type) + "_" + str(entity.entity_id) + "_" + str(entity.grid_pos.x) + "_" + str(entity.grid_pos.y)
			entity_positions[entity_id] = entity.grid_pos
			
			var state_data = {}
			state_data["moves"] = entity.moves
			state_data["stuck"] = entity.stuck
			state_data["forces_movement"] = entity.forces_movement
			state_data["entity_id"] = entity.entity_id
			state_data["entity_type"] = entity.entity_type
			
			# Determine entity type based on entity_type enum
			match entity.entity_type:
				Globals.EntityType.BallRed, Globals.EntityType.BallGreen, Globals.EntityType.BallBlue:
					state_data["type"] = "gem"
					if entity is Gem:
						var gem = entity as Gem
						state_data["gem_in_goal"] = gem.gem_in_goal
						# Use entity_type to determine hue instead of reading from ColorComponent
						match entity.entity_type:
							Globals.EntityType.BallRed:
								state_data["hue"] = Globals.hue_red
							Globals.EntityType.BallGreen:
								state_data["hue"] = Globals.hue_green
							Globals.EntityType.BallBlue:
								state_data["hue"] = Globals.hue_blue
				Globals.EntityType.BallBlack:
					state_data["type"] = "black_gem"
				Globals.EntityType.GoalRed, Globals.EntityType.GoalGreen, Globals.EntityType.GoalBlue:
					state_data["type"] = "goal"
					if entity is Goal:
						var goal = entity as Goal
						state_data["filled"] = goal.filled
						# Use entity_type to determine hue instead of reading from ColorComponent
						match entity.entity_type:
							Globals.EntityType.GoalRed:
								state_data["hue"] = Globals.hue_red
							Globals.EntityType.GoalGreen:
								state_data["hue"] = Globals.hue_green
							Globals.EntityType.GoalBlue:
								state_data["hue"] = Globals.hue_blue
				Globals.EntityType.SandTrap:
					state_data["type"] = "sand_trap"
					if entity is SandTrap:
						var sand = entity as SandTrap
						state_data["moves_to_escape"] = sand.moves_to_escape
				Globals.EntityType.WaterHazard:
					state_data["type"] = "water_hazard"
				Globals.EntityType.Teleporter:
					state_data["type"] = "teleporter"
					state_data["teleporter_id"] = entity.entity_id
				Globals.EntityType.IceSlick:
					state_data["type"] = "ice_slick"
				Globals.EntityType.BombRed, Globals.EntityType.BombGreen, Globals.EntityType.BombBlue:
					state_data["type"] = "bomb"
					if entity is Bomb:
						var bomb = entity as Bomb
						state_data["ignited"] = bomb.ignited
						state_data["moves_until_explosion"] = bomb.moves_until_explosion
						state_data["gem_in_goal"] = bomb.gem_in_goal
						# Use entity_type to determine hue instead of reading from ColorComponent
						match entity.entity_type:
							Globals.EntityType.BombRed:
								state_data["hue"] = Globals.hue_red
							Globals.EntityType.BombGreen:
								state_data["hue"] = Globals.hue_green
							Globals.EntityType.BombBlue:
								state_data["hue"] = Globals.hue_blue
				Globals.EntityType.TileBlocker:
					state_data["type"] = "tile_blocker"
				Globals.EntityType.Button:
					state_data["type"] = "pressure_plate"
					if entity is PressurePlate:
						var plate = entity as PressurePlate
						state_data["pressed"] = plate.pressed
			
			entity_states[entity_id] = state_data
	
	func get_hash() -> String:
		# Stable, move-count-independent hash of the logical state.
		var hash_parts: Array[String] = []
		hash_parts.append(str(grid_size))
		# Sort entity IDs for consistent hashing
		var sorted_ids: Array = entity_positions.keys()
		sorted_ids.sort()
		for entity_id in sorted_ids:
			# Position
			hash_parts.append(entity_id + ":" + str(entity_positions[entity_id]))
			# Sort state keys for stable ordering
			var state: Dictionary = entity_states[entity_id]
			var state_keys: Array = state.keys()
			state_keys.sort()
			for key in state_keys:
				hash_parts.append(key + ":" + str(state[key]))
		var hash_string = "|".join(hash_parts)
		return str(hash_string.hash())
	
	func is_goal_state() -> bool:
		var all_goals_filled = true
		
		var _goals_checked = 0
		for entity_id in entity_states.keys():
			var state = entity_states[entity_id]
			if state.has("type") and state["type"] == "goal":
				_goals_checked += 1
				if !state["filled"]:
					all_goals_filled = false
		
		if all_goals_filled:
			print("    GOAL STATE REACHED!")
		return all_goals_filled

# A* priority queue
class AStarQueue:
	var queue: Array[Array] = [] # [f_score, g_score, state]
	
	func push(f_score: int, g_score: int, state: GameState):
		queue.append([f_score, g_score, state])
		queue.sort_custom(func(a, b): 
			if a[0] != b[0]:
				return a[0] < b[0]  # Primary sort by f_score
			else:
				return a[1] > b[1]  # Secondary sort by g_score (prefer shorter paths)
		)
	
	func pop() -> GameState:
		if queue.is_empty():
			return null
		return queue.pop_front()[2]
	
	func is_empty() -> bool:
		return queue.is_empty()

var game: Game
var visited_states: Dictionary = {}
var g_scores: Dictionary = {} # cost from start to state
var f_scores: Dictionary = {} # estimated total cost

func _init(game_instance: Game):
	game = game_instance

# Enhanced A* search algorithm
func solve_level() -> Array[Vector2i]:
	var initial_state = create_game_state()
	
	if !is_winnable(initial_state):
		print("Level is not winnable!")
		return []
	
	var open_set = AStarQueue.new()
	var start_hash = initial_state.get_hash()
	
	g_scores[start_hash] = 0
	f_scores[start_hash] = heuristic(initial_state)
	open_set.push(f_scores[start_hash], g_scores[start_hash], initial_state)
	
	visited_states.clear()
	
	# Safety limits
	var max_states = 1000
	var max_moves = 200
	var states_explored = 0
	
	# Solution tracking (not needed for optimal A*)
	
	while !open_set.is_empty() and states_explored < max_states:
		var current_state = open_set.pop()
		var current_hash = current_state.get_hash()
		
		if visited_states.has(current_hash):
			continue
		
		visited_states[current_hash] = current_state
		states_explored += 1
		
			# Check if we've reached the goal
		if current_state.is_goal_state():
			var solution = reconstruct_path(current_state)
			print("Solution found after exploring ", states_explored, " states (", current_state.moves, " moves)")
			print("With admissible heuristic, this should be optimal!")
			return solution
		
		# (Debug output trimmed for performance)
		
		# Check move limit
		if current_state.moves >= max_moves:
			continue
		
		# Try all possible moves (prune immediate backtracks)
		var directions = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
		for direction in directions:
			if current_state.last_move != Vector2i.ZERO and direction == -current_state.last_move:
				continue
			var new_state = simulate_move(current_state, direction)
			if new_state:
				var new_hash = new_state.get_hash()
				if !visited_states.has(new_hash):
					if !g_scores.has(current_hash):
						g_scores[current_hash] = current_state.moves
					
					var tentative_g_score = g_scores[current_hash] + 1
					
					if !g_scores.has(new_hash) or tentative_g_score < g_scores[new_hash]:
						new_state.parent_state = current_state
						new_state.last_move = direction
						
						g_scores[new_hash] = tentative_g_score
						f_scores[new_hash] = tentative_g_score + heuristic(new_state)
						
						open_set.push(f_scores[new_hash], g_scores[new_hash], new_state)
	
	if states_explored >= max_states:
		print("Search limit reached (", max_states, " states). No solution found!")
	else:
		print("No solution found after exploring ", states_explored, " states!")
	return []

# Create a game state from the current game
func create_game_state() -> GameState:
	if game == null:
		print("ERROR: Game is null!")
		return null
	
	if game.entities == null:
		print("ERROR: Game entities is null!")
		return null
	
	# (Debug logging removed for performance)
	
	var initial_state = GameState.new(game.grid_size, game.entities, game.moves)
	
	# (Initial layout debug removed)
	
	return initial_state

# Check if a level is winnable
func is_winnable(state: GameState) -> bool:
	var goal_dict = {"Red": 0, "Green": 0, "Blue": 0}
	var gem_dict = {"Red": 0, "Green": 0, "Blue": 0}
	
	for entity_id in state.entity_states.keys():
		var entity_state = state.entity_states[entity_id]
		# Count ALL goals (filled and unfilled)
		if entity_state.has("type") and entity_state["type"] == "goal":
			var color = entity_state["hue"]
			if color == Globals.hue_red: goal_dict["Red"] += 1
			elif color == Globals.hue_green: goal_dict["Green"] += 1
			elif color == Globals.hue_blue: goal_dict["Blue"] += 1
		# Count ALL gems (in goals and not in goals)
		elif entity_state.has("type") and (entity_state["type"] == "gem" or entity_state["type"] == "bomb"):
			var color = entity_state["hue"]
			if color == Globals.hue_red: gem_dict["Red"] += 1
			elif color == Globals.hue_green: gem_dict["Green"] += 1
			elif color == Globals.hue_blue: gem_dict["Blue"] += 1
	
	var winnable = gem_dict["Red"] >= goal_dict["Red"] and \
		   gem_dict["Green"] >= goal_dict["Green"] and \
		   gem_dict["Blue"] >= goal_dict["Blue"]
	
	return winnable

# Enhanced heuristic function
func heuristic(state: GameState) -> int:
	# Admissible heuristic: sum of Manhattan distances from each unfixed gem/bomb
	# to the nearest matching-color unfilled goal.
	var h_score = 0
	var gem_positions: Array = []
	var goal_positions: Array = []
	for entity_id in state.entity_positions.keys():
		var entity_state: Dictionary = state.entity_states[entity_id]
		var pos: Vector2i = state.entity_positions[entity_id]
		if entity_state.has("type") and (entity_state["type"] == "gem" or entity_state["type"] == "bomb") and !entity_state.get("gem_in_goal", false):
			gem_positions.append({"pos": pos, "hue": entity_state.get("hue", 0.0)})
		elif entity_state.has("type") and entity_state["type"] == "goal" and !entity_state.get("filled", false):
			goal_positions.append({"pos": pos, "hue": entity_state.get("hue", 0.0)})
	for gem in gem_positions:
		var min_distance = 1000000
		for goal in goal_positions:
			if gem["hue"] == goal["hue"]:
				var distance = abs(gem["pos"].x - goal["pos"].x) + abs(gem["pos"].y - goal["pos"].y)
				if distance < min_distance:
					min_distance = distance
		if min_distance < 1000000:
			h_score += min_distance
	return h_score

# Enhanced move simulation
func simulate_move(state: GameState, direction: Vector2i) -> GameState:
	var new_state = GameState.new(state.grid_size, [], state.moves + 1)
	
	# Deep copy current state
	new_state.entity_positions = {}
	new_state.entity_states = {}
	for entity_id in state.entity_positions.keys():
		new_state.entity_positions[entity_id] = state.entity_positions[entity_id]
		new_state.entity_states[entity_id] = state.entity_states[entity_id].duplicate()
	
	# Track entities that will free themselves from sand after this move
	var will_unstuck: Array[String] = []
	for entity_id in new_state.entity_positions.keys():
		var e_state: Dictionary = new_state.entity_states[entity_id]
		if e_state.get("stuck", false) and e_state.get("moves", false):
			var cur_pos: Vector2i = new_state.entity_positions[entity_id]
			var next_pos: Vector2i = cur_pos + direction
			if can_move_to_position(next_pos, new_state, entity_id):
				# Free on next turn, not this one
				will_unstuck.append(entity_id)
	
	# Get all movable entities
	var movable_entities = []
	for entity_id in new_state.entity_positions.keys():
		var entity_state = new_state.entity_states[entity_id]
		if entity_state.has("moves") and entity_state["moves"] and !entity_state["stuck"]:
			if !entity_state.has("gem_in_goal") or (entity_state.has("gem_in_goal") and !entity_state["gem_in_goal"]):
				movable_entities.append(entity_id)
	
	# Sort entities by position (similar to game logic)
	movable_entities.sort_custom(func(a, b): 
		var pos_a = new_state.entity_positions[a]
		var pos_b = new_state.entity_positions[b]
		var pos1 = pos_a.x + pos_a.y * new_state.grid_size.y
		var pos2 = pos_b.x + pos_b.y * new_state.grid_size.y
		return pos1 < pos2
	)
	
	# Reverse for RIGHT and DOWN directions
	if direction == Vector2i.RIGHT or direction == Vector2i.DOWN:
		movable_entities.reverse()
	
	# Apply movement
	var moved_entities = []
	for entity_id in movable_entities:
		var _entity_state = new_state.entity_states[entity_id]
		var current_pos = new_state.entity_positions[entity_id]
		var target_pos = current_pos + direction
		
		# Check if entity can move
		if can_move_to_position(target_pos, new_state, entity_id):
			new_state.entity_positions[entity_id] = target_pos
			moved_entities.append(entity_id)
			
			# Handle ice slick movement
			var is_on_ice = false
			for other_id in new_state.entity_positions.keys():
				if new_state.entity_positions[other_id] == target_pos:
					var other_state = new_state.entity_states[other_id]
					if other_state.has("type") and other_state["type"] == "ice_slick":
						is_on_ice = true
						break
			
			# Continue moving on ice
			while is_on_ice:
				var next_pos = new_state.entity_positions[entity_id] + direction
				if can_move_to_position(next_pos, new_state, entity_id):
					new_state.entity_positions[entity_id] = next_pos
					
					# Check if still on ice
					is_on_ice = false
					for other_id in new_state.entity_positions.keys():
						if new_state.entity_positions[other_id] == next_pos:
							var other_state = new_state.entity_states[other_id]
							if other_state.has("type") and other_state["type"] == "ice_slick":
								is_on_ice = true
								break
				else:
					is_on_ice = false
	
	# If no entities moved, this is an invalid state
	if moved_entities.is_empty():
		return null
	
	# Handle post-movement effects
	handle_post_movement_effects(new_state)

	# Apply sand trap release after movement resolution, matching game timing
	for eid in will_unstuck:
		if new_state.entity_states.has(eid):
			new_state.entity_states[eid]["stuck"] = false
	
	return new_state

# Enhanced position checking
func can_move_to_position(pos: Vector2i, state: GameState, moving_entity_id: String) -> bool:
	# Check bounds
	if pos.x < 0 or pos.x >= state.grid_size.x or \
	   pos.y < 0 or pos.y >= state.grid_size.y:
		return false
	
	# Check for blocking entities at target position
	for entity_id in state.entity_positions.keys():
		if state.entity_positions[entity_id] == pos:
			var entity_state = state.entity_states[entity_id]
			var moving_entity_state = state.entity_states[moving_entity_id]
			
			# Goals block movement for gems of different colors
			if entity_state.has("type") and entity_state["type"] == "goal":
				if !entity_state["filled"]:
					# Black gems cannot enter goals
					if moving_entity_state.has("type") and moving_entity_state["type"] == "black_gem":
						return false
					# Check if the moving entity is a gem and if colors match
					if moving_entity_state.has("type") and moving_entity_state["type"] == "gem":
						if moving_entity_state["hue"] != entity_state["hue"]:
							return false # Different color gem blocked by goal
						else:
							# Same color gem can move onto goal
							continue
				# Filled goals don't block movement
				continue
			
			# Ice slicks don't block movement
			if entity_state.has("type") and entity_state["type"] == "ice_slick":
				continue
			
			# Sand traps don't block movement
			if entity_state.has("type") and entity_state["type"] == "sand_trap":
				continue
			
			# Teleporters don't block movement
			if entity_state.has("type") and entity_state["type"] == "teleporter":
				continue
			
			# Water hazards don't block movement
			if entity_state.has("type") and entity_state["type"] == "water_hazard":
				continue
			
			# Pressure plates don't block movement
			if entity_state.has("type") and entity_state["type"] == "pressure_plate":
				continue
			
			# Other entities block movement
			return false
	
	return true

# Enhanced post-movement effects
func handle_post_movement_effects(state: GameState):
	var entities_to_remove = []
	
	# Handle goal filling
	for gem_id in state.entity_positions.keys():
		var gem_state = state.entity_states[gem_id]
		if gem_state.has("type") and (gem_state["type"] == "gem" or gem_state["type"] == "bomb") and !gem_state["gem_in_goal"]:
			var gem_pos = state.entity_positions[gem_id]
			
			# Check if there's a matching goal at this position
			for goal_id in state.entity_positions.keys():
				var goal_state = state.entity_states[goal_id]
				if goal_state.has("type") and goal_state["type"] == "goal" and !goal_state["filled"]:
					if state.entity_positions[goal_id] == gem_pos:
						if gem_state["hue"] == goal_state["hue"]:
							goal_state["filled"] = true
							gem_state["gem_in_goal"] = true
							# Mark the gem as stuck so it can't move away from the goal
							gem_state["stuck"] = true
							# Remove both gem and goal to shrink state space
							entities_to_remove.append(gem_id)
							entities_to_remove.append(goal_id)
							# Ignite bombs of matching color (mirrors game logic)
							ignite_bombs_of_hue(state, goal_state.get("hue", 0.0))
							# Break out of the inner loop since this gem can only fill one goal
							break
	
	# Handle water hazards (remove gems, bombs, and black gems)
	for entity_id in state.entity_positions.keys():
		var entity_state = state.entity_states[entity_id]
		var pos = state.entity_positions[entity_id]
		
		if entity_state.has("type") and entity_state["type"] == "water_hazard":
			for other_id in state.entity_positions.keys():
				if state.entity_positions[other_id] == pos:
					var other_state = state.entity_states[other_id]
					if other_state.has("type") and (other_state["type"] == "gem" or other_state["type"] == "bomb" or other_state["type"] == "black_gem"):
						entities_to_remove.append(other_id)
	
	# Handle sand traps
	for entity_id in state.entity_positions.keys():
		var entity_state = state.entity_states[entity_id]
		var pos = state.entity_positions[entity_id]
		
		if entity_state.has("type") and entity_state["type"] == "sand_trap":
			for other_id in state.entity_positions.keys():
				if state.entity_positions[other_id] == pos:
					var other_state = state.entity_states[other_id]
					if other_state.has("type") and (other_state["type"] == "gem" or other_state["type"] == "bomb" or other_state["type"] == "black_gem"):
						other_state["stuck"] = true
	
	# Handle teleporters (mirror game's pairing rules)
	var teleporter_ids: Array = []
	for entity_id in state.entity_positions.keys():
		if state.entity_states[entity_id].get("type", "") == "teleporter":
			teleporter_ids.append(entity_id)
	for tele_id in teleporter_ids:
		# Iterate per source teleporter and move any gems/bombs standing on it
		var src_pos: Vector2i = state.entity_positions[tele_id]
		var dest_id: String = find_destination_teleporter_id(state, tele_id)
		if dest_id == "":
			continue
		var dest_pos: Vector2i = state.entity_positions[dest_id]
		# Teleport any gems/bombs at this teleporter's position
		var moving_ids: Array = []
		for eid in state.entity_positions.keys():
			if state.entity_positions[eid] == src_pos:
				var e_state = state.entity_states[eid]
				if e_state.has("type") and (e_state["type"] == "gem" or e_state["type"] == "bomb"):
					moving_ids.append(eid)
		for mid in moving_ids:
			state.entity_positions[mid] = dest_pos
			# Note: game visually teleports immediately and finalizes after movement; logically position is updated here
	
	# Handle pressure plates
	for entity_id in state.entity_positions.keys():
		var entity_state = state.entity_states[entity_id]
		var pos = state.entity_positions[entity_id]
		
		if entity_state.has("type") and entity_state["type"] == "pressure_plate":
			# Check if any gem is on this pressure plate
			var has_gem = false
			for other_id in state.entity_positions.keys():
				if state.entity_positions[other_id] == pos:
					var other_state = state.entity_states[other_id]
					if other_state.has("type") and (other_state["type"] == "gem" or other_state["type"] == "bomb"):
						has_gem = true
						break
			
			if has_gem and !entity_state["pressed"]:
				entity_state["pressed"] = true
				# Activate entities with matching ID
				for other_id in state.entity_positions.keys():
					var other_state = state.entity_states[other_id]
					if other_state.has("entity_id") and other_state["entity_id"] == entity_state.get("entity_id"):
						# Handle activation effects (could be teleporters, etc.)
						pass
	
	# Handle bomb countdown and explosions
	var bombs_ready_to_explode: Array = []
	for entity_id in state.entity_positions.keys():
		var b_state = state.entity_states[entity_id]
		if b_state.get("type", "") == "bomb" and b_state.get("ignited", false) and !b_state.get("gem_in_goal", false):
			if b_state.get("moves_until_explosion", -1) > 0:
				b_state["moves_until_explosion"] -= 1
			if b_state.get("moves_until_explosion", -1) == 0:
				bombs_ready_to_explode.append(entity_id)
	# Resolve explosions simultaneously
	if bombs_ready_to_explode.size() > 0:
		# Remove exploded bombs
		for bid in bombs_ready_to_explode:
			entities_to_remove.append(bid)
		# Accumulate pushes and destructions
		var net_push: Dictionary = {} # entity_id -> Vector2i
		for bid in bombs_ready_to_explode:
			var bomb_pos: Vector2i = state.entity_positions[bid]
			for other_id in state.entity_positions.keys():
				if other_id == bid:
					continue
				var other_pos: Vector2i = state.entity_positions[other_id]
				if is_adjacent(bomb_pos, other_pos):
					var o_state = state.entity_states[other_id]
					if o_state.get("type", "") == "black_gem":
						entities_to_remove.append(other_id)
					elif o_state.has("moves") and o_state["moves"] and o_state.get("type", "") != "bomb":
						var dir: Vector2i = other_pos - bomb_pos
						if !net_push.has(other_id):
							net_push[other_id] = Vector2i.ZERO
						net_push[other_id] += dir
		# Apply net pushes one tile in the direction of the net vector (cardinal)
		for eid in net_push.keys():
			var push_vec: Vector2i = net_push[eid]
			# Reduce to cardinal direction
			var final_dir: Vector2i = Vector2i(int(clamp(push_vec.x, -1, 1)), int(clamp(push_vec.y, -1, 1)))
			if final_dir != Vector2i.ZERO:
				var new_pos = state.entity_positions[eid] + final_dir
				if can_move_to_position(new_pos, state, eid):
					state.entity_positions[eid] = new_pos
	
	# Remove destroyed entities
	for entity_id in entities_to_remove:
		state.entity_positions.erase(entity_id)
		state.entity_states.erase(entity_id)


# Ignite bombs of a given hue (called when a goal of that hue is filled)
func ignite_bombs_of_hue(state: GameState, hue: float) -> void:
	for entity_id in state.entity_states.keys():
		var st: Dictionary = state.entity_states[entity_id]
		if st.get("type", "") == "bomb" and !st.get("gem_in_goal", false):
			if st.get("hue", -999.0) == hue or st.get("moves_until_explosion", -1) >= 0:
				st["ignited"] = true
				st["moves_until_explosion"] = 1


# Teleporter destination per game's rules
func find_destination_teleporter_id(state: GameState, src_entity_id: String) -> String:
	var src_state: Dictionary = state.entity_states[src_entity_id]
	var src_tid: int = int(src_state.get("teleporter_id", -999999))
	# 1) Same id
	for eid in state.entity_states.keys():
		if eid == src_entity_id:
			continue
		var st: Dictionary = state.entity_states[eid]
		if st.get("type", "") == "teleporter" and int(st.get("teleporter_id", -999999)) == src_tid:
			return eid
	# 2) id + 1
	for eid in state.entity_states.keys():
		if eid == src_entity_id:
			continue
		var st2: Dictionary = state.entity_states[eid]
		if st2.get("type", "") == "teleporter" and int(st2.get("teleporter_id", -999999)) == src_tid + 1:
			return eid
	# 3) lowest id
	var lowest_id: int = 2_147_483_647
	var lowest_eid: String = ""
	for eid in state.entity_states.keys():
		if eid == src_entity_id:
			continue
		var st3: Dictionary = state.entity_states[eid]
		if st3.get("type", "") == "teleporter":
			var tid = int(st3.get("teleporter_id", 2_147_483_647))
			if tid < lowest_id:
				lowest_id = tid
				lowest_eid = eid
	return lowest_eid

# Helper function to check if two positions are adjacent
func is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	var diff = pos1 - pos2
	return abs(diff.x) + abs(diff.y) == 1

# Reconstruct the solution path
func reconstruct_path(goal_state: GameState) -> Array[Vector2i]:
	var path:Array[Vector2i] = []
	var current_state = goal_state
	
	while current_state.parent_state != null:
		path.push_front(current_state.last_move)
		current_state = current_state.parent_state
	
	return path

# Public function to solve the current level
func solve() -> Array[Vector2i]:
	print("Starting enhanced solver...")
	
	# Safety check
	if game == null:
		print("ERROR: Game is null!")
		return []
	
	var start_time = Time.get_time_dict_from_system()
	
	var solution = solve_level()
	
	var end_time = Time.get_time_dict_from_system()
	var elapsed = (end_time.hour - start_time.hour) * 3600 + \
				  (end_time.minute - start_time.minute) * 60 + \
				  (end_time.second - start_time.second)
	
	print("Solver completed in ", elapsed, " seconds")
	print("States explored: ", visited_states.size())
	
	if solution.size() > 0:
		print("Solution found in ", solution.size(), " moves!")
		for i in range(solution.size()):
			var dir = solution[i]
			var dir_name = ""
			if dir == Vector2i.UP: dir_name = "UP"
			elif dir == Vector2i.DOWN: dir_name = "DOWN"
			elif dir == Vector2i.LEFT: dir_name = "LEFT"
			elif dir == Vector2i.RIGHT: dir_name = "RIGHT"
			print("Move ", i + 1, ": ", dir_name)
	else:
		print("No solution found!")
	
	return solution 
