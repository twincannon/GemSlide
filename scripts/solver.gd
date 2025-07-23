extends Node
class_name PuzzleSolver

# Optimized game state representation
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
		
		# Store entity positions and states more efficiently
		for entity in ents:
			var entity_id = str(entity.entity_type) + "_" + str(entity.entity_id) + "_" + str(entity.grid_pos)
			entity_positions[entity_id] = entity.grid_pos
			
			var state_data = {}
			# Store the moves property - this determines if the entity can move
			state_data["moves"] = entity.moves
			state_data["stuck"] = entity.stuck
			
			if entity is Gem:
				var gem = entity as Gem
				state_data["gem_in_goal"] = gem.gem_in_goal
				state_data["color"] = gem.get_node("ColorComponent").color
			elif entity is Goal:
				var goal = entity as Goal
				state_data["filled"] = goal.filled
				state_data["color"] = goal.get_node("ColorComponent").color
			elif entity is SandTrap:
				var sand = entity as SandTrap
				state_data["moves_to_escape"] = sand.moves_to_escape
			elif entity is WaterHazard:
				state_data["type"] = "water"
			
			entity_states[entity_id] = state_data
	
	func get_hash() -> String:
		var hash_parts = []
		hash_parts.append(str(grid_size))
		hash_parts.append(str(moves))
		
		# Sort entity IDs for consistent hashing
		var sorted_ids = entity_positions.keys()
		sorted_ids.sort()
		
		for entity_id in sorted_ids:
			hash_parts.append(entity_id + ":" + str(entity_positions[entity_id]))
			var state = entity_states[entity_id]
			for key in state.keys():
				hash_parts.append(key + ":" + str(state[key]))
		
		var hash_string = "|".join(hash_parts)
		# Use a simple hash to create a short, safe key
		return str(hash_string.hash())
	
	func is_goal_state() -> bool:
		var all_goals_filled = true
		
		for entity_id in entity_states.keys():
			var state = entity_states[entity_id]
			# Check if this is a goal that's not filled
			if state.has("filled") and !state["filled"]:
				all_goals_filled = false
				break
		
		return all_goals_filled

# A* priority queue with better performance
class AStarQueue:
	var queue: Array[Array] = [] # [f_score, state]
	
	func push(f_score: int, state: GameState):
		queue.append([f_score, state])
		queue.sort_custom(func(a, b): return a[0] < b[0])
	
	func pop() -> GameState:
		if queue.is_empty():
			return null
		return queue.pop_front()[1]
	
	func is_empty() -> bool:
		return queue.is_empty()

var game: Game
var visited_states: Dictionary = {}
var g_scores: Dictionary = {} # cost from start to state
var f_scores: Dictionary = {} # estimated total cost

func _init(game_instance: Game):
	game = game_instance

# A* search algorithm for better performance
func solve_level() -> Array[Vector2i]:
	var initial_state = create_game_state()
	
	if !is_winnable(initial_state):
		print("Level is not winnable!")
		return []
	
	var open_set = AStarQueue.new()
	var start_hash = initial_state.get_hash()
	
	g_scores[start_hash] = 0
	f_scores[start_hash] = heuristic(initial_state)
	open_set.push(f_scores[start_hash], initial_state)
	
	visited_states.clear()
	
	# Safety limits to prevent infinite loops
	var max_states = 10000  # Maximum states to explore
	var max_moves = 100     # Maximum moves to consider
	var states_explored = 0
	
	while !open_set.is_empty() and states_explored < max_states:
		var current_state = open_set.pop()
		var current_hash = current_state.get_hash()
		
		if visited_states.has(current_hash):
			continue
		
		visited_states[current_hash] = current_state
		states_explored += 1
		
		# Check if we've reached the goal
		if current_state.is_goal_state():
			print("Solution found after exploring ", states_explored, " states")
			return reconstruct_path(current_state)
		
		# Check move limit
		if current_state.moves >= max_moves:
			continue
		
		# Try all possible moves
		var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		for direction in directions:
			var new_state = simulate_move(current_state, direction)
			if new_state:
				var new_hash = new_state.get_hash()
				if !visited_states.has(new_hash):
					# Make sure we have a g_score for current_hash before accessing it
					if !g_scores.has(current_hash):
						g_scores[current_hash] = current_state.moves
					
					var tentative_g_score = g_scores[current_hash] + 1
					
					if !g_scores.has(new_hash) or tentative_g_score < g_scores[new_hash]:
						new_state.parent_state = current_state
						new_state.last_move = direction
						
						g_scores[new_hash] = tentative_g_score
						f_scores[new_hash] = tentative_g_score + heuristic(new_state)
						
						open_set.push(f_scores[new_hash], new_state)
	
	if states_explored >= max_states:
		print("Search limit reached (", max_states, " states). No solution found!")
	else:
		print("No solution found after exploring ", states_explored, " states!")
	return []

# Create a game state from the current game
func create_game_state() -> GameState:
	# Safety check
	if game == null:
		print("ERROR: Game is null!")
		return null
	
	if game.entities == null:
		print("ERROR: Game entities is null!")
		return null
	
	print("Creating game state with ", game.entities.size(), " entities")
	return GameState.new(game.grid_size, game.entities, game.moves)

