extends NodeState

@export var character: NonPlayableCharacter
@export var animated_sprite_2d: AnimatedSprite2D
@export var navigation_agent_2d: NavigationAgent2D
@export var min_speed: float = 5.0
@export var max_speed: float = 10.0

var speed: float

func _ready() -> void:
	randomize()  # ensure different PRNG sequence per run
	navigation_agent_2d.velocity_computed.connect(on_safe_velocity_computed)
	call_deferred("character_setup")

func character_setup() -> void:
	# let the navigation map/areas register
	await get_tree().physics_frame

	# tiny random stagger so multiple agents don't query at the exact same frame
	await get_tree().create_timer(randf_range(0.05, 0.5)).timeout

	# now pick a movement target
	set_movement_target()

func set_movement_target() -> void:
	var nav_map = navigation_agent_2d.get_navigation_map()
	if nav_map == RID():
		return

	var regions = NavigationServer2D.map_get_regions(nav_map)
	if regions.size() == 0:
		return

	# choose a region at random
	var region_rid: RID = regions[randi() % regions.size()]

	# region_get_random_point requires at least (region_rid, max_tries, border)
	var max_tries: int = 20
	var border: float = 0.0
	var target_position: Vector2 = NavigationServer2D.region_get_random_point(region_rid, max_tries, border)

	# fallback: if the call failed (Vector2.ZERO) try map_get_random_point
	if target_position == Vector2.ZERO:
		target_position = NavigationServer2D.map_get_random_point(nav_map, navigation_agent_2d.navigation_layers, true)

	navigation_agent_2d.target_position = target_position
	speed = randf_range(min_speed, max_speed)


func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	if navigation_agent_2d.is_navigation_finished():
		character.current_walk_cycle += 1
		set_movement_target()
		return
	
	var target_position: Vector2 = navigation_agent_2d.get_next_path_position()
	var target_direction: Vector2 = character.global_position.direction_to(target_position)
	
	var velocity: Vector2 = target_direction * speed
	
	if navigation_agent_2d.avoidance_enabled:
		animated_sprite_2d.flip_h = velocity.x < 0
		navigation_agent_2d.velocity = velocity
	else:
		character.velocity = velocity
		character.move_and_slide()

func on_safe_velocity_computed(safe_velocity: Vector2) -> void:
	animated_sprite_2d.flip_h = safe_velocity.x < 0
	character.velocity = safe_velocity
	character.move_and_slide()

func _on_next_transitions() -> void:
	if character.current_walk_cycle == character.walk_cycles:
		character.velocity = Vector2.ZERO
		transition.emit("Idle")


func _on_enter() -> void:
	animated_sprite_2d.play("walk")
	character.current_walk_cycle = 0


func _on_exit() -> void:
	animated_sprite_2d.stop()
