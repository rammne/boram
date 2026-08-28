extends Node2D

@onready var label: RichTextLabel = $RichTextLabel
@onready var timer: Timer = $Timer
@onready var progress_bar: ProgressBar = $ProgressBar

# Replace mistake_penalty with this:
@export var penalty_percentage: float = 0.10 # Deducts 10% of total time per mistake

var cached_max_time: float = 0.0

var words: PackedStringArray = []
var current_word_index: int = 0
var target_text: String = ""
var current_index: int = 0
var active_event: String = ""
var fill_style: StyleBoxFlat 
var has_error: bool = false

var active_zone_id: int = 0

var real_time_left: float = 0.0

func _ready() -> void:
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color.WHITE
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	var default_fill = progress_bar.get_theme_stylebox("fill")
	if default_fill is StyleBoxFlat:
		fill_style = default_fill.duplicate()
	else:
		fill_style = StyleBoxFlat.new()
	
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	set_process(false)
	set_process_unhandled_key_input(false)
	hide()
	
	fill_style = StyleBoxFlat.new()
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	Signals.start_typing_event.connect(_on_typing_started)
	timer.timeout.connect(_on_timeout)

func _process(delta: float) -> void:
	var current_scale: float = Engine.time_scale

	if current_scale <= 0.0:
		current_scale = 1.0 
		
	var real_delta: float = delta / current_scale
	real_time_left -= real_delta
	# Clamp the value so it never drops below 0 and breaks the UI rendering
	progress_bar.value = max(0.0, real_time_left)
	
	if progress_bar.max_value > 0:
		var ratio: float = real_time_left / progress_bar.max_value
		fill_style.bg_color = Color.RED.lerp(Color.GREEN, ratio)
		
	if real_time_left <= 0.0:
		_resolve()
	

func _on_typing_started(prompt_data: Variant, time_limit: float, event_type: String, zone_id: int) -> void:
	active_zone_id = zone_id
	
	words = prompt_data.split(" ", false) 
	current_word_index = 0
	active_event = event_type

	cached_max_time = time_limit 
	real_time_left = time_limit
	
	progress_bar.max_value = time_limit
	progress_bar.value = time_limit
	
	_load_next_word()
	
	show()
	set_process_unhandled_key_input(true)
	set_process(true)

func _trigger_hitstop(duration: float) -> void:
	# Requires TypingUI Node process_mode to be "Always"
	get_tree().paused = true
	await get_tree().create_timer(duration, true, false, true).timeout
	get_tree().paused = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
		
	get_viewport().set_input_as_handled()
		
	if event.unicode == 0:
		return
		
	var char_typed: String = char(event.unicode)
	
	# Action-Oriented Flow: No backspace required. Just hit the right key.
	if char_typed == target_text[current_index]:
		current_index += 1
		has_error = false # Clear the visual error state instantly
		_update_display()
		
		if current_index >= target_text.length():
			current_word_index += 1
			_load_next_word()
	else:
		has_error = true
		_handle_mistake()
		_update_display()

func _update_display() -> void:
	var typed_portion: String = target_text.substr(0, current_index)
	
	if has_error:
		var error_char: String = target_text[current_index]
		var untyped_portion: String = target_text.substr(current_index + 1)
		label.text = "[center][color=green]" + typed_portion + "[/color][color=red]" + error_char + "[/color]" + untyped_portion + "[/center]"
	else:
		var untyped_portion: String = target_text.substr(current_index)
		label.text = "[center][color=green]" + typed_portion + "[/color]" + untyped_portion + "[/center]"

# Find and update your _resolve function to this:
func _resolve() -> void:
	hide()
	set_process_unhandled_key_input(false)
	set_process(false)
	timer.stop()
	
	Signals.typing_event_resolved.emit(current_word_index, words.size(), active_event, active_zone_id)

# Update the timeout function:
func _on_timeout() -> void:
	_resolve()

func _handle_mistake() -> void:
	var deduction: float = cached_max_time * penalty_percentage
	real_time_left -= deduction
	
	Signals.typing_mistake.emit() 
	
	if real_time_left <= 0.0:
		_resolve()

# Update the word completion check inside _load_next_word():
func _load_next_word() -> void:
	if current_word_index > 0:
		_trigger_hitstop(0.05) 

	if current_word_index >= words.size():
		_resolve() # All words completed
		return
		
	target_text = words[current_word_index]
	current_index = 0
	has_error = false
	_update_display()
