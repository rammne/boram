extends CanvasLayer

@onready var ultimate_cooldown: TextureProgressBar = $SkillContainer/SkillStack/UltimateCooldown
@onready var dash_count_label: Label = $SkillContainer/SkillStack/DashUI/DashCount
@onready var jump_count_label: Label = $SkillContainer/SkillStack/JumpUI/JumpCount
@onready var cooldown_label: Label = $SkillContainer/SkillStack/UltimateCooldown/Label

var is_cooling_down: bool = false
var current_cooldown_time: float = 0.0

func _ready() -> void:
	ultimate_cooldown.max_value = 1.0 
	ultimate_cooldown.value = 1.0 
	cooldown_label.hide()
	
	Signals.ultimate_used.connect(_on_ultimate_used)
	Signals.dash_charges_updated.connect(_on_dash_charges_updated)
	Signals.jump_charges_updated.connect(_on_jump_charges_updated)

func _process(delta: float) -> void:
	if not is_cooling_down:
		return
		
	current_cooldown_time -= delta 
	ultimate_cooldown.value = ultimate_cooldown.max_value - current_cooldown_time
	cooldown_label.text = str(ceil(current_cooldown_time))
	
	if current_cooldown_time <= 0.0:
		is_cooling_down = false
		ultimate_cooldown.value = ultimate_cooldown.max_value
		cooldown_label.hide()

func _on_ultimate_used(duration: float) -> void:
	ultimate_cooldown.max_value = duration
	current_cooldown_time = duration
	ultimate_cooldown.value = 0.0 
	cooldown_label.text = str(ceil(duration))
	cooldown_label.show()
	is_cooling_down = true

func _on_dash_charges_updated(charges: int) -> void:
	dash_count_label.text = "x" + str(charges)

func _on_jump_charges_updated(charges: int) -> void:
	jump_count_label.text = "x" + str(charges)
