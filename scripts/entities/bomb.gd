class_name Bomb
extends Gem

var ignited = false
var queue_ignite = false
var moves_until_explosion = -1  # -1 means not counting down, 0 means explode now

func _ready():
	entity_sprite = %BombSprite
	moves = true
	gem_rotates = false

func ignite_fuse():
	queue_ignite = true
	%BombFuseVFX.visible = true

func on_goal_entered(_goal):
	super(_goal)
	ignited = false
	%BombFuseSprite.visible = false
	%BombFuseVFX.visible = false

func _entity_post_all_movement():
	super()
	if queue_ignite:
		ignited = true
		queue_ignite = false  # Clear the queue so it doesn't ignite again
		moves_until_explosion = 1  # Start the countdown
	elif ignited and moves_until_explosion > 0:
		moves_until_explosion -= 1  # Decrement the countdown

func should_explode_now() -> bool:
	return ignited and moves_until_explosion == 0 and !gem_in_goal

func explode() -> Array[Entity]:
	Globals.get_game_node().on_bomb_explode()
	Globals.get_game_node().queue_entity_for_removal(self)
	$BlockedAnchor.visible = false
	moves_until_explosion = -1  # Clear the flag after exploding
	
	# Get all adjacent entities and push them recursively
	var ents:Array[Entity] = []
	var adjacent_entities = []
	for e in Globals.get_game_node().entities:
		if e != self and Globals.is_cardinally_adjacent(grid_pos, e.grid_pos):
			if e is Bomb:
				continue
			elif e is BlackGem:
				e.on_rock_destroyed()
			else:
				adjacent_entities.append(e)
	
	# Push each adjacent entity recursively
	for entity in adjacent_entities:
		var push_direction = entity.grid_pos - grid_pos
		ents.append_array(push_entity_recursively(entity, push_direction))
	
	return ents
	
func push_entity_recursively(entity: Entity, direction: Vector2i) -> Array[Entity]:
	# Check if there are entities blocking the path in the direction we're pushing
	var target_pos = entity.grid_pos + direction
	var blocking_entities = Globals.get_game_node().get_entities_blocking_at_pos(target_pos, entity)
	
	var ents:Array[Entity] = []
	ents.append(entity) # Add the current entity to the list
	
	# First, recursively push any blocking entities (furthest from bomb first)
	# But exclude bombs - they should never be pushed by explosions
	for blocking_entity in blocking_entities:
		if blocking_entity.moves and !(blocking_entity is Bomb):
			ents.append_array(push_entity_recursively(blocking_entity, direction))
	
	# Set the pending move direction for this entity
	entity.pending_move_dir = direction
	
	return ents

func get_properties() -> Dictionary:
	var dict = super()
	dict["ignited"] = ignited
	dict["moves_until_explosion"] = moves_until_explosion
	return dict

func apply_properties(properties:Dictionary):
	super(properties)
	if properties.has("ignited"):
		ignited = properties["ignited"]
		if ignited:
			%BombFuseVFX.visible = true
	if properties.has("moves_until_explosion"):
		moves_until_explosion = properties["moves_until_explosion"]
	if gem_in_goal:
		%BombFuseSprite.visible = false
		%BombFuseVFX.visible = false
