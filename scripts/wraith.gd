extends CharacterBody2D

@export var word_health: int = 2 
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var blood_splatter: GPUParticles2D = $BloodSplatter
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $BloodSplatterAudio

var is_dying: bool = false

func die(attack_direction: Vector2 = Vector2.ZERO) -> void:
	if is_dying:
		return
		
	is_dying = true
	set_physics_process(false)
	
	animated_sprite_2d.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if attack_direction != Vector2.ZERO:
		# Rotate the emitter to face the slash direction
		blood_splatter.rotation = attack_direction.angle()
		
	blood_splatter.emitting = true
	blood_splatter.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var global_spawn_pos: Vector2 = blood_splatter.global_position
	remove_child(blood_splatter)
	get_tree().current_scene.add_child(blood_splatter)
	blood_splatter.global_position = global_spawn_pos
	
	get_tree().create_timer(blood_splatter.lifetime).timeout.connect(blood_splatter.queue_free)
	audio_stream_player_2d.play()
	animated_sprite_2d.play("death")
	await animated_sprite_2d.animation_finished
	
	queue_free()
