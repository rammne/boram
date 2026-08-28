extends Sprite2D

# Configurable decay duration
@export var fade_time: float = 0.2

func _ready() -> void:
	# 1. Setup the initial look
	modulate = Color(0, 1, 1, 0.75) # Tint Cyan and set 75% transparent
	
	# 2. Fade to fully transparent over fade_time
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	
	# 3. Destroy the node automatically when the fade finishes
	tween.finished.connect(queue_free)
