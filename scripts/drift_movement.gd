extends Node

# Node references assigned in the Inspector
@export var body: CharacterBody2D
@export var vision_area: Area2D
@onready var sprite: AnimatedSprite2D = $"../AnimatedSprite2D"

# Movement metrics
@export var speed: float = 120.0

var target_player: CharacterBody2D = null

func _ready() -> void:
	if not body or not vision_area or not sprite:
		push_error("DriftMovement: Missing body, vision_area, or sprite assignment.")
		return
		
	vision_area.body_entered.connect(_on_vision_entered)
	vision_area.body_exited.connect(_on_vision_exited)

func _physics_process(delta: float) -> void:
	if not body:
		return
		
	if not target_player:
		body.velocity = body.velocity.move_toward(Vector2.ZERO, speed * delta * 5.0)
		sprite.play("idle")
	else:
		var direction: Vector2 = (target_player.global_position - body.global_position).normalized()
		body.velocity = direction * speed
		sprite.play("flying")
		
		# Flip the sprite based on the X direction
		if direction.x != 0:
			sprite.flip_h = direction.x > 0

	body.move_and_slide()

func _on_vision_entered(entered_body: Node2D) -> void:
	if entered_body.name == "Player":
		target_player = entered_body

func _on_vision_exited(exited_body: Node2D) -> void:
	if exited_body == target_player:
		target_player = null