# Check if a level is winnable
func is_winnable(state: GameState) -> bool:
	var goal_dict = {"Red": 0, "Green": 0, "Blue": 0}
	var gem_dict = {"Red": 0, "Green": 0, "Blue": 0}
	
	for entity_id in state.entity_states.keys():
		var entity_state = state.entity_states[entity_id]
		# Count ALL goals (filled and unfilled)
		if entity_state.has("filled"):
			var color = entity_state["color"]
			if color == Globals.COLOR_RED: goal_dict["Red"] += 1
			elif color == Globals.COLOR_GREEN: goal_dict["Green"] += 1
			elif color == Globals.COLOR_BLUE: goal_dict["Blue"] += 1
		# Count ALL gems (in goals and not in goals)
		elif entity_state.has("gem_in_goal"):
			var color = entity_state["color"]
			if color == Globals.COLOR_RED: gem_dict["Red"] += 1
			elif color == Globals.COLOR_GREEN: gem_dict["Green"] += 1
			elif color == Globals.COLOR_BLUE: gem_dict["Blue"] += 1
	
	return gem_dict["Red"] >= goal_dict["Red"] and \
		   gem_dict["Green"] >= goal_dict["Green"] and \
		   gem_dict["Blue"] >= goal_dict["Blue"]

# Heuristic function for A*
func heuristic(state: GameState) -> int:
	var h_score = 0
	
	# Count unfilled goals
	var unfilled_goals = 0
	for entity_id in state.entity_states.keys():
		var entity_state = state.entity_states[entity_id]
		if entity_state.has("filled") and !entity_state["filled"]:
			unfilled_goals += 1
	
	h_score += unfilled_goals * 5
	
	# Add distance-based heuristic
	var gem_positions = []
	var goal_positions = []
	
	for entity_id in state.entity_positions.keys():
		var entity_state = state.entity_states[entity_id]
		var pos = state.entity_positions[entity_id]
		
		# Gems that are not in goals
		if entity_state.has("gem_in_goal") and !entity_state["gem_in_goal"]:
			gem_positions.append({"pos": pos, "color": entity_state["color"]})
		# Goals that are not filled
		elif entity_state.has("filled") and !entity_state["filled"]:
			goal_positions.append({"pos": pos, "color": entity_state["color"]})
	
	# Calculate minimum distance from gems to matching goals
	for gem in gem_positions:
		var min_distance = 999
		for goal in goal_positions:
			if gem["color"] == goal["color"]:
				var distance = abs(gem["pos"].x - goal["pos"].x) + abs(gem["pos"].y - goal["pos"].y)
				min_distance = min(min_distance, distance)
		h_score += min_distance
	
	# Add penalty for stuck entities
	var stuck_entities = 0
	for entity_id in state.entity_states.keys():
		var entity_state = state.entity_states[entity_id]
		if entity_state.has("stuck") and entity_state["stuck"]:
			stuck_entities += 1
	
	h_score += stuck_entities * 3
	
	return h_score

# Simulate a move (simplified version)
func simulate_move(state: GameState, direction: Vector2i) -> GameState:
	var new_state = GameState.new(state.grid_size, [], state.moves + 1)
	
	# Copy current state
	new_state.entity_positions = state.entity_positions.duplicate()
	new_state.entity_states = state.entity_states.duplicate()
	
	# Apply movement logic (simplified)
	var moved_entities = []
	
	for entity_id in new_state.entity_positions.keys():
		var entity_state = new_state.entity_states[entity_id]
		var current_pos = new_state.entity_positions[entity_id]
		var target_pos = current_pos + direction
		
		# Only move entities that have moves = true and are not stuck
		if entity_state.has("moves") and entity_state["moves"] and !entity_state["stuck"]:
			# Check if entity can move
			if can_move_to_position(target_pos, new_state):
				new_state.entity_positions[entity_id] = target_pos
				moved_entities.append(entity_id)
	
	# If no entities moved, this is an invalid state
	if moved_entities.is_empty():
		return null
	
	# Handle post-movement effects
	handle_post_movement_effects(new_state)
	
	return new_state

# Check if an entity can move to a position
func can_move_to_position(pos: Vector2i, state: GameState) -> bool:
	# Check bounds
	if pos.x < 0 or pos.x >= state.grid_size.x or \
	   pos.y < 0 or pos.y >= state.grid_size.y:
		return false
	
	# Check for blocking entities at target position
	for entity_id in state.entity_positions.keys():
		if state.entity_positions[entity_id] == pos:
			var entity_state = state.entity_states[entity_id]
			
			# Goals don't block movement - gems can move onto them
			if entity_state.has("filled"):
				continue # Both filled and unfilled goals don't block
			
			# Other entities block movement
			return false
	
	return true

# Handle post-movement effects
func handle_post_movement_effects(state: GameState):
	var entities_to_remove = []
	
	# Handle goal filling - check if any gems are on goals
	for gem_id in state.entity_positions.keys():
		var gem_state = state.entity_states[gem_id]
		if gem_state.has("gem_in_goal") and !gem_state["gem_in_goal"]:
			var gem_pos = state.entity_positions[gem_id]
			
			# Check if there's a matching goal at this position
			for goal_id in state.entity_positions.keys():
				var goal_state = state.entity_states[goal_id]
				if goal_state.has("filled") and !goal_state["filled"]:
					if state.entity_positions[goal_id] == gem_pos:
						if gem_state["color"] == goal_state["color"]:
							goal_state["filled"] = true
							gem_state["gem_in_goal"] = true
	
	# Handle water hazards
	for entity_id in state.entity_positions.keys():
		var entity_state = state.entity_states[entity_id]
		var pos = state.entity_positions[entity_id]
		
		if entity_state.has("type") and entity_state["type"] == "water":
			for other_id in state.entity_positions.keys():
				if state.entity_positions[other_id] == pos:
					var other_state = state.entity_states[other_id]
					if other_state.has("gem_in_goal"):
						entities_to_remove.append(other_id)
	
	# Remove destroyed entities
	for entity_id in entities_to_remove:
		state.entity_positions.erase(entity_id)
		state.entity_states.erase(entity_id)

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
	print("Starting optimized solver...")
	
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
