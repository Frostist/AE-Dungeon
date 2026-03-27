extends Control

@onready var key_input: LineEdit = $VBoxContainer/KeyInput
@onready var error_label: Label = $VBoxContainer/ErrorLabel

func _on_confirm_button_pressed() -> void:
	var key := key_input.text.strip_edges()
	if key.is_empty():
		error_label.text = "Key cannot be empty."
		error_label.show()
		return
	ConfigLoader.save_key(key)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
