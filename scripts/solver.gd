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
						state_data["queue_ignite"] = bomb.queue_ignite
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
				Globals.EntityType.Boulder:
					state_data["type"] = "boulder"
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

# Safety limits. The time limit is the real stopping condition; max_states is
# just a memory backstop and should rarely (if ever) be hit before the timer.
const SOLVE_TIME_LIMIT_MS := 10000
const MAX_STATES := 300000
const MAX_MOVES := 200
const MAX_EXPLOSION_CASCADE_STEPS := 20 # guards against a pathological chain of bomb explosions

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

	var states_explored = 0
	var start_ticks := Time.get_ticks_msec()

	while !open_set.is_empty() and states_explored < MAX_STATES:
		if Time.get_ticks_msec() - start_ticks > SOLVE_TIME_LIMIT_MS:
			print("Solve time limit reached (", SOLVE_TIME_LIMIT_MS, "ms) after exploring ", states_explored, " states. No solution found!")
			return []

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

		# Check move limit
		if current_state.moves >= MAX_MOVES:
			continue

		# Try all possible moves. Note: we deliberately do NOT prune immediate
		# reversals of the last move here. That's a common sliding-puzzle
		# optimization, but it's unsound in this game: a move can trigger a
		# one-way side effect (a bomb exploding and destroying a boulder, a
		# gem settling into a goal) that means moving back in the opposite
		# direction next does NOT undo it - it can be a required part of the
		# solution. Duplicate states are still caught by the visited_states
		# hash check below regardless.
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

	if states_explored >= MAX_STATES:
		print("Search limit reached (", MAX_STATES, " states). No solution found!")
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

	var initial_state = GameState.new(game.grid_size, game.entities, game.moves)

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

# Simulate one player-input move: slide every movable entity in `direction`,
# then resolve everything that move triggers (goal fills, hazards, bomb
# ignition/explosion cascades) the same way Game.move_entities() /
# Game.on_all_movement_finished() do for the real game.
func simulate_move(state: GameState, direction: Vector2i) -> GameState:
	var new_state = GameState.new(state.grid_size, [], state.moves + 1)

	# Deep copy current state
	new_state.entity_positions = {}
	new_state.entity_states = {}
	for entity_id in state.entity_positions.keys():
		new_state.entity_positions[entity_id] = state.entity_positions[entity_id]
		new_state.entity_states[entity_id] = state.entity_states[entity_id].duplicate()

	# Track entities that will free themselves from sand after this move.
	# Mirrors SandTrap.pre_move(), which is (perhaps confusingly) evaluated
	# against the entity's un-moved grid_pos, since a stuck entity never
	# actually relocates via the normal movement step below.
	var will_unstuck: Array[String] = []
	for entity_id in new_state.entity_positions.keys():
		var e_state: Dictionary = new_state.entity_states[entity_id]
		if e_state.get("stuck", false) and e_state.get("moves", false):
			var cur_pos: Vector2i = new_state.entity_positions[entity_id]
			if can_move_to_position(cur_pos + direction, new_state, entity_id):
				will_unstuck.append(entity_id)

	# Everything that moves under player input this turn
	var pending: Dictionary = {}
	for entity_id in new_state.entity_positions.keys():
		var entity_state = new_state.entity_states[entity_id]
		if entity_state.get("moves", false) and !entity_state.get("stuck", false) and !entity_state.get("gem_in_goal", false):
			pending[entity_id] = direction

	var moved_ids: Array = apply_pending_moves(new_state, pending)

	# Apply sand trap release after movement resolution, matching game timing
	for eid in will_unstuck:
		if new_state.entity_states.has(eid):
			new_state.entity_states[eid]["stuck"] = false

	# If no entities moved, this is an invalid (no-op) move
	if moved_ids.is_empty():
		return null

	resolve_post_movement_cascade(new_state, moved_ids)

	return new_state

