extends Node2D

const GRID_COLS: int = 6
const GRID_ROWS: int = 8
const ENTRY_ROW: int = 0
const ENTRY_COL: int = 2
const EXIT_ROW: int = 7
const EXIT_COL: int = 2

@export var room_origin: Vector2 = Vector2(32, 48)
@export var cell_size: Vector2 = Vector2(32, 32)

@onready var entities: Node2D = $Entities
@onready var exit_door: Area2D = $ExitDoor
@onready var hud = $HUD
@onready var player = $Player

var exit_locked: bool = true
var active_enemies: Array = []

signal exit_reached

func _ready() -> void:
	exit_door.body_entered.connect(_on_exit_door_body_entered)
	hud.attack_pressed.connect(_on_attack_pressed)
	player.tapped.connect(_on_player_tapped)
	_lock_exit(true)
	hud.refresh()

func grid_to_world(row: int, col: int) -> Vector2:
	return room_origin + Vector2(col * cell_size.x, row * cell_size.y) + cell_size / 2

func _lock_exit(locked: bool) -> void:
	exit_locked = locked
	$ExitDoorSprite.modulate = Color(0.4, 0.4, 0.4) if locked else Color(1, 1, 1)

func _on_exit_door_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not exit_locked:
		exit_reached.emit()

func _on_attack_pressed() -> void:
	pass  # implemented in Task 8

func _on_player_tapped(_pos: Vector2) -> void:
	pass  # implemented in Task 8

func check_exit_unlock() -> void:
	if active_enemies.is_empty():
		_lock_exit(false)
