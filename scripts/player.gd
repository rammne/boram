extends CharacterBody2D

enum SkillType { DOUBLE_JUMP, DASH, ULTIMATE }

@export var current_level: int = 1

# --- Skill Activation Metrics ---
#@export var required_word_count: int = 3
@export var bullet_time_scale: float = 0.3
@export var base_reaction_time: float = 0.5
@export var time_per_character: float = 0.2

var thematic_pools: Dictionary = {
	SkillType.DOUBLE_JUMP: ["leap", "soar", "jump", "vault", "rise", "up", "hop"],
	SkillType.DASH: ["swift", "rush", "zoom", "bolt", "dart", "flash", "skip"],
	SkillType.ULTIMATE: ["scindas", "ferias", "frangas", "dividas", "perfores", "laniara", "impelle", "malleus", "findere", "pungira"]
}

# --- Movement Metrics ---
@export var max_speed: float = 300.0
@export var acceleration: float = 2000.0
@export var friction: float = 2500.0
@export var air_resistance: float = 1200.0

# --- Jump Metrics ---
@export var jump_force: float = -400.0
@export var jump_cut_multiplier: float = 0.4
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 800.0

# --- Forgiveness Mechanics ---
@export var coyote_time: float = 0.15
var coyote_timer: float = 0.0

@export var jump_buffer_time: float = 0.1
var jump_buffer_timer: float = 0.0

var is_typing_skill: bool = false
var is_knocked_back: bool = false
var is_dashing: bool = false
var preserve_momentum: bool = false

# --- Skill Execution Metrics ---
@export var double_jump_force: float = -300.0
@export var dash_speed: float = 1000.0
@export var dash_duration: float = 0.3
@export var knockback_recovery_time: float = 0.4

# --- Mobility Charges ---
@export var max_dash_charges: int = 3
var current_dash_charges: int = max_dash_charges

@export var max_jump_charges: int = 3
var current_jump_charges: int = max_jump_charges
var can_double_jump: bool = true

# --- Time-Based Cooldown Restrictions (Ultimate) ---
@export var ultimate_cooldown: float = 15.0 
var ultimate_last_used_time: float = -15.0

var stored_x_velocity: float = 0.0
var combat_origin_position: Vector2 = Vector2.ZERO
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var damage_flash: ColorRect = $HUD/DamageFlash
@onready var ghost_timer = $AfterImageContainer/GhostTimer
@onready var ghost_container = $AfterImageContainer
@onready var sprite = $AnimatedSprite2D
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $SwordSlash
@onready var energy_charge: AudioStreamPlayer2D = $EnergyCharge
@onready var jump_sfx: AudioStreamPlayer2D = $JumpSFX
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound
@onready var dash_sfx: AudioStreamPlayer2D = $DashSFX

var is_invulnerable: bool = false

var GhostScene = preload("res://scenes/ghost.tscn")
var is_ghosting: bool = false
var last_ghost_position: Vector2 = Vector2.ZERO
@export var ghost_spacing: float = 24.0

func _ready() -> void:
	Signals.typing_event_resolved.connect(_on_typing_resolved)
	Signals.typing_mistake.connect(_on_typing_mistake)
	Signals.dash_charges_updated.emit(current_dash_charges)
	Signals.jump_charges_updated.emit(current_jump_charges)
	if not ghost_timer.timeout.is_connected(_on_ghost_timer_timeout):
		ghost_timer.timeout.connect(_on_ghost_timer_timeout)

func _unhandled_input(event: InputEvent) -> void:
	if is_typing_skill or is_dashing or is_knocked_back:
		return

	if event.is_action_pressed("dash"):
		if current_dash_charges > 0:
			_trigger_skill(SkillType.DASH)
			get_viewport().set_input_as_handled()
		else:
			print("Out of dash charges.")
			
	elif event.is_action_pressed("db_jump") and not is_on_floor() and can_double_jump:
		if current_jump_charges > 0:
			_trigger_skill(SkillType.DOUBLE_JUMP)
			get_viewport().set_input_as_handled()
		else:
			print("Out of jump charges.")
			
	elif event.is_action_pressed("attack"):
		var current_time: float = Time.get_ticks_msec() / 1000.0
		if current_time >= ultimate_last_used_time + ultimate_cooldown:
			_trigger_skill(SkillType.ULTIMATE)
			Signals.ultimate_used.emit(ultimate_cooldown) # Broadcast to UI
			get_viewport().set_input_as_handled()

