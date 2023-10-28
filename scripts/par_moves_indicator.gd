extends Control

@onready var result_sound_par = preload("res://assets/audio/result_par.wav")
@onready var result_sound_birdie = preload("res://assets/audio/result_birdie.wav")
@onready var result_sound_eagle = preload("res://assets/audio/result_eagle.wav")
@onready var result_sound_supereagle = preload("res://assets/audio/result_supereagle.wav")

signal on_indicator_done
var result := Globals.ResultType.Par

func _ready():
	match result:
		Globals.ResultType.Par:
			%Results/Par.visible = true
			$AudioStreamPlayer.stream = result_sound_par
		Globals.ResultType.Birdie:
			%Results/Birdie.visible = true
			$AudioStreamPlayer.stream = result_sound_birdie
		Globals.ResultType.Eagle:
			%Results/Eagle.visible = true
			$AudioStreamPlayer.stream = result_sound_eagle
		Globals.ResultType.SuperEagle:
			%Results/SuperEagle.visible = true
			$AudioStreamPlayer.stream = result_sound_supereagle
		Globals.ResultType.BeatDev:
			%Results/BeatDev.visible = true
			$AudioStreamPlayer.stream = result_sound_supereagle
	
	$AudioStreamPlayer.play()
	
	var enter_tween = create_tween().set_parallel()
	enter_tween.set_trans(Tween.TRANS_CUBIC)
	enter_tween.tween_property(%Results, "position:x", 0, 1.0)
	enter_tween.tween_property(%Results, "modulate:a", 1.0, 1.0)
	
	if $AudioStreamPlayer.has_stream_playback():
		await $AudioStreamPlayer.finished
	else:
		await get_tree().create_timer(1.5).timeout
	
	var fade_tween = create_tween()
	fade_tween.tween_property(%Results, "modulate:a", 0.0, 0.5)
	fade_tween.tween_callback(on_tween_finished)
	
	
func on_tween_finished():
	on_indicator_done.emit()
	queue_free()
