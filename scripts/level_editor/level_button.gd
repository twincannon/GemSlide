extends Button
class_name LevelButton

@export var level_to_load:PackedScene
var custom_level_data := { }

func _on_pressed():
	if !custom_level_data.is_empty():
		Globals.set_custom_level_data(custom_level_data)
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	elif level_to_load:
		Globals.change_level(level_to_load)
		get_tree().change_scene_to_file("res://scenes/game.tscn")

func set_button_text(new_text:String):
	%LevelNum.text = new_text
	const MIN_SIZE = 10
	var font_size = max(remap(ThemeDB.fallback_font.get_string_size(%LevelNum.text).x, 50, 100, 20, MIN_SIZE), MIN_SIZE)
	%LevelNum.add_theme_font_size_override("font_size", font_size)
#	#var split_text = new_text.split("-")
	#if split_text.size() > 0:
	#	level_num = int(new_text.split("-")[1])

func set_button_score(score):
	%Moves.text = "Best: " + str(score) if score > 0 else ""
	
func set_par_score(par):
	%Par.text = "Par: " + str(par) if par > 0 else ""
