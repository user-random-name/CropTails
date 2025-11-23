class_name CropsCursorComponent
extends Node

@export var tilled_soil_tilemap_layer: TileMapLayer

var player: Player
var corn_plant_scene = preload("res://scenes/objects/plants/corn.tscn")
var tomato_plant_scene = preload("res://scenes/objects/plants/tomato.tscn")

var mouse_position: Vector2
var cell_position: Vector2i
var cell_source_id: int
var local_cell_position: Vector2
var distance: float
var can_plant_crop: bool = true  # Flag to prevent duplicate planting

func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("remove_dirt"):
		if ToolManager.selected_tool == DataTypes.Tools.TillGround:
			get_cell_under_mouse()
			remove_crop()
	elif event.is_action_pressed("hit"):
		if ToolManager.selected_tool in [DataTypes.Tools.PlantCorn, DataTypes.Tools.PlantTomato]:
			get_cell_under_mouse()
			_replant_crop()
			if can_plant_crop:
				add_crop()

func get_cell_under_mouse() -> void:
	mouse_position = tilled_soil_tilemap_layer.get_local_mouse_position()
	cell_position = tilled_soil_tilemap_layer.local_to_map(mouse_position)
	cell_source_id = tilled_soil_tilemap_layer.get_cell_source_id(cell_position)
	local_cell_position = tilled_soil_tilemap_layer.map_to_local(cell_position)
	distance = player.global_position.distance_to(local_cell_position)

# --- Main planting function ---
func add_crop() -> void:
	if distance < 20.0 and cell_source_id != -1:
		if ToolManager.selected_tool == DataTypes.Tools.PlantCorn:
			var corn_instance = corn_plant_scene.instantiate() as Node2D
			corn_instance.global_position = local_cell_position
			get_parent().find_child("CropFields").add_child(corn_instance)
		elif ToolManager.selected_tool == DataTypes.Tools.PlantTomato:
			var tomato_instance = tomato_plant_scene.instantiate() as Node2D
			tomato_instance.global_position = local_cell_position
			get_parent().find_child("CropFields").add_child(tomato_instance)

# --- Prevent stacking crops, allow replanting ---
func _replant_crop() -> void:
	can_plant_crop = true  # Reset flag
	if distance > 20.0:
		can_plant_crop = false
		return
	
	var crop_nodes = get_parent().find_child("CropFields").get_children()
	for node in crop_nodes:
		if node.global_position == local_cell_position:
			if node.has_signal("is_crop"):
				if node.has_signal("too_old"):
					print("crop too old, cannot replant")
					can_plant_crop = false
				else:
					print("replanting crop")
					node.on_crop_harvesting()  # Harvest the existing crop first

# --- Remove crop manually ---
func remove_crop() -> void:
	if distance < 20.0:
		var crop_nodes = get_parent().find_child("CropFields").get_children()
		for node in crop_nodes:
			if node.global_position == local_cell_position:
				if node.has_signal("is_crop"):
					node._on_crop_harvesting()
