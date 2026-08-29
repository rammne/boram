extends Node

enum AttackType { KNOCKBACK, TELEPORT }
@export var attack_type: AttackType = AttackType.KNOCKBACK

@export var body: CharacterBody2D
@export var hitbox_area: Area2D
@export var movement_component: Node 

@export var teleport_drop_distance: float = 600.0
@export var knockback_force_x: float = 600.0
@export var knockback_force_y: float = 300.0

@export var windup_time: float = 0.35
@export var charge_speed: float = 1200.0
@export var charge_duration: float = 0.4
@export var cooldown_time: float = 1.0
@export var charge_friction: float = 4000.0

var is_attacking: bool = false
var is_charging: bool = false
var target_player: CharacterBody2D = null
var player_in_hitbox: bool = false

func _ready() -> void:
	if not body or not hitbox_area or not movement_component:
		push_error("AttackComponent: Missing node assignments.")
		return
		
	hitbox_area.body_entered.connect(_on_hitbox_entered)
	hitbox_area.body_exited.connect(_on_hitbox_exited)

func _physics_process(delta: float) -> void:
	if is_charging:
		# move_and_collide returns the collision data instantly, avoiding slide logic
		var collision = body.move_and_collide(body.velocity * delta)
		if collision:
			_handle_dash_collision(collision)
	elif not is_attacking and player_in_hitbox and is_instance_valid(target_player):
		_execute_attack()

func _on_hitbox_entered(entered_body: Node2D) -> void:
	if entered_body.name == "Player":
		target_player = entered_body
		player_in_hitbox = true

func _on_hitbox_exited(exited_body: Node2D) -> void:
	if exited_body.name == "Player":
		player_in_hitbox = false

func _execute_attack() -> void:
	is_attacking = true
	movement_component.set_physics_process(false)
	body.velocity = Vector2.ZERO
	
	var sprite = body.get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, windup_time / 2.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "modulate", Color.WHITE, windup_time / 2.0).set_trans(Tween.TRANS_SINE)
		
	await get_tree().create_timer(windup_time).timeout
	
	if is_instance_valid(target_player):
		var direction = (target_player.global_position - body.global_position).normalized()
		body.velocity = direction * charge_speed
		is_charging = true
	
	await get_tree().create_timer(charge_duration).timeout
	
	is_charging = false
	body.velocity = Vector2.ZERO
	
	await get_tree().create_timer(cooldown_time).timeout
	
	is_attacking = false
	movement_component.set_physics_process(true)

func _handle_dash_collision(collision: KinematicCollision2D) -> void:
	var collider = collision.get_collider()
	
	if collider.name == "Player":
		is_charging = false
		body.velocity = Vector2.ZERO
		
		match attack_type:
			AttackType.KNOCKBACK:
				if collider.has_method("apply_knockback"):
					collider.apply_knockback(body.global_position, knockback_force_x, knockback_force_y)
			AttackType.TELEPORT:
				collider.global_position.y += teleport_drop_distance
				collider.velocity.y = 0.0
	else:
		# Homing Ricochet Mechanics: Redirects velocity strictly toward the player
		#if is_instance_valid(target_player):
			#var homing_direction = (target_player.global_position - body.global_position).normalized()
			#body.velocity = homing_direction * charge_speed
		#else:
			#body.velocity = body.velocity.bounce(collision.get_normal())
		pass
		
