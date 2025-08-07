extends RigidBody2D

const VFX_FIREWORK_EXPLODE = preload("res://scenes/vfx/vfx_firework_explode.tscn")


func _ready() -> void:
	gravity_scale = 0.0
	get_tree().create_timer(randf_range(0.3,0.6)).timeout.connect(_launch.bind())

func _launch() -> void:
	gravity_scale = 1.0
	linear_velocity = Vector2(randf_range(-300,300), -1000.0)
	angular_velocity = randf_range(-1,1)
	get_tree().create_timer(randf_range(0.9,1.3)).timeout.connect(_explode.bind())

func _explode() -> void:
	var vfx = VFX_FIREWORK_EXPLODE.instantiate()
	add_child(vfx)
	vfx.restart()
	vfx.emitting = true
	#vfx.modulate = Color(100000, 10, 10)
	vfx.process_material.color = Color.from_hsv(randf_range(0.0,1.0), 1.0, 1.0)
	
	var sub_emitter := vfx.get_node(vfx.sub_emitter) as GPUParticles2D
	var sub_particle_material := sub_emitter.process_material as ParticleProcessMaterial
	randomize()
	var randomcolor = Color.from_hsv(randf_range(0.0,1.0), 1.0, 1.0)
	sub_particle_material.color = randomcolor

	var sub_emitter2 := vfx.get_node("Fireworklet") as GPUParticles2D
	var sub_particle_material2 := sub_emitter2.process_material as ParticleProcessMaterial
	randomize()
	sub_particle_material2.color = randomcolor
	
	
	linear_velocity = Vector2.ZERO
	gravity_scale = 0.0
	$Sprite2D.visible = false
	get_tree().create_timer(10.0).timeout.connect(queue_free.bind())
