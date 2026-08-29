extends CharacterBody2D

# --- Movement Metrics ---
@export var max_speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 2500.0
@export var air_resistance: float = 1200.0

# --- Jump Metrics ---
@export var jump_force: float = -500.0
@export var jump_cut_multiplier: float = 0.4
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 800.0

# --- Forgiveness Mechanics ---
@export var coyote_time: float = 0.15
var coyote_timer: float = 0.0

@export var jump_buffer_time: float = 0.1
var jump_buffer_timer: float = 0.0

var is_typing: bool = false

# --- Skill Metrics ---
@export var double_jump_force: float = -600.0
@export var dash_speed: float = 1200.0
@export var dash_duration: float = 0.2

var is_knocked_back: bool = false
@export var knockback_recovery_time: float = 0.4

var is_dashing: bool = false
var stored_x_velocity: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var damage_flash: ColorRect = $HUD/DamageFlash

var GhostScene = preload("res://scenes/ghost.tscn")

@onready var ghost_timer = $AfterImageContainer/GhostTimer
@onready var ghost_container = $AfterImageContainer
@onready var sprite = $Sprite2D # Change to your exact sprite node name

var is_ghosting: bool = false
var last_ghost_position: Vector2 = Vector2.ZERO
@export var ghost_spacing: float = 24.0 # The exact pixel distance between ghosts

var preserve_momentum: bool = false

var combat_origin_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	Signals.start_typing_event.connect(_on_typing_started)
	Signals.typing_event_resolved.connect(_on_typing_resolved)
	Signals.typing_mistake.connect(_on_typing_mistake) # New connection
	if not ghost_timer.timeout.is_connected(_on_ghost_timer_timeout):
		ghost_timer.timeout.connect(_on_ghost_timer_timeout)

func _on_ghost_timer_timeout() -> void:
	if GhostScene == null:
		push_error("GhostScene is not loaded. Check your preload path.")
		return
		
	var ghost = GhostScene.instantiate()
	
	if ghost == null:
		print("ERROR: Ghost instantiation failed.") # <--- ADD THIS
		return
	
	# Sync position
	ghost.global_position = global_position
	
	# Sync visual texture to match the player exactly
	var player_sprite = $Sprite2D
	#if player_sprite and player_sprite.texture:
		#ghost.texture = player_sprite.texture
		#
		## If your Sprite2D uses a spritesheet (hframes/vframes), uncomment this:
		## ghost.frame = player_sprite.frame
		#
		## Sync the direction the player is facing
		#ghost.flip_h = player_sprite.flip_h 
		
	ghost_container.add_child(ghost)

func _on_typing_started(prompt: String, time_limit: float, event_type: String, zone_id: int) -> void:
	is_typing = true
	stored_x_velocity = velocity.x 
	velocity = Vector2.ZERO
	
	if event_type == "cinematic_attack":
		combat_origin_position = global_position # Store the safe starting point

func _on_typing_resolved(completed_words: int, total_words: int, event_type: String, zone_id: int) -> void:
	is_typing = false
	
	# Always restore time scale upon resolution
	if Engine.time_scale < 1.0:
		Engine.time_scale = 1.0

	if completed_words == 0:
		velocity.x = stored_x_velocity 
		return
		
	var power_ratio: float = float(completed_words) / float(total_words)
	
	match event_type:
		"double_jump":
			velocity.x = stored_x_velocity 
			velocity.y = double_jump_force * power_ratio
			preserve_momentum = true 
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			
		"dash":
			_execute_dash(power_ratio)
			
		"cinematic_attack":
			_execute_cinematic_attack(completed_words, total_words)

