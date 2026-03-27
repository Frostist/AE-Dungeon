extends Node

const ROOM_SCENE: PackedScene = preload("res://scenes/room/room.tscn")
const GAME_OVER_SCENE: String = "res://scenes/ui/game_over.tscn"  # created in Task 12

var current_room: Node = null

func _ready() -> void:
	GameState.reset()
	_load_next_room()

func _load_next_room() -> void:
	if current_room:
		EnemyAI.clear_queue()
		current_room.queue_free()
		current_room = null

	GameState.room_number += 1
	if GameState.room_number > 5:
		GameState.room_number = 1
		GameState.floor_number += 1

	current_room = ROOM_SCENE.instantiate()
	add_child(current_room)
	current_room.exit_reached.connect(_on_exit_reached)

	# Request AI room generation (implemented in Task 9)
	# For now, load an empty room
	current_room.populate_grid([])

func _on_exit_reached() -> void:
	_load_next_room()

func game_over() -> void:
	if current_room:
		EnemyAI.clear_queue()
		current_room.queue_free()
	get_tree().change_scene_to_file(GAME_OVER_SCENE)
