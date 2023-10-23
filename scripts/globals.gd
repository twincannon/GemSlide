extends Node

@export var world_datas:Array[WorldData] = [load("res://data/worlds/world01.tres"), \
											load("res://data/worlds/world02.tres")]

var current_world_data : WorldData = load("res://data/worlds/world01.tres")

var current_level_scene:PackedScene
var current_level:LevelBase
var current_level_num := 0

enum Entity {None = 0, Gem, TileBlocker}

func get_current_world_index():
	return world_datas.find(current_world_data)

func get_current_level_index():
	return world_datas[get_current_world_index()].level_data.find(current_level_scene)

func change_level(level_to_load):
	current_level_scene = level_to_load

func _ready():
	DisplayServer.window_set_min_size(Vector2i(400,400))

func get_game_node() -> Game:
	return get_node("/root/Game")

func get_entity_movement_distance() -> Vector2:
	var game_node = get_game_node()
	if game_node:
		return game_node.tile_size
	return Vector2(0,0)