func _execute_cinematic_attack(completed_words: int, total_words: int) -> void:
	is_dashing = true 
	velocity = Vector2.ZERO
	
	var is_perfect: bool = (completed_words >= total_words)
	var cam: Camera2D = get_node_or_null("Camera2D")
	var sprite_node = $Sprite2D 

	# --- CHARGING / ANTICIPATION PHASE ---
	if is_perfect and cam:
		var cam_tween = create_tween()
		var super_zoom = cam.typing_zoom * 1.33 
		cam_tween.tween_property(cam, "zoom", super_zoom, 1.5).set_trans(Tween.TRANS_SINE)
		
		if sprite_node and sprite_node.material and sprite_node.material is ShaderMaterial:
			sprite_node.material.set_shader_parameter("flash_modifier", 1.0)
			var flash_tween = create_tween()
			flash_tween.tween_property(sprite_node.material, "shader_parameter/flash_modifier", 0.0, 1.0)
		
		get_tree().paused = true
		await get_tree().create_timer(1.0).timeout 
		get_tree().paused = false
	else:
		await get_tree().create_timer(0.2).timeout

	# --- SLASHING LOOP ---
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	enemies.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	
	var remaining_damage: int = completed_words
	
	for enemy in enemies:
		if remaining_damage <= 0:
			break
			
		# 1. Anchor position, force initial spawn, open process gate
		last_ghost_position = global_position
		_spawn_ghost_at(global_position)
		is_ghosting = true
		
		var dash_tween = create_tween()
		dash_tween.tween_property(self, "global_position", enemy.global_position, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		await dash_tween.finished
		
		# 2. Close process gate
		is_ghosting = false
		
		var applied_damage: int = min(remaining_damage, enemy.word_health)
		enemy.word_health -= applied_damage
		remaining_damage -= applied_damage
		
		if enemy.word_health <= 0:
			enemy.queue_free()
			
		await get_tree().create_timer(0.3).timeout 
		
	# --- RESOLUTION & ZOOM OUT ---
	if completed_words < total_words:
		# Failure State Return
		last_ghost_position = global_position
		_spawn_ghost_at(global_position)
		is_ghosting = true
		
		var return_tween = create_tween()
		return_tween.tween_property(self, "global_position", combat_origin_position, 0.15).set_trans(Tween.TRANS_SINE)
		await return_tween.finished
		
		is_ghosting = false 
		
		velocity.y = double_jump_force * 0.5 
		preserve_momentum = false 
		
		if cam and cam.has_method("force_zoom_out"):
			cam.force_zoom_out()
	else:
		# Success State
		velocity.y = double_jump_force * 0.75
		preserve_momentum = true
		
		if cam and cam.has_method("force_zoom_out"):
			cam.force_zoom_out()
		
	is_dashing = false

func _execute_dash(power_ratio: float) -> void:
	is_dashing = true
	var direction: float = 0.0
	
	if abs(stored_x_velocity) > 0.1:
		direction = sign(stored_x_velocity)
	else:
		direction = Input.get_axis("ui_left", "ui_right")
		if direction == 0.0:
			direction = 1.0 
			
	velocity.y = 0
	# Multiply the base speed by the completion ratio
	velocity.x = direction * (dash_speed * power_ratio) 
	
	await get_tree().create_timer(dash_duration).timeout
	
	is_dashing = false
	velocity.x = 0

func _on_typing_mistake() -> void:
	# 1. Create a new tween. If one is already running (from spamming keys), 
	# Godot automatically overrides it to prevent conflicts.
	var tween = create_tween()

	# 2. Instantly snap the alpha to 30% opacity
	damage_flash.modulate.a = 0.3

	# 3. Fade it smoothly back to 0.0 over 0.2 seconds
	tween.tween_property(damage_flash, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	if not is_ghosting:
		return
		
	var distance_moved: float = last_ghost_position.distance_to(global_position)
	
	# Backfill ghosts if the player moved further than the spacing in a single frame
	while distance_moved >= ghost_spacing:
		var direction: Vector2 = (global_position - last_ghost_position).normalized()
		var precise_spawn_point: Vector2 = last_ghost_position + (direction * ghost_spacing)
		
		_spawn_ghost_at(precise_spawn_point)
		
		last_ghost_position = precise_spawn_point
		distance_moved -= ghost_spacing

func _spawn_ghost_at(spawn_pos: Vector2) -> void:
	if GhostScene == null: 
		return
		
	var ghost = GhostScene.instantiate()
	ghost.global_position = spawn_pos
	
	#var player_sprite = $Sprite2D
	#if player_sprite and player_sprite.texture:
		#ghost.texture = player_sprite.texture
		#ghost.flip_h = player_sprite.flip_h 
		
	ghost_container.add_child(ghost)

func _physics_process(delta: float) -> void:
	if is_typing:
		return
		
	if is_dashing:
		# Only execute the raw horizontal velocity set by _execute_dash()
		move_and_slide()
		return
	_update_timers(delta)
	_handle_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	move_and_slide()

func _update_timers(delta: float) -> void:
	# Coyote Timer
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
		
	# Jump Buffer Timer
	jump_buffer_timer -= delta

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * fall_gravity_multiplier * delta
		else:
			velocity.y += gravity * delta
		
		velocity.y = min(velocity.y, max_fall_speed)

func _handle_jump() -> void:
	# Register the jump input into the buffer
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	# Execute jump if both timers are active
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_force
		# Consume both timers instantly to prevent double-firing
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
	
	# Variable Jump Height
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func apply_knockback(source_position: Vector2, force_x: float, force_y: float) -> void:
	# 1. State Guard: Reject all damage/knockback if executing a cinematic attack
	if is_dashing:
		return
		
	is_knocked_back = true
	preserve_momentum = false
	
	# 2. Directional Calculation
	var direction_x: float = sign(global_position.x - source_position.x)
	if direction_x == 0:
		direction_x = 1.0 
		
	velocity.x = direction_x * force_x
	velocity.y = abs(force_y) 
	
	# 3. Visual Feedback: Damage Flash
	#var damage_flash = get_node_or_null("HUD/DamageFlash")
	#if damage_flash:
		## Ensure the node is visible, snap opacity to 100%, then fade to 0%
		#damage_flash.show()
		#damage_flash.modulate.a = 1.0
		#
		#var flash_tween = create_tween()
		## Fades out over 0.2 seconds for a sharp, impactful flash
		#flash_tween.tween_property(damage_flash, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_OUT)
	
	# 4. State Recovery
	await get_tree().create_timer(knockback_recovery_time).timeout
	is_knocked_back = false

func _handle_movement(delta: float) -> void:
	if is_knocked_back:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		return

	var direction := Input.get_axis("left", "right")
	
	if direction != 0:
		preserve_momentum = false 
		velocity.x = direction * max_speed 
	else:
		if preserve_momentum and not is_on_floor():
			pass 
		else:
			preserve_momentum = false
			velocity.x = move_toward(velocity.x, 0, friction * delta)
