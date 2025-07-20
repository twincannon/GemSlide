extends Node

var level_dict = { }
var config_dict = {
	"Volume": {"Master": 1.0, "SFX": 1.0, "Music": 1.0},
	"BallColor": {"R":var_to_str(Color.RED), "G":var_to_str(Color.GREEN), "B":var_to_str(Color.BLUE)}
}

const SAVE_FILE_NAME = "save.json"
const CONFIG_FILE_NAME = "config.json"
const SECURITY_KEY = "982afe2934e"

func update_level_in_dict(level_name, unlocked, score):
	level_dict[level_name] = {"unlocked": unlocked, "score": score}

func set_level_unlocked(level_name, unlocked = true):
	if level_dict.has(level_name):
		level_dict[level_name]["unlocked"] = unlocked

func set_level_score(level_name, score):
	if level_dict.has(level_name):
		level_dict[level_name]["score"] = score

func set_level_moves(level_name, moves):
	if level_dict.has(level_name):
		level_dict[level_name]["moves"] = moves

func is_level_unlocked(level_name):
	return level_dict[level_name]["unlocked"] if level_dict.has(level_name) else true

func get_level_score(level_name) -> int:
	return level_dict[level_name]["score"] if level_dict.has(level_name) else 0

func save_game():
	save_data(Globals.SAVE_DIR + SAVE_FILE_NAME)

func _ready():
	for world in Globals.world_datas:
		var is_first_level = true
		for level in world.level_data_json:
			update_level_in_dict(level.resource_path, is_first_level, 0)
			is_first_level = false
	
	verify_save_directory(Globals.SAVE_DIR)
	load_data(Globals.SAVE_DIR + SAVE_FILE_NAME)
	load_config()
	#print(str(level_dict).replace("}", "}\n"))

func _input(_event):
	if Input.is_action_just_pressed("unlocklevels"):
		if OS.is_debug_build():
			for level in level_dict:
				set_level_unlocked(level)
		
func verify_save_directory(path:String):
	DirAccess.make_dir_absolute(path)
	
func save_data(path:String):
	var file = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, SECURITY_KEY)
	if file == null:
		printerr(FileAccess.get_open_error())
		return
	
	var json_string = JSON.stringify(level_dict, "\t")
	file.store_string(json_string)
	file.close()
	
func load_data(path:String):
	if FileAccess.file_exists(path):
		var file = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, SECURITY_KEY)
		if file == null:
			printerr(FileAccess.get_open_error())
			return
		
		var content = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(content)
		if data == null:
			printerr("Cannot parse %s as a json string (%s)" % [path, content])
			return
		
		# Iterate through our data and set each level's data (don't set the level_dict directly to data!)
		for level_name in data:
			level_dict[level_name] = data[level_name]
	else:
		printerr("Cannot open file at %s" % [path])

func get_custom_level_files():
	var valid_files = []
	var files = DirAccess.get_files_at(Globals.SAVE_DIR)
	for file in files:
		if file.begins_with("level_"):
			valid_files.append(file)
	return valid_files

func get_custom_level_data(path:String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr(FileAccess.get_open_error())
		return
	
	var content = file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(content)
	if data == null:
		printerr("Cannot parse %s as a json string (%s)" % [path, content])
		return
	
	return data

func set_config_volume(bus:String, value:float):
	if config_dict["Volume"].has(bus):
		config_dict["Volume"][bus] = value
	save_config()

func set_config_ball_color(ballcolor:String, color:Color):
	if config_dict["BallColor"].has(ballcolor):
		config_dict["BallColor"][ballcolor] = var_to_str(color)
	save_config()
		
func save_config():
	var file = FileAccess.open(Globals.SAVE_DIR + CONFIG_FILE_NAME, FileAccess.WRITE)
	if file == null:
		printerr(FileAccess.get_open_error())
		return
	
	var json_string = JSON.stringify(config_dict, "\t")
	file.store_string(json_string)
	file.close()
	
func load_config():
	var path = Globals.SAVE_DIR + CONFIG_FILE_NAME
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			printerr(FileAccess.get_open_error())
			return
		
		var content = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(content)
		if data == null:
			printerr("Cannot parse %s as a json string (%s)" % [path, content])
			return
		
		config_dict = data
		
		Globals.COLOR_RED = str_to_var(data["BallColor"]["R"])
		Globals.COLOR_GREEN = str_to_var(data["BallColor"]["G"])
		Globals.COLOR_BLUE = str_to_var(data["BallColor"]["B"])
		
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(data["Volume"]["Master"]))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(data["Volume"]["SFX"]))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(data["Volume"]["Music"]))
		
	else:
		printerr("Cannot open file at %s" % [path])