# Applies a set of {entity_id: direction} moves to `state`, respecting
# blocking and ice-slick-style "forces_movement" chaining, in the same
# leading-entity-first order Game.move_entities()/sort_ents_by_push_direction
# use. Works for both a normal directional move (all directions equal) and a
# bomb-explosion push (directions may differ per entity). Returns the ids of
# entities that actually moved.
func apply_pending_moves(state: GameState, pending: Dictionary) -> Array:
	if pending.is_empty():
		return []

	var ids: Array = pending.keys()
	ids.sort_custom(func(a, b):
		var da: Vector2i = pending[a]
		var db: Vector2i = pending[b]
		if da == db:
			var pa: Vector2i = state.entity_positions[a]
			var pb: Vector2i = state.entity_positions[b]
			var pos1 = pa.x + pa.y * state.grid_size.y
			var pos2 = pb.x + pb.y * state.grid_size.y
			if da == Vector2i.RIGHT or da == Vector2i.DOWN:
				return pos1 > pos2
			return pos1 < pos2
		var pr1 = da.x + da.y * 2
		var pr2 = db.x + db.y * 2
		return pr1 < pr2
	)

	var moved_ids: Array = []
	for entity_id in ids:
		var dir: Vector2i = pending[entity_id]
		var target_pos: Vector2i = state.entity_positions[entity_id] + dir
		if !can_move_to_position(target_pos, state, entity_id):
			continue
		state.entity_positions[entity_id] = target_pos

		# Keep sliding while something with forces_movement (ice) occupies the tile
		var forced := true
		while forced:
			forced = false
			for other_id in state.entity_positions.keys():
				if other_id != entity_id and state.entity_positions[other_id] == state.entity_positions[entity_id] \
						and state.entity_states[other_id].get("forces_movement", false):
					forced = true
					break
			if forced:
				var next_pos: Vector2i = state.entity_positions[entity_id] + dir
				if can_move_to_position(next_pos, state, entity_id):
					state.entity_positions[entity_id] = next_pos
				else:
					forced = false

		moved_ids.append(entity_id)
	return moved_ids

# Position/blocking checking
func can_move_to_position(pos: Vector2i, state: GameState, moving_entity_id: String) -> bool:
	if pos.x < 0 or pos.x >= state.grid_size.x or pos.y < 0 or pos.y >= state.grid_size.y:
		return false
	return get_blocking_ids_at(state, pos, moving_entity_id).is_empty()

# Returns the ids of entities at `pos` that block `moving_entity_id` from
# occupying it, mirroring each entity's real _does_block() override.
func get_blocking_ids_at(state: GameState, pos: Vector2i, moving_entity_id: String, entities_to_remove: Array = []) -> Array:
	var blockers: Array = []
	var moving_entity_state: Dictionary = state.entity_states.get(moving_entity_id, {})
	var moving_type: String = moving_entity_state.get("type", "")

	for entity_id in state.entity_positions.keys():
		if entity_id == moving_entity_id or entities_to_remove.has(entity_id):
			continue
		if state.entity_positions[entity_id] != pos:
			continue
		var entity_state: Dictionary = state.entity_states[entity_id]
		var etype: String = entity_state.get("type", "")
		match etype:
			"goal":
				if entity_state.get("filled", false):
					continue # Filled goals don't block movement
				if moving_type == "black_gem":
					blockers.append(entity_id) # Black gems can never enter a goal
					continue
				if (moving_type == "gem" or moving_type == "bomb") and moving_entity_state.get("hue", -999.0) == entity_state.get("hue", -998.0):
					continue # A matching-color gem or bomb (bombs are gems too) can enter
				blockers.append(entity_id)
			"ice_slick", "sand_trap", "teleporter", "water_hazard", "pressure_plate":
				pass # These never block movement
			_:
				blockers.append(entity_id) # Gems, bombs, black gems, tile blockers, boulders always block

	return blockers

# Resolves everything that follows a movement step: entities landing on
# goals/hazards/sand/teleporters, then bomb ignition/countdown/explosion.
# Explosions can push entities into new tiles, which can itself trigger more
# of the same effects and further bomb ticks - so this loops the same way
# Game.on_all_movement_finished() re-enters itself after a bomb-triggered
# move_entities() call, until a step produces no further explosions.
func resolve_post_movement_cascade(state: GameState, initially_moved_ids: Array) -> void:
	var entities_to_remove: Array = []
	var moved_ids: Array = initially_moved_ids
	var cascade_step := 0

	while cascade_step < MAX_EXPLOSION_CASCADE_STEPS:
		cascade_step += 1
		apply_entered_tile_effects(state, moved_ids, entities_to_remove)
		var explode_ids := tick_bombs_and_find_explosions(state, entities_to_remove)
		if explode_ids.is_empty():
			break
		moved_ids = resolve_explosions(state, explode_ids, entities_to_remove)
		if moved_ids.is_empty():
			break

	for entity_id in entities_to_remove:
		state.entity_positions.erase(entity_id)
		state.entity_states.erase(entity_id)

