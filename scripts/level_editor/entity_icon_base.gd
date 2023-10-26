@tool
extends MarginContainer
class_name EntityIconBase

var gem_scene = preload("res://scenes/entities/gem.tscn")
var black_gem_scene = preload("res://scenes/entities/black_gem.tscn")
var tile_blocker_scene = preload("res://scenes/entities/tile_blocker.tscn")
var goal_scene = preload("res://scenes/entities/goal.tscn")
var ice_slick_scene = preload("res://scenes/entities/ice_slick.tscn")
var sand_trap_scene = preload("res://scenes/entities/sand_trap.tscn")

enum EntityType {
	None = 0,
	GemRed,
	GemGreen,
	GemBlue,
	GoalRed,
	GoalGreen,
	GoalBlue,
	GemBlack,
	TileBlocker,
	IceSlick,
	SandTrap,
	WaterHazard
}

@export var entity_type:EntityType : set = set_entity_type
@export var entity_text:String : set = set_entity_text
@export var entity_color:Color = Color(1,1,1) : set = set_entity_color

@onready var entity_label = %EntityLabel

var panel_style = StyleBoxFlat.new()

func _ready():
	$PanelContainer.add_theme_stylebox_override("panel", panel_style)
	update_ui()
	pass
	
func set_entity_text(new_entity_text):
	entity_text = new_entity_text
	update_ui()

func set_entity_color(new_entity_color):
	entity_color = new_entity_color
	update_ui()

func set_entity_type(new_entity_type):
	entity_type = new_entity_type
	match new_entity_type:
		EntityType.GemRed:
			entity_text = "g"
			entity_color = Color.RED
		EntityType.GemGreen:
			entity_text = "g"
			entity_color = Color.GREEN
		EntityType.GemBlue:
			entity_text = "g"
			entity_color = Color.BLUE
		EntityType.GoalRed:
			entity_text = "goal"
			entity_color = Color.RED
		EntityType.GoalGreen:
			entity_text = "goal"
			entity_color = Color.GREEN
		EntityType.GoalBlue:
			entity_text = "goal"
			entity_color = Color.BLUE
		EntityType.GemBlack:
			entity_text = "g"
			entity_color = Color.DIM_GRAY
		EntityType.TileBlocker:
			entity_text = "#"
			entity_color = Color.BLACK
		EntityType.IceSlick:
			entity_text = "ice"
			entity_color = Color.AQUA
		EntityType.SandTrap:
			entity_text = "sand"
			entity_color = Color.BURLYWOOD
		EntityType.WaterHazard:
			entity_text = "water"
			entity_color = Color.NAVY_BLUE
		_:
			entity_text = ""
			entity_color = Color.WHITE
	update_ui()
		
func update_ui():
	if entity_label:
		entity_label.text = entity_text
	panel_style.bg_color = entity_color
	if is_gem():
		panel_style.set_corner_radius_all(50)
	else:
		panel_style.set_corner_radius_all(5)

func is_gem():
	return entity_text.to_lower() == "g" or entity_text.to_lower() == "gem"
func is_goal():
	return entity_text.to_lower() == "goal"
func is_ice_slick():
	return entity_text.to_lower() == "ice" or entity_text.to_lower() == "ice slick"
func is_sand_trap():
	return entity_text.to_lower() == "sand"
func is_water_hazard():
	return entity_text.to_lower() == "water"
func is_red():
	return entity_color.r >= 0.8 and entity_color.g < 0.2 and entity_color.b < 0.2
func is_green():
	return entity_color.r < 0.2 and entity_color.g >= 0.8 and entity_color.b < 0.2
func is_blue():
	return entity_color.r < 0.2 and entity_color.g < 0.2 and entity_color.b >= 0.8

func get_entity():
	var entity = null
	
	if is_gem():
		if is_red() or is_green() or is_blue():
			entity = gem_scene.instantiate() as Gem
		else:
			entity = black_gem_scene.instantiate() as BlackGem
	elif is_goal():
		entity = goal_scene.instantiate() as Goal
	elif is_ice_slick():
		entity = ice_slick_scene.instantiate() as IceSlick
	elif is_sand_trap():
		entity = sand_trap_scene.instantiate() as SandTrap
	elif entity_text == "#":
		entity = tile_blocker_scene.instantiate() as TileBlocker
	
	if entity:
		if entity.has_node("ColorComponent"):
			var color_comp := entity.get_node("ColorComponent") as ColorComponent
			if color_comp:
				if is_red():
					color_comp.set_color(Color.RED)
				elif is_green():
					color_comp.set_color(Color.GREEN)
				elif is_blue():
					color_comp.set_color(Color.BLUE)
	
	return entity
