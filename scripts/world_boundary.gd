extends Area2D

@export var slow_mo_scale: float = 0.2 # Slows game to 20% speed
@export var reset_delay: float = 1.0 # Real-world seconds to wait before resetting

func _ready() -> void:
	collision_layer = 0
	# Ensure this matches your player's physics layer (default is 1 if you haven't changed it)
	collision_mask = 1 
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		# 1. Disable the boundary so it doesn't trigger repeatedly
		set_deferred("monitoring", false)
		
		# 2. Trigger slow motion
		Engine.time_scale = slow_mo_scale
		
		# 3. Wait using a timer that ignores the engine time scale
		# create_timer(time_sec, process_always, process_in_physics, ignore_time_scale)
		await get_tree().create_timer(reset_delay, false, false, true).timeout
		
		# 4. Restore normal time
		Engine.time_scale = 1.0
		
		# 5. Reload the level
		get_tree().reload_current_scene()
