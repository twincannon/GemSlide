extends Node

const SAVE_DIR = "user://saves/"

@export var world_datas:Array[WorldData] = [load("res://data/worlds/world01.tres"), \
											load("res://data/worlds/world02.tres"), \
											load("res://data/worlds/world03.tres"), \
											load("res://data/worlds/world04.tres")]

enum ResultType { Par, Birdie, Eagle, SuperEagle, BeatDev }

enum EntityType {
	None = 0,
	BallRed,
	BallGreen,
	BallBlue,
	GoalRed,
	GoalGreen,
	GoalBlue,
	BallBlack,
	TileBlocker,
	IceSlick,
	SandTrap,
	WaterHazard,
	Teleporter
}

#var COLOR_RED := Color.ORANGE
#var COLOR_GREEN := Color.CYAN
#var COLOR_BLUE := Color.DARK_VIOLET
# TODO: Make color picker for these colors in options
var COLOR_RED := Color.RED
var COLOR_GREEN := Color.GREEN
var COLOR_BLUE := Color.BLUE

var current_world_data : WorldData = load("res://data/worlds/world01.tres")

var current_level_scene:PackedScene
var current_level:LevelBase

var custom_level_data := { } : set = set_custom_level_data

var did_retry := false

func _ready():
	#DisplayServer.window_set_min_size(Vector2i(400,400))
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(_event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func get_current_world_index():
	return world_datas.find(current_world_data)

func get_current_level_index():
	return world_datas[get_current_world_index()].level_data.find(current_level_scene)

func change_level(level_to_load):
	current_level_scene = level_to_load

func set_custom_level_data(new_data):
	custom_level_data = new_data

func get_game_node() -> Game:
	return get_node("/root/Game")

func get_entity_movement_distance() -> Vector2:
	var game_node = get_game_node()
	if game_node:
		return game_node.tile_size
	return Vector2(0,0)

func is_valid_custom_level(data):
	return data \
		and data.has("GridSize") \
		and data.has("ParMoves") \
		and data.has("Entities") \
		and data.has("LevelName")
	
