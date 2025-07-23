class_name Bomb
extends Gem

var ignited = false
var ignite_next_move = false

func _ready():
	entity_sprite = %BombSprite
	moves = true
	gem_rotates = false

func ignite_fuse():
	ignite_next_move = true
	%BombFuseVFX.visible = true

func on_goal_entered(_goal):
	super(_goal)
	%BombFuseSprite.visible = false
	%BombFuseVFX.visible = false

func _on_movement_tween_done(dir):
	super(dir)
	if ignited and !gem_in_goal:
		explode()
	elif ignite_next_move:
		ignited = true

func explode():
	Globals.get_game_node().on_bomb_explode()
	Globals.get_game_node().queue_entity_for_removal(self)
	$BlockedAnchor.visible = false
	
	# Get all adjacent entities and push them recursively
	var adjacent_entities = []
	for e in Globals.get_game_node().entities:
		if e != self and Globals.is_cardinally_adjacent(grid_pos, e.grid_pos):
			if e is Bomb:
				continue
			elif e is BlackGem:
				e.on_rock_destroyed()
			elif e.is_forcibly_moving: #Ice slicks
				continue
			else:
				adjacent_entities.append(e)
	
	# Push each adjacent entity recursively
	for entity in adjacent_entities:
		var push_direction = entity.grid_pos - grid_pos
		push_entity_recursively(entity, push_direction)

func push_entity_recursively(entity: Entity, direction: Vector2i):
	# Check if there are entities blocking the path in the direction we're pushing
	var target_pos = entity.grid_pos + direction
	var blocking_entities = Globals.get_game_node().get_entities_blocking_at_pos(target_pos, entity)
	
	# First, recursively push any blocking entities
	for blocking_entity in blocking_entities:
		if blocking_entity.moves:
			push_entity_recursively(blocking_entity, direction)
	
	# Now try to move the original entity
	if entity.on_try_move(direction):
		# The entity moved successfully
		pass
		
#OK current bugs/observations:
# if a bomb pushes another bomb, they dont explode at the same time like they should
# probably need to loop all bombs and then explode all at the same time or something? idk how
# they explode mid-ice slick
# yeahhh... we need to say "ok all of these bombs are exploding, apply the forces all at once"
# refactor ice slicks so they are properly only one move
