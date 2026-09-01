extends Area2D

# Expose options to the Inspector so you can place different crystal types in the level
@export_enum("dash", "jump", "both") var refill_type: String = "both"
@export var respawn_time: float = 2.5

func _ready() -> void:
	# Ensure the collision mask matches your Player layer
	collision_mask = 1 
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("add_charge"):
		body.add_charge(refill_type)
		_trigger_respawn_cycle()

func _trigger_respawn_cycle() -> void:
	# Disable interaction and visibility instantly
	set_deferred("monitoring", false)
	visible = false
	
	await get_tree().create_timer(respawn_time).timeout
	
	# Re-enable the item
	visible = true
	set_deferred("monitoring", true)
	
	# Optional: Add a tween here to fade it back in smoothly
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
