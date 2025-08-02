extends Node

const UNLOCKS_STR := "unlocks"

# Array indices to use
const UNLOCK_LEVEL_REQ := 1
const IS_UNLOCKED := 2

var unlock_dict := {}

enum UnlockType { COURSE, SKIN }

func _init() -> void:
	# Init our unlocks
	unlock_dict = \
		{ UNLOCKS_STR: \
			{ # See consts about array indices
				"Course-2":["course","1-6",false], \
				"Course-3":["course","2-6",false], \
				"Course-4":["course","3-6",false], \
				"Course-5":["course","4-6",false], \
				"Skin-Cat":["skin","1-12",false], \
				"Skin-Bowling Ball":["skin","2-12",false], \
			}
		}

func load_unlocks(data:Dictionary):
	for key in data:
		var values:Array = data[key]
		if values[2]: #Unlocked, so unlock it in our dict (but don't bother saving right now)
			if is_course(key):
				unlock_course(int(parse_course_str(key)[1]), false)
			elif is_skin(key):
				unlock_skin(parse_skin_str(key)[1], false)

func is_course(input:String) -> bool: return input.begins_with("Course")
func is_skin(input:String) -> bool: return input.begins_with("Skin")

# Parses strings like "Course-2" into an array of strings
func parse_course_str(course:String) -> Array: return course.split("-")
func parse_skin_str(skin:String) -> Array: return skin.split("-")

func is_course_unlocked(course_num:int) -> bool:
	var dict = unlock_dict[UNLOCKS_STR]
	for key in dict:
		if is_course(key) and int(parse_course_str(key)[1]) == course_num:
			return dict[key][IS_UNLOCKED]
	return false

func is_skin_unlocked(skin_name:String) -> bool:
	var dict = unlock_dict[UNLOCKS_STR]
	for key in dict:
		if is_skin(key) and parse_skin_str(key)[1] == skin_name:
			return dict[key][IS_UNLOCKED]
	return false

func unlock_course(course_num:int, save := true) -> void:
	var course_str = "Course-" + str(course_num)
	if unlock_dict[UNLOCKS_STR].has(course_str):
		unlock_dict[UNLOCKS_STR][course_str][IS_UNLOCKED] = true
		SaveGame.on_world_unlocked(course_num)
		if save: SaveGame.save_game()
	else:
		printerr("Unable to unlock course: " + course_str)

func unlock_skin(skin_name:String, save := true) -> void:
	var skin_str = "Skin-" + skin_name
	if unlock_dict[UNLOCKS_STR].has(skin_str):
		unlock_dict[UNLOCKS_STR][skin_str][IS_UNLOCKED] = true
		if save: SaveGame.save_game()
	else:
		printerr("Unable to unlock skin: " + skin_str)

func get_unlocked_skins() -> Array[String]:
	var unlocked_skins:Array[String] = []
	var dict = unlock_dict[UNLOCKS_STR]
	for key in dict:
		if is_skin(key) and dict[key][IS_UNLOCKED]:
			unlocked_skins.append(parse_skin_str(key)[1])
	return unlocked_skins

func on_level_beat(course_num:int, level_num:int) -> String:
	var level_str = str(course_num) + "-" + str(level_num)
	var dict = unlock_dict[UNLOCKS_STR]
	var unlocked_courses:Array[int] = []
	var unlocked_skins:Array[String] = []
	for key in dict:
		if dict[key][UNLOCK_LEVEL_REQ] == level_str:
			if is_course(key):
				var cur_course_num = int(parse_course_str(key)[1])
				if !is_course_unlocked(cur_course_num):
					unlocked_courses.append(cur_course_num)
				unlock_course(cur_course_num) #Should this be inside above if statement?
			elif is_skin(key):
				var cur_skin_num = parse_skin_str(key)[1]
				if !is_skin_unlocked(cur_skin_num):
					unlocked_skins.append(cur_skin_num)
				unlock_skin(cur_skin_num)
	
	if unlocked_courses.size() + unlocked_skins.size() > 0:
		var unlocks_str = ""
		for c in unlocked_courses:
			if unlocks_str != "":
				unlocks_str += "\n"
			unlocks_str += "Unlocked Course " + str(c) + "! Check it out at the main menu!"
		for c in unlocked_skins:
			if unlocks_str != "":
				unlocks_str += "\n"
			unlocks_str += "Unlocked " + c + " skin! Check it out in options!"
		return unlocks_str
	return ""
