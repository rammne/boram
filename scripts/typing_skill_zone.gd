extends Area2D

# 1. Define available skills as a dropdown menu
enum SkillType { DOUBLE_JUMP, DASH, ULTIMATE }
@export var skill_type: SkillType = SkillType.DOUBLE_JUMP

# 2. Keep action pacing fast: 1 to 2 words maximum
@export var required_word_count: int = 1 
@export var respawn_time: float = 2.5

@export var bullet_time_scale: float = 0.1
@export var base_reaction_time: float = 0.5 
@export var time_per_character: float = 0.2

# 3. Categorized Thematic Pools
var thematic_pools: Dictionary = {
	SkillType.DOUBLE_JUMP: ["leap", "soar", "jump", "vault", "rise", "up", "hop"],
	SkillType.DASH: ["swift", "rush", "zoom", "bolt", "dart", "flash", "skip"],
	SkillType.ULTIMATE: ["smash", "crush", "break", "burst", "strike", "blast"]
}

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 
	body_entered.connect(_on_body_entered)
	Signals.typing_event_resolved.connect(_on_typing_event_resolved)

# Update your body_entered function:
func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var prompt_data: Array = _generate_thematic_prompt()
		var prompt_phrase: String = prompt_data[0]
		var calculated_time_limit: float = prompt_data[1]
		var event_string: String = _get_event_string()
		
		Engine.time_scale = bullet_time_scale
		
		# Pass get_instance_id() as the 4th parameter
		Signals.start_typing_event.emit(prompt_phrase, calculated_time_limit, event_string, get_instance_id())
		set_deferred("monitoring", false)
		visible = false 

# Update the receiver function signature and add the ID check:
func _on_typing_event_resolved(completed_words: int, total_words: int, event_type: String, zone_id: int) -> void:
	# Only respawn if the ID matches this exact node
	if event_type == _get_event_string() and zone_id == get_instance_id():
		await get_tree().create_timer(respawn_time).timeout
		
		modulate.a = 0.0
		visible = true
		set_deferred("monitoring", true)
		
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

func _generate_thematic_prompt() -> Array:
	# Pull only from the pool matching the selected skill
	var active_pool: Array = thematic_pools[skill_type].duplicate()
	active_pool.shuffle()
	
	var selected_words: PackedStringArray = []
	var count: int = min(required_word_count, active_pool.size())
	var total_characters: int = 0
	
	for i in range(count):
		var word: String = active_pool[i]
		selected_words.append(word)
		total_characters += word.length()
		
	var final_string: String = " ".join(selected_words)
	var dynamic_time: float = base_reaction_time + (total_characters * time_per_character)
	
	return [final_string, dynamic_time]

func _get_event_string() -> String:
	match skill_type:
		SkillType.DOUBLE_JUMP:
			return "double_jump"
		SkillType.DASH:
			return "dash"
		SkillType.ULTIMATE:
			return "ultimate_attack"
		_:
			return "unknown"
