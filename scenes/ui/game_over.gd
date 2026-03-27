extends Control

func _ready() -> void:
	$VBoxContainer/StatsLabel.text = "Floor %d reached\nGold collected: %d" % [
		GameState.floor_number, GameState.gold
	]
	$VBoxContainer/RestartButton.pressed.connect(_on_restart)

func _on_restart() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
