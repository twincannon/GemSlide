extends Control

@export var label_text:String = ""
@export_category("Defaults")
@export var panel_container:PanelContainer
@export var label:Label


# Called when the node enters the scene tree for the first time.
func _ready():
	label.text = label_text
	await get_tree().create_timer(5.0).timeout
	var tween = create_tween()
	tween.tween_property(panel_container, "modulate:a", 0.0, 2.0)
	tween.tween_callback(queue_free)
