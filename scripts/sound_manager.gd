extends Node

var music_node:AudioStreamPlayer2D

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
		node.pressed.connect(play_ui_sound.bind(node, &"ui_click"))
		node.mouse_entered.connect(play_ui_sound.bind(node, &"ui_hover"))

func play_ui_sound(button:Button, soundname:String):
	if !button.disabled and sounds.has(soundname):
		sounds[soundname].play()

func start_game_music():
	if !music_node:
		music_node = AudioStreamPlayer2D.new()
		music_node.stream = preload("res://assets/audio/music/cool_contemplation.mp3")
		music_node.process_mode = Node.PROCESS_MODE_ALWAYS
		music_node.bus = "Music"
		add_child(music_node)
	if !music_node.playing:
		music_node.play()

func stop_game_music():
	if music_node:
		music_node.stop()