# Handles the entity-entered-tile effects (goal fill, water hazard, sand
# trap, teleporter) for entities that just moved this cascade step.
func apply_entered_tile_effects(state: GameState, moved_ids: Array, entities_to_remove: Array) -> void:
	# Goal filling
	for gem_id in moved_ids:
		if entities_to_remove.has(gem_id) or !state.entity_positions.has(gem_id):
			continue
		var gem_state: Dictionary = state.entity_states[gem_id]
		var gtype: String = gem_state.get("type", "")
		if (gtype != "gem" and gtype != "bomb") or gem_state.get("gem_in_goal", false):
			continue
		var gem_pos: Vector2i = state.entity_positions[gem_id]
		for goal_id in state.entity_positions.keys():
			if entities_to_remove.has(goal_id):
				continue
			var goal_state: Dictionary = state.entity_states[goal_id]
			if goal_state.get("type", "") != "goal" or goal_state.get("filled", false):
				continue
			if state.entity_positions[goal_id] != gem_pos:
				continue
			if gem_state.get("hue", -999.0) != goal_state.get("hue", -998.0):
				continue
			goal_state["filled"] = true
			gem_state["gem_in_goal"] = true
			gem_state["stuck"] = true # Can no longer be moved out of the goal
			entities_to_remove.append(gem_id)
			entities_to_remove.append(goal_id)
			queue_ignite_bombs_of_hue(state, goal_state.get("hue", 0.0))
			break

	# Water hazards (remove gems, bombs, and black gems that just entered one)
	for entity_id in moved_ids:
		if entities_to_remove.has(entity_id) or !state.entity_positions.has(entity_id):
			continue
		var etype: String = state.entity_states[entity_id].get("type", "")
		if etype != "gem" and etype != "bomb" and etype != "black_gem":
			continue
		var pos: Vector2i = state.entity_positions[entity_id]
		for other_id in state.entity_positions.keys():
			if state.entity_states[other_id].get("type", "") == "water_hazard" and state.entity_positions[other_id] == pos:
				entities_to_remove.append(entity_id)
				break

	# Sand traps (stick gems, bombs, and black gems that just entered one)
	for entity_id in moved_ids:
		if entities_to_remove.has(entity_id) or !state.entity_positions.has(entity_id):
			continue
		var e_state: Dictionary = state.entity_states[entity_id]
		var etype: String = e_state.get("type", "")
		if etype != "gem" and etype != "bomb" and etype != "black_gem":
			continue
		var pos: Vector2i = state.entity_positions[entity_id]
		for other_id in state.entity_positions.keys():
			if state.entity_states[other_id].get("type", "") == "sand_trap" and state.entity_positions[other_id] == pos:
				e_state["stuck"] = true
				break

	# Teleporters (only entities that just moved onto one teleport - mirrors
	# Teleporter._on_entity_finished_entering(), which only fires on entry).
	# Real Teleporter._on_entity_finished_entering() doesn't discriminate by
	# type - a black gem can be teleported just as well as a gem or bomb.
	for entity_id in moved_ids:
		if entities_to_remove.has(entity_id) or !state.entity_positions.has(entity_id):
			continue
		var pos: Vector2i = state.entity_positions[entity_id]
		for tele_id in state.entity_positions.keys():
			if state.entity_states[tele_id].get("type", "") == "teleporter" and state.entity_positions[tele_id] == pos:
				var dest_id := find_destination_teleporter_id(state, tele_id)
				if dest_id != "":
					state.entity_positions[entity_id] = state.entity_positions[dest_id]
				break

# Advances bomb fuses one step (mirrors Bomb._entity_post_all_movement()):
# a bomb that was just queued to ignite this step becomes ignited with a
# fresh 1-move fuse (and does NOT also count down this same step); a bomb
# that was already ignited counts down. Returns ids ready to explode now.
func tick_bombs_and_find_explosions(state: GameState, entities_to_remove: Array) -> Array:
	var ready: Array = []
	for entity_id in state.entity_positions.keys():
		if entities_to_remove.has(entity_id):
			continue
		var b_state: Dictionary = state.entity_states[entity_id]
		if b_state.get("type", "") != "bomb" or b_state.get("gem_in_goal", false):
			continue
		if b_state.get("queue_ignite", false):
			b_state["ignited"] = true
			b_state["moves_until_explosion"] = 1
			b_state["queue_ignite"] = false
		elif b_state.get("ignited", false) and b_state.get("moves_until_explosion", -1) > 0:
			b_state["moves_until_explosion"] -= 1
		if b_state.get("ignited", false) and b_state.get("moves_until_explosion", -1) == 0:
			ready.append(entity_id)
	return ready

