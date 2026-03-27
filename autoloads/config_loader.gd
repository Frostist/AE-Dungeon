extends Node

var gemini_api_key: String = ""

func _ready() -> void:
	var f := FileAccess.open("user://config.json", FileAccess.READ)
	if f == null or not f.is_open():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/api_key_setup.tscn")
		return
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/api_key_setup.tscn")
		return
	gemini_api_key = data.get("gemini_api_key", "")
	if gemini_api_key.is_empty():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/api_key_setup.tscn")

func save_key(key: String) -> void:
	var f := FileAccess.open("user://config.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"gemini_api_key": key}))
	gemini_api_key = key
