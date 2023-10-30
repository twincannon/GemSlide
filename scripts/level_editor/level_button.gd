extends Button
class_name LevelButton

@export var level_to_load:PackedScene

func _on_pressed():
	if !level_to_load:
		return
	Globals.change_level(level_to_load)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func set_button_text(new_text:String):
	%LevelNum.text = new_text
	#var split_text = new_text.split("-")
	#if split_text.size() > 0:
	#	level_num = int(new_text.split("-")[1])

func set_button_score(score):
	%Moves.text = "Best: " + str(score) if score > 0 else ""
	
func set_par_score(par):
	%Par.text = "Par: " + str(par) if par > 0 else ""
