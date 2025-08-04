extends CanvasLayer

const DEPIXELATION_SPEED := 15.0

func do_pixelation():
	visible = true
	$ColorRect.material.set_shader_parameter("pixel_size", 64)

func _process(delta: float) -> void:
	if visible:
		var cur = $ColorRect.material.get_shader_parameter("pixel_size")
		var new = lerpf(cur, 0.0, DEPIXELATION_SPEED * delta)
		$ColorRect.material.set_shader_parameter("pixel_size", new)
		if new <= 1.0:
			visible = false
