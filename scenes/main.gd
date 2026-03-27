extends Node

const ROOM_SCENE: PackedScene = preload("res://scenes/room/room.tscn")
const GAME_OVER_SCENE: String = "res://scenes/ui/game_over.tscn"  # created in Task 12

var current_room: Node = null

func _ready() -> void:
	add_to_group("main")
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

	RoomGenerator.room_ready.connect(_on_room_ready, CONNECT_ONE_SHOT)
	RoomGenerator.request_room(GameState.floor_number, GameState.room_number)

func _on_room_ready(grid_data: Dictionary) -> void:
	if current_room and is_instance_valid(current_room):
		if current_room.has_method("set_door_loading"):
			current_room.set_door_loading(false)
	current_room = preload("res://scenes/room/room.tscn").instantiate()
	add_child(current_room)
	current_room.exit_reached.connect(_on_exit_reached)
	current_room.populate_grid(grid_data)

func _on_exit_reached() -> void:
	_load_next_room()

func game_over() -> void:
	if current_room:
		EnemyAI.clear_queue()
		current_room.queue_free()
	get_tree().change_scene_to_file(GAME_OVER_SCENE)
