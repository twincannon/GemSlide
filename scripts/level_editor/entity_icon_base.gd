@tool
extends MarginContainer
class_name EntityIconBase

var gem_scene = preload("res://scenes/entities/gem.tscn")
var black_gem_scene = preload("res://scenes/entities/black_gem.tscn")
var tile_blocker_scene = preload("res://scenes/entities/tile_blocker.tscn")
var goal_scene = preload("res://scenes/entities/goal.tscn")
var ice_slick_scene = preload("res://scenes/entities/ice_slick.tscn")
var sand_trap_scene = preload("res://scenes/entities/sand_trap.tscn")
var water_hazard_scene = preload("res://scenes/entities/water_hazard.tscn")
var teleporter_scene = preload("res://scenes/entities/teleporter.tscn")

var icon_ball = preload("res://assets/art/golfball.png")
var icon_goal = preload("res://assets/art/goal.png")
var icon_ice = preload("res://assets/art/ice_slick.png")
var icon_sand = preload("res://assets/art/sandtrap.png")
var icon_tele = preload("res://assets/art/teleporter.png")
var icon_tree = preload("res://assets/art/tree.png")
var icon_water = preload("res://assets/art/waterhazard.png")

@export var entity_type:Globals.EntityType : set = set_entity_type
@export var entity_text:String : set = set_entity_text
@export var entity_color:Color = Color(1,1,1) : set = set_entity_color
@export var entity_id:int = 0 : set = set_entity_id

@onready var entity_label = %EntityLabel
@onready var button = $PanelContainer/Button
@export_category("Defaults")
@export var entity_icon:TextureRect
@export var id_label:Label

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

func set_entity_id(new_entity_id):
	entity_id = new_entity_id
	update_ui()

func set_entity_type(new_entity_type):
	entity_id = 0
	entity_type = new_entity_type
	if !entity_icon:
		return
	entity_color = Color.WHITE
	match new_entity_type:
		Globals.EntityType.BallRed:
			entity_text = "b"
			entity_color = Color.RED # Keeping these RGB as I rely on the values below
			entity_icon.texture = icon_ball
		Globals.EntityType.BallGreen:
			entity_text = "b"
			entity_color = Color.GREEN
			entity_icon.texture = icon_ball
		Globals.EntityType.BallBlue:
			entity_text = "b"
			entity_color = Color.BLUE
			entity_icon.texture = icon_ball
		Globals.EntityType.GoalRed:
			entity_text = "goal"
			entity_color = Color.RED
			entity_icon.texture = icon_goal
		Globals.EntityType.GoalGreen:
			entity_text = "goal"
			entity_color = Color.GREEN
			entity_icon.texture = icon_goal
		Globals.EntityType.GoalBlue:
			entity_text = "goal"
			entity_color = Color.BLUE
			entity_icon.texture = icon_goal
		Globals.EntityType.BallBlack:
			entity_text = "b"
			entity_color = Color.DIM_GRAY
			entity_icon.texture = icon_ball
		Globals.EntityType.TileBlocker:
			entity_text = "#"
			#entity_color = Color.BLACK
			entity_icon.texture = icon_tree
		Globals.EntityType.IceSlick:
			entity_text = "ice"
			#entity_color = Color.AQUA
			entity_icon.texture = icon_ice
		Globals.EntityType.SandTrap:
			entity_text = "sand"
			#entity_color = Color.BURLYWOOD
			entity_icon.texture = icon_sand
		Globals.EntityType.WaterHazard:
			entity_text = "water"
			#entity_color = Color.NAVY_BLUE
			entity_icon.texture = icon_water
		Globals.EntityType.Teleporter:
			entity_text = "tele"
			#entity_color = Color.BLUE_VIOLET
			entity_icon.texture = icon_tele
		_:
			entity_text = ""
			entity_color = Color.WHITE
			entity_icon.texture = null
	entity_icon.modulate = entity_color
	update_ui()
		
func update_ui():
	if entity_label:
		entity_label.text = entity_text
	
	if id_label:
		id_label.text = ""
		if entity_text.is_empty() == false:
			id_label.text = "id: " + str(entity_id)
	#panel_style.bg_color = entity_color
#	if is_gem():
#		panel_style.set_corner_radius_all(500)
#	else:
#		panel_style.set_corner_radius_all(3)

func is_gem():
	return entity_text.to_lower() == "g" or entity_text.to_lower() == "gem" or entity_text.to_lower() == "b"
func is_goal():
	return entity_text.to_lower() == "goal"
func is_ice_slick():
	return entity_text.to_lower() == "ice" or entity_text.to_lower() == "ice slick"
func is_sand_trap():
	return entity_text.to_lower() == "sand"
func is_water_hazard():
	return entity_text.to_lower() == "water"
func is_teleporter():
	return entity_text.to_lower() == "tele"
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
	elif is_water_hazard():
		entity = water_hazard_scene.instantiate() as WaterHazard
	elif is_teleporter():
		entity = teleporter_scene.instantiate() as Teleporter
	elif entity_text == "#":
		entity = tile_blocker_scene.instantiate() as TileBlocker
	
	if entity:
		entity.entity_id = int(id_label.text.lstrip("id: "))
		
		if entity.has_node("ColorComponent"):
			var color_comp := entity.get_node("ColorComponent") as ColorComponent
			if color_comp:
				if is_red():
					color_comp.set_color(Globals.COLOR_RED)
				elif is_green():
					color_comp.set_color(Globals.COLOR_GREEN)
				elif is_blue():
					color_comp.set_color(Globals.COLOR_BLUE)
	
	return entity
