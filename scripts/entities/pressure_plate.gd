class_name PressurePlate extends Entity

var pressed := false

var icon_pressed = preload("res://assets/art/button_pressed.png")

func _ready():
	moves = false

func _does_block(_other_entity):
	return false

func _on_entity_finished_entering(_other_entity):
	pressed = true
	$Sprite.texture = icon_pressed
	for e in Globals.get_game_node().entities:
		if e.entity_id == entity_id:
			e._on_activated()

func get_properties() -> Dictionary:
	var dict = super()
	dict["pressed"] = pressed
	return dict