func _trigger_skill(skill: SkillType) -> void:
	is_typing_skill = true
	stored_x_velocity = velocity.x
	
	if skill == SkillType.ULTIMATE:
		combat_origin_position = global_position
	
	var prompt_data: Array = _generate_thematic_prompt(skill)
	var prompt_phrase: String = prompt_data[0]
	var calculated_time_limit: float = prompt_data[1]
	var event_string: String = _get_event_string(skill)
	
	Engine.time_scale = bullet_time_scale
	Signals.start_typing_event.emit(prompt_phrase, calculated_time_limit, event_string, get_instance_id())

func _on_typing_resolved(completed_words: int, total_words: int, event_type: String, zone_id: int) -> void:
	if zone_id != get_instance_id():
		return
		
	is_typing_skill = false
	Engine.time_scale = 1.0

	# The Ultimate bypasses the binary failure check to allow partial kills
	if event_type == "cinematic_attack":
		sprite.play("charge_attack")
		_execute_cinematic_attack(completed_words, total_words)
		return

	# Strict Binary Check for Dash and Jump
	if completed_words >= total_words and total_words > 0:
		match event_type:
			"double_jump":
				_execute_double_jump()
			"dash":
				_execute_dash()
	else:
		velocity.y += 300.0

func _execute_double_jump() -> void:
	jump_sfx.play()
	can_double_jump = false
	current_jump_charges -= 1
	Signals.jump_charges_updated.emit(current_jump_charges)
	last_ghost_position = global_position
	_spawn_ghost_at(global_position)
	is_ghosting = true
	velocity.x = stored_x_velocity 
	velocity.y = double_jump_force # Applies absolute maximum force
	preserve_momentum = true 
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	sprite.play("jump")
	get_tree().paused = true
	await get_tree().create_timer(0.5).timeout 
	get_tree().paused = false
	last_ghost_position = global_position
	_spawn_ghost_at(global_position)
	is_ghosting = false

func _execute_dash() -> void:
	dash_sfx.play()
	current_dash_charges -= 1
	Signals.dash_charges_updated.emit(current_dash_charges)
	is_dashing = true
	var direction: float = 0.0
	set_collision_mask_value(3, false)
	last_ghost_position = global_position
	_spawn_ghost_at(global_position)
	is_ghosting = true
	if abs(stored_x_velocity) > 0.1:
		direction = sign(stored_x_velocity)
	else:
		direction = Input.get_axis("left", "right")
		if direction == 0.0:
			direction = -1.0 if sprite.flip_h else 1.0
			
	velocity.y = 0
	sprite.play("dash")
	velocity.x = direction * dash_speed # Applies absolute maximum speed
	
	await get_tree().create_timer(dash_duration).timeout
	
	last_ghost_position = global_position
	_spawn_ghost_at(global_position)
	is_ghosting = false
	is_dashing = false
	velocity.x = 0
	set_collision_mask_value(3, true)
	
func add_charge(type: String, amount: int = 3) -> void:
	match type:
		"dash":
			current_dash_charges = min(current_dash_charges + amount, max_dash_charges)
			Signals.dash_charges_updated.emit(current_dash_charges)
		"jump":
			current_jump_charges = min(current_jump_charges + amount, max_jump_charges)
			Signals.jump_charges_updated.emit(current_jump_charges)
		"both":
			current_dash_charges = min(current_dash_charges + amount, max_dash_charges)
			current_jump_charges = min(current_jump_charges + amount, max_jump_charges)
			Signals.dash_charges_updated.emit(current_dash_charges)
			Signals.jump_charges_updated.emit(current_jump_charges)