# Resolves a simultaneous set of bomb explosions: destroys adjacent black
# gems/boulders, and recursively pushes adjacent movable entities (and
# whatever blocks them in turn) away from each bomb, mirroring
# Bomb.explode()/push_entity_recursively(). Returns the ids that moved.
func resolve_explosions(state: GameState, explode_ids: Array, entities_to_remove: Array) -> Array:
	for bid in explode_ids:
		entities_to_remove.append(bid)

	var push_dirs: Dictionary = {} # entity_id -> summed Vector2i push
	for bid in explode_ids:
		var bomb_pos: Vector2i = state.entity_positions[bid]
		for other_id in state.entity_positions.keys():
			if other_id == bid or entities_to_remove.has(other_id):
				continue
			var other_pos: Vector2i = state.entity_positions[other_id]
			if !is_adjacent(bomb_pos, other_pos):
				continue
			var o_state: Dictionary = state.entity_states[other_id]
			var otype: String = o_state.get("type", "")
			if otype == "black_gem":
				entities_to_remove.append(other_id)
			elif otype == "boulder":
				entities_to_remove.append(other_id)
			elif o_state.get("moves", false):
				push_entity_recursively(state, other_id, other_pos - bomb_pos, push_dirs, entities_to_remove)

	# Reduce each entity's summed push to a single cardinal step, then apply
	# through the normal movement/blocking/ice-chaining pipeline.
	var pending: Dictionary = {}
	for entity_id in push_dirs.keys():
		if entities_to_remove.has(entity_id):
			continue
		var push_vec: Vector2i = push_dirs[entity_id]
		var final_dir := Vector2i(int(clamp(push_vec.x, -1, 1)), int(clamp(push_vec.y, -1, 1)))
		if final_dir != Vector2i.ZERO:
			pending[entity_id] = final_dir

	return apply_pending_moves(state, pending)

func push_entity_recursively(state: GameState, entity_id: String, direction: Vector2i, push_dirs: Dictionary, entities_to_remove: Array) -> void:
	if entities_to_remove.has(entity_id):
		return
	push_dirs[entity_id] = push_dirs.get(entity_id, Vector2i.ZERO) + direction

	var target_pos: Vector2i = state.entity_positions[entity_id] + direction
	for blocking_id in get_blocking_ids_at(state, target_pos, entity_id, entities_to_remove):
		var blocking_state: Dictionary = state.entity_states[blocking_id]
		# Bombs are never chain-pushed by another bomb's blast (though a bomb
		# directly adjacent to the exploding bomb is still pushed, above).
		if blocking_state.get("moves", false) and blocking_state.get("type", "") != "bomb":
			push_entity_recursively(state, blocking_id, direction, push_dirs, entities_to_remove)

# Queues a fuse-ignite for bombs affected by a goal being filled (mirrors
# Game.on_goal_filled()): bombs matching the filled goal's color light for
# the first time, and any bomb already counting down gets its fuse reset,
# regardless of color. The actual ignited/countdown transition happens on
# the next tick_bombs_and_find_explosions() call, not immediately - this is
# what gives a one-move delay between a goal fill and the resulting fuse
# actually starting to count down.
func queue_ignite_bombs_of_hue(state: GameState, hue: float) -> void:
	for entity_id in state.entity_states.keys():
		var st: Dictionary = state.entity_states[entity_id]
		if st.get("type", "") == "bomb" and !st.get("gem_in_goal", false):
			if st.get("hue", -999.0) == hue or st.get("moves_until_explosion", -1) >= 0:
				st["queue_ignite"] = true

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

	var start_ticks := Time.get_ticks_msec()

	var solution = solve_level()

	var elapsed_ms := Time.get_ticks_msec() - start_ticks

	print("Solver completed in ", elapsed_ms / 1000.0, " seconds")
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
