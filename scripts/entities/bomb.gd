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
	Globals.get_game_node().queue_entity_for_removal(self)
	$BlockedAnchor.visible = false
	#todo: move adjacent entities/destroy rocks
