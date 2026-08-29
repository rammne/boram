extends CharacterBody2D

@export var word_health: int = 2 

func _process(_delta: float) -> void:
	if word_health <= 0:
		queue_free() # Dies instantly when health reaches 0
