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
		return str(hash_string.hash())
	
	func is_goal_state() -> bool:
		var all_goals_filled = true
		
		var goals_checked = 0
		for entity_id in entity_states.keys():
			var state = entity_states[entity_id]
			if state.has("type") and state["type"] == "goal":
				goals_checked += 1
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
	var max_states = 500  # Increased limit for complex puzzles
	var max_moves = 200     # Increased move limit
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
		
		# Debug: Print progress every 100 states
		if states_explored % 100 == 0:
			print("Explored ", states_explored, " states, current f_score: ", f_scores[current_hash], " (g=", g_scores[current_hash], ", h=", f_scores[current_hash] - g_scores[current_hash], ")")
			# Show current state layout
			print("  Current state layout:")
			for y in range(current_state.grid_size.y):
				var row = ""
				for x in range(current_state.grid_size.x):
					var pos = Vector2i(x, y)
					var entity_found = false
					for entity_id in current_state.entity_positions.keys():
						if current_state.entity_positions[entity_id] == pos:
							var entity_state = current_state.entity_states[entity_id]
							if entity_state.has("type"):
								if entity_state["type"] == "gem":
									row += "G"
								elif entity_state["type"] == "goal":
									row += "O"
								elif entity_state["type"] == "tile_blocker":
									row += "X"
								elif entity_state["type"] == "black_gem":
									row += "B"
								elif entity_state["type"] == "bomb":
									row += "M"
								else:
									row += "?"
									print("    Unknown entity type at ", pos, ": ", entity_state["type"])
							entity_found = true
							break
					if !entity_found:
						row += "."
				print("    ", row)
		
		# Check move limit
		if current_state.moves >= max_moves:
			continue
		
		# Try all possible moves (prioritize directions that are more likely to lead to goals)
		var directions = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
		for direction in directions:
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
	
	print("Creating game state with ", game.entities.size(), " entities")
	
	# Debug: Print entity details
	for entity in game.entities:
		print("Entity: type=", entity.entity_type, " (", Globals.EntityType.keys()[entity.entity_type], ") pos=", entity.grid_pos, " moves=", entity.moves)
		if entity is Gem:
			var gem_hue = 0.0
			match entity.entity_type:
				Globals.EntityType.BallRed: gem_hue = Globals.hue_red
				Globals.EntityType.BallGreen: gem_hue = Globals.hue_green
				Globals.EntityType.BallBlue: gem_hue = Globals.hue_blue
			print("  - Gem: in_goal=", entity.gem_in_goal, " hue=", gem_hue)
		elif entity is Goal:
			var goal_hue = 0.0
			match entity.entity_type:
				Globals.EntityType.GoalRed: goal_hue = Globals.hue_red
				Globals.EntityType.GoalGreen: goal_hue = Globals.hue_green
				Globals.EntityType.GoalBlue: goal_hue = Globals.hue_blue
			print("  - Goal: filled=", entity.filled, " hue=", goal_hue)
	
	# Debug: Print expected vs actual entity types
	print("Expected entities from level data:")
	#print(typeof(Globals.current_level_data))
	var level_data = Globals.current_level_data.get_data()
	if level_data and level_data.has("Entities"):
		for i in range(level_data["Entities"].size()):
			var entity_type = level_data["Entities"][i]
			if entity_type != 0:  # Skip empty positions
				print("  Position ", i, ": ", Globals.EntityType.keys()[entity_type])
	
	var initial_state = GameState.new(game.grid_size, game.entities, game.moves)
	
	# Debug: Show initial state layout
	print("Initial state layout:")
	for y in range(initial_state.grid_size.y):
		var row = ""
		for x in range(initial_state.grid_size.x):
			var pos = Vector2i(x, y)
			var entity_found = false
			for entity_id in initial_state.entity_positions.keys():
				if initial_state.entity_positions[entity_id] == pos:
					var entity_state = initial_state.entity_states[entity_id]
					if entity_state.has("type"):
						if entity_state["type"] == "gem":
							row += "G"
						elif entity_state["type"] == "goal":
							row += "O"
						elif entity_state["type"] == "tile_blocker":
							row += "X"
						elif entity_state["type"] == "black_gem":
							row += "B"
						elif entity_state["type"] == "bomb":
							row += "M"
						else:
							row += "?"
							print("  Unknown entity type at ", pos, ": ", entity_state["type"])
					entity_found = true
					break
			if !entity_found:
				row += "."
		print("  ", row)
	
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
	var h_score = 0
	
	# Count unfilled goals
	var unfilled_goals = 0
	for entity_id in state.entity_states.keys():
		var entity_state = state.entity_states[entity_id]
		if entity_state.has("type") and entity_state["type"] == "goal" and !entity_state["filled"]:
			unfilled_goals += 1
	
	# Don't add penalty for unfilled goals - just use distance heuristic
	
	# Add distance-based heuristic with better weighting
	var gem_positions = []
	var goal_positions = []
	
	for entity_id in state.entity_positions.keys():
		var entity_state = state.entity_states[entity_id]
		var pos = state.entity_positions[entity_id]
		
		# Gems that are not in goals
		if entity_state.has("type") and (entity_state["type"] == "gem" or entity_state["type"] == "bomb") and !entity_state["gem_in_goal"]:
			gem_positions.append({"pos": pos, "hue": entity_state["hue"]})
		# Goals that are not filled
		elif entity_state.has("type") and entity_state["type"] == "goal" and !entity_state["filled"]:
			goal_positions.append({"pos": pos, "hue": entity_state["hue"]})
	
	# Calculate minimum distance from gems to matching goals
	for gem in gem_positions:
		var min_distance = 999
		var found_matching_goal = false
		for goal in goal_positions:
			if gem["hue"] == goal["hue"]:
				var distance = abs(gem["pos"].x - goal["pos"].x) + abs(gem["pos"].y - goal["pos"].y)
				min_distance = min(min_distance, distance)
				found_matching_goal = true
		# Only add distance if there's a matching goal, otherwise the gem is already in a goal
		if found_matching_goal:
			h_score += min_distance * 1  # Lower weight to ensure admissibility
	

	
	# Add penalty for stuck entities
	var stuck_entities = 0
	for entity_id in state.entity_states.keys():
		var entity_state = state.entity_states[entity_id]
		if entity_state.has("stuck") and entity_state["stuck"]:
			stuck_entities += 1
	
	h_score += stuck_entities * 5
	
	# Add penalty for ignited bombs
	var ignited_bombs = 0
	for entity_id in state.entity_states.keys():
		var entity_state = state.entity_states[entity_id]
		if entity_state.has("type") and entity_state["type"] == "bomb" and entity_state["ignited"]:
			ignited_bombs += 1
	
	h_score += ignited_bombs * 15
	
	# Debug: Print heuristic breakdown for first few states
	if state.moves < 3:
		print("  Heuristic for state with ", state.moves, " moves: ", h_score, " (unfilled_goals=", unfilled_goals, ", distance=", h_score - stuck_entities * 5 - ignited_bombs * 15, ")")
	
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
		var entity_state = new_state.entity_states[entity_id]
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
							entities_to_remove.append(gem_id)
							entities_to_remove.append(goal_id) # May as well remove the goal too
							# Break out of the inner loop since this gem can only fill one goal
							break
	
	# Handle water hazards
	for entity_id in state.entity_positions.keys():
		var entity_state = state.entity_states[entity_id]
		var pos = state.entity_positions[entity_id]
		
		if entity_state.has("type") and entity_state["type"] == "water_hazard":
			for other_id in state.entity_positions.keys():
				if state.entity_positions[other_id] == pos:
					var other_state = state.entity_states[other_id]
					if other_state.has("type") and (other_state["type"] == "gem" or other_state["type"] == "bomb"):
						entities_to_remove.append(other_id)
	
	# Handle sand traps
	for entity_id in state.entity_positions.keys():
		var entity_state = state.entity_states[entity_id]
		var pos = state.entity_positions[entity_id]
		
		if entity_state.has("type") and entity_state["type"] == "sand_trap":
			for other_id in state.entity_positions.keys():
				if state.entity_positions[other_id] == pos:
					var other_state = state.entity_states[other_id]
					if other_state.has("type") and (other_state["type"] == "gem" or other_state["type"] == "bomb"):
						other_state["stuck"] = true
	
	# Handle teleporters
	for entity_id in state.entity_positions.keys():
		var entity_state = state.entity_states[entity_id]
		var pos = state.entity_positions[entity_id]
		
		if entity_state.has("type") and entity_state["type"] == "teleporter":
			var teleporter_id = entity_state["teleporter_id"]
			
			# Find destination teleporter
			for other_id in state.entity_positions.keys():
				var other_state = state.entity_states[other_id]
				if other_state.has("type") and other_state["type"] == "teleporter" and other_state["teleporter_id"] == teleporter_id:
					if other_id != entity_id: # Different teleporter
						var dest_pos = state.entity_positions[other_id]
						
						# Teleport any gems at this position
						for gem_id in state.entity_positions.keys():
							if state.entity_positions[gem_id] == pos:
								var gem_state = state.entity_states[gem_id]
								if gem_state.has("type") and (gem_state["type"] == "gem" or gem_state["type"] == "bomb"):
									state.entity_positions[gem_id] = dest_pos
						break
	
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
	for entity_id in state.entity_positions.keys():
		var entity_state = state.entity_states[entity_id]
		if entity_state.has("type") and entity_state["type"] == "bomb" and entity_state["ignited"] and !entity_state["gem_in_goal"]:
			# Decrement countdown
			if entity_state["moves_until_explosion"] > 0:
				entity_state["moves_until_explosion"] -= 1
			
			# Explode if countdown reaches 0
			if entity_state["moves_until_explosion"] == 0:
				# Simulate bomb explosion
				var bomb_pos = state.entity_positions[entity_id]
				entities_to_remove.append(entity_id)
				
				# Push adjacent entities
				for other_id in state.entity_positions.keys():
					if other_id != entity_id:
						var other_pos = state.entity_positions[other_id]
						if is_adjacent(bomb_pos, other_pos):
							var other_state = state.entity_states[other_id]
							if other_state.has("type") and other_state["type"] == "black_gem":
								entities_to_remove.append(other_id)
							elif other_state.has("type") and (other_state["type"] == "gem" or other_state["type"] == "bomb"):
								var push_dir = other_pos - bomb_pos
								var new_pos = other_pos + push_dir
								if can_move_to_position(new_pos, state, other_id):
									state.entity_positions[other_id] = new_pos
	
	# Remove destroyed entities
	for entity_id in entities_to_remove:
		state.entity_positions.erase(entity_id)
		state.entity_states.erase(entity_id)

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
