extends Node

var level_dict = { }

const SAVE_DIR = "user://saves/"
const SAVE_FILE_NAME = "save.json"
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

func get_level_score(level_name):
	return level_dict[level_name]["score"] if level_dict.has(level_name) else 0

func save_game():
	save_data(SAVE_DIR + SAVE_FILE_NAME)
	#print(str(level_dict).replace("}", "}\n"))

func _ready():
	for world in Globals.world_datas:
		var is_first_level = true
		for level in world.level_data:
			update_level_in_dict(level.resource_path, is_first_level, 0)
			is_first_level = false
	
	verify_save_directory(SAVE_DIR)
	load_data(SAVE_DIR + SAVE_FILE_NAME)


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
