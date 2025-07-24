class_name Bomb
extends Gem

var ignited = false
var queue_ignite = false

func _ready():
	entity_sprite = %BombSprite
	moves = true
	gem_rotates = false

func ignite_fuse():
	queue_ignite = true
	%BombFuseVFX.visible = true

func on_goal_entered(_goal):
	super(_goal)
	%BombFuseSprite.visible = false
	%BombFuseVFX.visible = false

func _entity_post_all_movement():
	super()
	if ignited and !gem_in_goal:
		explode()
	elif queue_ignite:
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
			else:
				adjacent_entities.append(e)
	
	# Push each adjacent entity recursively
	for entity in adjacent_entities:
		var push_direction = entity.grid_pos - grid_pos
		push_entity_recursively(entity, push_direction)

func get_properties() -> Dictionary:
	var dict = super()
	dict["ignited"] = ignited
	return dict

func apply_properties(properties:Dictionary):
	super(properties)
	if properties.has("ignited"):
		ignited = properties["ignited"]
		if ignited:
			%BombFuseVFX.visible = true
	if gem_in_goal:
		%BombFuseSprite.visible = false
		%BombFuseVFX.visible = false
