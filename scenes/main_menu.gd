extends Control

@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton
@onready var typing_test_button: Button = $MarginContainer/VBoxContainer/TypingTestButton
@onready var main_menu_music: AudioStreamPlayer = $MainMenuMusic

func _ready() -> void:
	main_menu_music.play()
	# Forces initial UI focus for keyboard/controller navigation
	start_button.grab_focus()
	
	start_button.pressed.connect(_on_start_pressed)
	typing_test_button.pressed.connect(_on_typing_test_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_typing_test_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/testingGround.tscn")
