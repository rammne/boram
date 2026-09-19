extends Area2D



func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		get_tree().change_scene_to_file("res://scenes/testingGround.tscn")
