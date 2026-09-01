extends Area2D

@export var attack_pool: Array[String] = ["scinde ", "feri", "frange", "divide", "perfora"]
@export var base_reaction_time: float = 1.0
@export var time_per_character: float = 0.2
@export var bullet_time_scale: float = 0.1

var tracked_enemies: Array = []
var total_required_words: int = 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Player mask
	body_entered.connect(_on_body_entered)
	Signals.typing_event_resolved.connect(_on_typing_event_resolved)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_initialize_combat()

func _initialize_combat() -> void:
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	tracked_enemies.clear()
	total_required_words = 0
	
	# Iterate through all enemies in the scene without checking for physical overlap
	for enemy in all_enemies:
		tracked_enemies.append(enemy)
		total_required_words += enemy.word_health
			
	if total_required_words == 0:
		return # Abort if the arena is already empty

	Engine.time_scale = bullet_time_scale
	
	var prompt_data: Array = _generate_combat_prompt(total_required_words)
	Signals.start_typing_event.emit(prompt_data[0], prompt_data[1], "cinematic_attack", get_instance_id())
	
	# Disable the zone and hide the collectible graphic
	set_deferred("monitoring", false)
	visible = false

func _generate_combat_prompt(word_count: int) -> Array:
	var selected_words: PackedStringArray = []
	var total_characters: int = 0
	
	for i in range(word_count):
		var word: String = attack_pool.pick_random()
		selected_words.append(word)
		total_characters += word.length()
		
	var final_string: String = " ".join(selected_words)
	var dynamic_time: float = base_reaction_time + (total_characters * time_per_character)
	
	return [final_string, dynamic_time]

func _on_typing_event_resolved(_completed_words: int, _total_words: int, event_type: String, zone_id: int) -> void:
	if event_type == "cinematic_attack" and zone_id == get_instance_id():
		queue_free() # Destroy the zone so it cannot be triggered again