func _execute_cinematic_attack(completed_words: int, total_words: int) -> void:
	BackgroundMusic.stop_track()
	ultimate_last_used_time = Time.get_ticks_msec() / 1000.0
	is_dashing = true 
	is_invulnerable = true
	velocity = Vector2.ZERO
	
	# Disable collision with enemies (assuming enemies are on Layer 2)
	# This ensures your teleport tweens do not get physically blocked
	
	set_collision_mask_value(3, false)
	
	energy_charge.process_mode = Node.PROCESS_MODE_ALWAYS
	energy_charge.play()
	
	var charge_duration: float = 3.0
	#if energy_charge.stream:
		#charge_duration = energy_charge.stream.get_length()
	
	var is_perfect: bool = (completed_words >= total_words and total_words > 0)
	var cam: Camera2D = get_node_or_null("Camera2D")
	var sprite_node = $AnimatedSprite2D

	#if is_perfect and cam:
	if sprite_node and sprite_node.material and sprite_node.material is ShaderMaterial:
		sprite_node.material.set_shader_parameter("flash_modifier", 1.0)
		var flash_tween = create_tween()
		flash_tween.tween_property(sprite_node.material, "shader_parameter/flash_modifier", 0.0, 1.0)
	
	get_tree().paused = true
	await get_tree().create_timer(charge_duration, true, false, true).timeout 
	energy_charge.stop()
	get_tree().paused = false
	#else:
		#await get_tree().create_timer(0.2).timeout

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	enemies.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	
	if cam and cam.has_method("force_attack_zoom_out"):
		cam.force_attack_zoom_out()
	
	var remaining_attacks: int = completed_words
	
	for enemy in enemies:
		if remaining_attacks <= 0:
			break
		var slash_direction: Vector2 = (enemy.global_position - global_position).normalized()
		last_ghost_position = global_position
		_spawn_ghost_at(global_position)
		is_ghosting = true
		
		var dash_tween = create_tween()
		dash_tween.tween_property(self, "global_position", enemy.global_position, 0.015).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		await dash_tween.finished
		
		
		is_ghosting = false
		enemy.die(slash_direction)
		remaining_attacks -= 1
			
		await get_tree().create_timer(0.1).timeout 
		
	#if not is_perfect:
	get_tree().paused = true
	await get_tree().create_timer(1.0).timeout 
	get_tree().paused = false
	last_ghost_position = global_position
	_spawn_ghost_at(global_position)
	is_ghosting = true
	
	var return_tween = create_tween()
	return_tween.tween_property(self, "global_position", combat_origin_position, 0.15).set_trans(Tween.TRANS_SINE)
	await return_tween.finished
	
	is_ghosting = false 
	#preserve_momentum = false 
	#else:
	preserve_momentum = true
	#velocity.y = double_jump_force * 0.2
		
	# --- RESOLUTION: Restore States ---
	is_dashing = false
	is_invulnerable = false
	set_collision_mask_value(3, true) # Re-enable enemy collision
	audio_stream_player_2d.play()
	BackgroundMusic.play_track()
	if cam and cam.has_method("force_default_zoom"):
				cam.force_default_zoom()

func reset_room_charges() -> void:
	current_dash_charges = max_dash_charges
	current_jump_charges = max_jump_charges
	Signals.dash_charges_updated.emit(current_dash_charges)
	Signals.jump_charges_updated.emit(current_jump_charges)

func _generate_thematic_prompt(skill: SkillType) -> Array:
	var active_pool: Array = thematic_pools[skill].duplicate()
	active_pool.shuffle()
	
	var selected_words: PackedStringArray = []
	var required_words: int = 1
	
	if skill == SkillType.ULTIMATE:
		# Dynamically scale word count based on active enemies
		var enemies = get_tree().get_nodes_in_group("enemies")
		required_words = max(1, enemies.size()) 
	else:
		# Use progressive scaling for standard traversal skills
		required_words = current_level 
		
	var count: int = min(required_words, active_pool.size())
	var total_characters: int = 0
	
	for i in range(count):
		var word: String = active_pool[i]
		selected_words.append(word)
		total_characters += word.length()
		
	var final_string: String = " ".join(selected_words)
	var dynamic_time: float = base_reaction_time + (total_characters * time_per_character)
	
	Engine.time_scale = bullet_time_scale / float(current_level)
	
	return [final_string, dynamic_time]

