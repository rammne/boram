extends Camera2D

# Shake parameters
@export var base_shake_increment: float = 4.0
@export var max_shake_limit: float = 12.0
@export var shake_decay_rate: float = 15.0

# Zoom parameters
@export var default_zoom: Vector2 = Vector2(1.0, 1.0)
@export var typing_zoom: Vector2 = Vector2(1.5, 1.5)
@export var zoom_duration: float = 0.2
@export var attack_zoom: Vector2 = Vector2(0.3, 0.3)

@export var target: Node2D
@export var smoothing_speed: float = 8.0

var current_shake_strength: float = 0.0

func _ready() -> void:
	Signals.typing_mistake.connect(_on_typing_mistake)
	Signals.start_typing_event.connect(_on_typing_started)
	Signals.typing_event_resolved.connect(_on_typing_event_resolved)
	
	top_level = true 
	if target:
		global_position = target.global_position.round()

func _on_typing_mistake() -> void:
	# Additive stacking
	current_shake_strength += base_shake_increment
	if current_shake_strength > max_shake_limit:
		current_shake_strength = max_shake_limit

func _on_typing_started(_prompt: Variant, _time_limit: float, _event_type: String, _zone_id: int) -> void:
	_tween_zoom(typing_zoom)

func _on_typing_event_resolved(_completed_words: int, _total_words: int, event_type: String, _zone_id: int) -> void:
	# Do NOT zoom out automatically if the attack needs a cinematic sequence.
	# The Player script will call zoom out manually later.
	#if event_type == "cinematic_attack":
		#return 
		
	# Standard zoom out for Jump/Dash zones
	_tween_zoom(default_zoom)

func force_attack_zoom_out() -> void:
	_tween_zoom(attack_zoom)

func force_default_zoom() -> void:
	_tween_zoom(default_zoom)

func _tween_zoom(target_zoom: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "zoom", target_zoom, zoom_duration).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	if current_shake_strength > 0:
		current_shake_strength = lerpf(current_shake_strength, 0.0, shake_decay_rate * delta)
		offset = _get_random_offset()
		
		if current_shake_strength < 0.1:
			current_shake_strength = 0.0
			offset = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if target:
		# 1. Calculate the smooth fractional movement
		var smooth_position = global_position.lerp(target.global_position, smoothing_speed * delta)
		
		# 2. Force the final rendering coordinate to a strict integer
		global_position = smooth_position.round()

func _get_random_offset() -> Vector2:
	return Vector2(
		randf_range(-current_shake_strength, current_shake_strength),
		randf_range(-current_shake_strength, current_shake_strength)
	)
