class_name UndoManager
extends Node

var game:Game
var game_states:Array[UndoGameState]

func push_game_state():
	print("pushing new gamestate")
	var new_game_state := UndoGameState.new()
	new_game_state.moves_count = game.moves
	new_game_state.moves_array = game.moves_array.duplicate()
	#new_game_state.game_state = game.game_state
	
	for e in game.entities:
		if e in game.entities_to_remove:
			continue #safety check
		var ent_state = UndoEntityState.new()
		ent_state.entity_id = e.entity_id
		ent_state.entity_type = e.entity_type
		ent_state.grid_pos = e.grid_pos
		#print(Globals.EntityType.keys()[e.entity_type]) #make sure this actually returns "Teleporter" etc
		ent_state.properties = e.get_properties()
		new_game_state.entity_states.append(ent_state)
	
	game_states.append(new_game_state)

func pop_game_state():
	if game_states.size() <= 0:
		return
	print("Popping gamestate")

	for e in game.entities:
		e.queue_free()
	game.entities.clear()
	
	if game_states.size() > 0:
		var state = game_states.pop_back()

		game.moves = state.moves_count
		game.moves_array = state.moves_array.duplicate()

		for ent_state in state.entity_states:
			var icon_inst = game.entity_icon_scene.instantiate()
			if icon_inst:
				icon_inst.set_entity_type(ent_state.entity_type)
				icon_inst.set_entity_id(ent_state.entity_id)
				var new_ent = icon_inst.get_entity()
				if new_ent:
					new_ent.entity_type = ent_state.entity_type
					new_ent.entity_id = ent_state.entity_id
					game.add_entity_to_grid(new_ent, ent_state.grid_pos)
					new_ent.apply_properties(ent_state.properties)
		
		# Initialize all entities - do we need this ...?
		for e in game.entities:
			e._initialize_entity(game)
		
		# Reconnect sand trap signals after all entities are initialized
		for e in game.entities:
			if e is SandTrap:
				e.reconnect_to_stuck_entities()
		
		game.update_moves_text()

func remove_newest_game_state():
	print("undoing gamestate add")
	game_states.pop_back()
