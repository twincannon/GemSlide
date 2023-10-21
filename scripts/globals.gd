extends Node

var world_data : WorldData

var current_level_scene:PackedScene
var current_level:LevelBase

enum Entity {None = 0, Gem, TileBlocker}

func get_game_node() -> Game:
	return get_node("/root/Game")

func get_entity_movement_distance() -> Vector2:
	var game_node = get_game_node()
	if game_node:
		return game_node.icon_size
	return Vector2(0,0)
