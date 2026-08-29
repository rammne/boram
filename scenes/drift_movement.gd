extends Node

# Node references assigned in the Inspector
@export var body: CharacterBody2D
@export var vision_area: Area2D

# Movement metrics
@export var speed: float = 120.0

var target_player: CharacterBody2D = null

func _ready() -> void:
	# Validate exports to prevent null instance crashes
	if not body or not vision_area:
		push_error("DriftMovement: Missing body or vision_area assignment.")
		return
		
	vision_area.body_entered.connect(_on_vision_entered)
	vision_area.body_exited.connect(_on_vision_exited)

func _physics_process(_delta: float) -> void:
	if not body:
		return
		
	if not target_player:
		# Decelerate to a halt when the player leaves the vision radius
		body.velocity = body.velocity.move_toward(Vector2.ZERO, speed * _delta * 5.0)
	else:
		# Calculate a normalized vector toward the player and apply constant speed
		var direction: Vector2 = (target_player.global_position - body.global_position).normalized()
		body.velocity = direction * speed

	body.move_and_slide()

func _on_vision_entered(entered_body: Node2D) -> void:
	# Ensure your player node is named exactly "Player"
	if entered_body.name == "Player":
		target_player = entered_body

func _on_vision_exited(exited_body: Node2D) -> void:
	if exited_body == target_player:
		target_player = null
