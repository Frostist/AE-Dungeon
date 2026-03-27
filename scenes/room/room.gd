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
var selected_enemy: CharacterBody2D = null
var _game_over_triggered: bool = false

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
	if selected_enemy and is_instance_valid(selected_enemy):
		selected_enemy.take_damage(GameState.weapon.damage)
		hud.refresh()
		if not is_instance_valid(selected_enemy):
			selected_enemy = null
			hud.set_attack_enabled(false)
			check_exit_unlock()

func _on_player_tapped(world_pos: Vector2) -> void:
	if selected_enemy and is_instance_valid(selected_enemy):
		selected_enemy.set_selected(false)
	selected_enemy = null

	var nearest_dist: float = 80.0
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		var d: float = enemy.global_position.distance_to(world_pos)
		if d < nearest_dist:
			nearest_dist = d
			selected_enemy = enemy

	if selected_enemy:
		selected_enemy.set_selected(true)

	hud.set_attack_enabled(selected_enemy != null)

func check_exit_unlock() -> void:
	if active_enemies.is_empty():
		_lock_exit(false)

func populate_grid(grid: Array) -> void:
	# grid is Array of 8 Arrays of 6 Strings
	# Called by main.gd after AI generation; for now accepts empty array
	# Since no enemies exist yet, unlock exit immediately
	check_exit_unlock()

func _register_enemy(enemy: CharacterBody2D) -> void:
	active_enemies.append(enemy)
	enemy.died.connect(_on_enemy_died)

func _on_enemy_died(enemy: CharacterBody2D, gold: int) -> void:
	active_enemies.erase(enemy)
	GameState.gold += gold
	if selected_enemy == enemy:
		selected_enemy = null
		hud.set_attack_enabled(false)
	hud.refresh()
	check_exit_unlock()

func _process(_delta: float) -> void:
	if GameState.hp <= 0 and not _game_over_triggered:
		_game_over_triggered = true
		get_tree().get_first_node_in_group("main").game_over()
