extends Node

var sounds = {
	&"ui_click" : AudioStreamPlayer.new(),
	&"ui_hover" : AudioStreamPlayer.new()
}

func _ready():
	for i in sounds.keys():
		sounds[i].stream = load("res://assets/audio/ui/" + str(i) + ".wav")
		sounds[i].bus = &"SFX"
		add_child(sounds[i])
	get_tree().node_added.connect(connect_sound)

func connect_sound(node:Node):
	if node is Button:
		node.pressed.connect(play_ui_sound.bind(&"ui_click"))
		node.mouse_entered.connect(play_ui_sound.bind(&"ui_hover"))

func play_ui_sound(name:String):
	if sounds.has(name):
		sounds[name].play()