func _get_event_string(skill: SkillType) -> String:
	match skill:
		SkillType.DOUBLE_JUMP:
			return "double_jump"
		SkillType.DASH:
			return "dash"
		SkillType.ULTIMATE:
			return "cinematic_attack"
		_:
			return "unknown"

func _physics_process(delta: float) -> void:
	if is_dashing:
		move_and_slide()
		return
		
	_update_timers(delta)
	
	# Block manual standard movement/jumping if currently typing, 
	# but allow physics calculations (gravity/momentum) to execute.
	if not is_typing_skill:
		_handle_jump()
		_handle_movement(delta)
		
	_handle_gravity(delta)
	move_and_slide()

func _update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
		can_double_jump = true
	else:
		coyote_timer -= delta
		
	jump_buffer_timer -= delta

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * fall_gravity_multiplier * delta
		else:
			velocity.y += gravity * delta
		
		velocity.y = min(velocity.y, max_fall_speed)

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_force
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
	
	if velocity.y != 0 and not is_on_floor():
		sprite.play("jump")
	
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func _handle_movement(delta: float) -> void:
	if is_knocked_back:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		return

	var direction := Input.get_axis("left", "right")
	
	if direction > 0:
		sprite.flip_h = false
	elif direction < 0:
		sprite.flip_h = true
	
	if direction != 0 and is_on_floor():
		sprite.play("run")
	elif direction == 0 and is_on_floor():
		sprite.play("idle")
	
	if direction != 0:
		preserve_momentum = false 
		velocity.x = direction * max_speed 
	else:
		if not preserve_momentum or is_on_floor():
			preserve_momentum = false
			velocity.x = move_toward(velocity.x, 0, friction * delta)

func apply_knockback(source_position: Vector2, force_x: float, force_y: float) -> void:
	hurt_sound.play()
	if is_dashing or is_invulnerable:
		return
		
	is_knocked_back = true
	is_invulnerable = true 
	preserve_momentum = false
	
	# Disable physical collision with the enemy layer to prevent body-blocking
	set_collision_mask_value(3, false)
	var direction_x: float = sign(global_position.x - source_position.x)
	if direction_x == 0:
		direction_x = 1.0 
		
	velocity.x = direction_x * force_x
	
	# Contextual Vertical Knockback
	if is_on_floor():
		# Micro-bump to break floor friction. Provides zero exploitable vertical height.
		velocity.y = -50.0 
	else:
		# Spike the player downward if they are hit mid-air to ruin traversal.
		velocity.y = abs(force_y) 
		
	sprite.play("hurt")
	
	
	if damage_flash:
		damage_flash.show()
		damage_flash.modulate.a = 0.5
		var flash_tween = create_tween()
		flash_tween.tween_property(damage_flash, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(knockback_recovery_time).timeout
	
	is_knocked_back = false
	is_invulnerable = false
	set_collision_mask_value(3, true)

func _on_typing_mistake() -> void:
	var tween = create_tween()
	damage_flash.modulate.a = 0.3
	tween.tween_property(damage_flash, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	if not is_ghosting:
		return
		
	var distance_moved: float = last_ghost_position.distance_to(global_position)
	
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
	ghost_container.add_child(ghost)

func _on_ghost_timer_timeout() -> void:
	if GhostScene == null:
		push_error("GhostScene is not loaded. Check your preload path.")
		return
		
	var ghost = GhostScene.instantiate()
	
	if ghost == null:
		print("ERROR: Ghost instantiation failed.")
		return
	
	ghost.global_position = global_position
	ghost_container.add_child(ghost)
