extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/enemy/boss.tscn")
const MERCHANT_SCENE := preload("res://scenes/merchant/merchant.tscn")
const CHEST_SCENE := preload("res://scenes/chest/chest.tscn")

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
@onready var chat_overlay = $ChatOverlay
@onready var shop_overlay = $ShopOverlay

var exit_locked: bool = true
var active_enemies: Array = []
var selected_enemy: CharacterBody2D = null
var _game_over_triggered: bool = false

signal exit_reached

func _ready() -> void:
	# TODO Task 14: Add PointLight2D torch nodes in editor (need circle gradient texture)
	exit_door.body_entered.connect(_on_exit_door_body_entered)
	hud.attack_pressed.connect(_on_attack_pressed)
	player.tapped.connect(_on_player_tapped)
	player.long_tapped.connect(_on_player_long_tapped)
	chat_overlay.closed.connect(func(): pass)
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
	# Check for merchant tap first
	for merchant in get_tree().get_nodes_in_group("merchants"):
		if merchant.global_position.distance_to(world_pos) < 64.0:
			if not merchant.items.is_empty():
				shop_overlay.open_with_items(merchant.items)
			else:
				if not merchant.shop_ready.is_connected(_on_merchant_shop_ready):
					merchant.shop_ready.connect(_on_merchant_shop_ready, CONNECT_ONE_SHOT)
			return
	# Check for chest tap
	for chest in get_tree().get_nodes_in_group("chests"):
		if chest.global_position.distance_to(world_pos) < 64.0:
			var loot_msg: String = chest.open()
			if not loot_msg.is_empty():
				print("Loot: ", loot_msg)
				hud.refresh()
			return

	# Deselect previous
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

func populate_grid(grid_data: Dictionary) -> void:
	var grid: Array = grid_data.get("grid", [])
	if grid.is_empty():
		check_exit_unlock()
		return
	for row in grid.size():
		for col in grid[row].size():
			var token: String = grid[row][col]
			if token == "empty":
				continue
			var world_pos: Vector2 = grid_to_world(row, col)
			_spawn_entity(token, world_pos)
	check_exit_unlock()
	EnemyAI.register_enemies(active_enemies)

func _spawn_entity(token: String, pos: Vector2) -> void:
	match token:
		"enemy:goblin", "enemy:skeleton", "enemy:orc":
			var type: String = token.split(":")[1]
			var e = ENEMY_SCENE.instantiate()
			entities.add_child(e)
			e.setup(type)
			e.global_position = pos
			_register_enemy(e)
		"boss":
			var b = BOSS_SCENE.instantiate()
			entities.add_child(b)
			b.setup_boss(GameState.floor_number)
			b.global_position = pos
			_register_enemy(b)
		"merchant":
			var m = MERCHANT_SCENE.instantiate()
			entities.add_child(m)
			m.global_position = pos
		"chest":
			var c = CHEST_SCENE.instantiate()
			entities.add_child(c)
			c.global_position = pos
		"trap":
			var trap := Area2D.new()
			var shape := CollisionShape2D.new()
			shape.shape = RectangleShape2D.new()
			shape.shape.size = Vector2(16, 16)
			trap.add_child(shape)
			var spr := ColorRect.new()
			spr.size = Vector2(14, 14)
			spr.color = Color(0.8, 0.1, 0.1)
			trap.add_child(spr)
			entities.add_child(trap)
			trap.global_position = pos
			trap.body_entered.connect(func(body):
				if body.is_in_group("player"):
					body.take_damage(10)
					trap.queue_free()
			)

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

func _on_player_long_tapped(world_pos: Vector2) -> void:
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(world_pos) < 80.0:
			if enemy.enemy_type == "boss":
				return
			var type_label: String = enemy.enemy_type.capitalize()
			chat_overlay.open_for("Dungeon %s" % type_label, enemy.enemy_type)
			return

func _on_merchant_shop_ready(items: Array) -> void:
	shop_overlay.open_with_items(items)

func _process(_delta: float) -> void:
	if GameState.hp <= 0 and not _game_over_triggered:
		_game_over_triggered = true
		get_tree().get_first_node_in_group("main").game_over()
