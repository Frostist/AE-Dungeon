extends CharacterBody2D

var enemy_type: String = "goblin"
var hp: int = 0
var max_hp: int = 0
var attack_damage: int = 0
var gold_min: int = 0
var gold_max: int = 0
var behavior: String = "patrol"
var is_selected: bool = false

const PATROL_SPEED: float = 40.0
const ATTACK_SPEED: float = 70.0
const CHARGE_SPEED: float = 140.0
const MELEE_RANGE: float = 40.0

var _attack_timer: float = 0.0
const ATTACK_COOLDOWN: float = 1.5
var _patrol_dir: Vector2 = Vector2.RIGHT
var _patrol_timer: float = 0.0

signal died(enemy: CharacterBody2D, gold_amount: int)

func _ready() -> void:
	add_to_group("enemies")

func setup(type: String) -> void:
	enemy_type = type
	var stats: Dictionary = GameState.ENEMY_STATS.get(type, GameState.ENEMY_STATS["goblin"])
	hp = stats["hp"]
	max_hp = stats["hp"]
	attack_damage = stats["attack"]
	gold_min = stats["gold_min"]
	gold_max = stats["gold_max"]
	print("Enemy ", type, " spawned with HP: ", hp, "/", max_hp, " at position: ", global_position)
	_update_hp_bar()

func _physics_process(delta: float) -> void:
	_attack_timer += delta
	_patrol_timer += delta
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	match behavior:
		"attack":
			_move_toward(player.global_position, ATTACK_SPEED, delta)
			if global_position.distance_to(player.global_position) <= MELEE_RANGE:
				_try_attack(player)
		"patrol":
			_patrol(delta)
		"flee":
			_move_away_from(player.global_position, PATROL_SPEED, delta)
	move_and_slide()

func _move_toward(target: Vector2, speed: float, _delta: float) -> void:
	velocity = (target - global_position).normalized() * speed

func _move_away_from(target: Vector2, speed: float, _delta: float) -> void:
	velocity = (global_position - target).normalized() * speed

func _patrol(_delta: float) -> void:
	if _patrol_timer > 2.0:
		_patrol_timer = 0.0
		_patrol_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	velocity = _patrol_dir * PATROL_SPEED

func _try_attack(player: Node) -> void:
	if _attack_timer >= ATTACK_COOLDOWN:
		_attack_timer = 0.0
		player.take_damage(attack_damage)

func take_damage(amount: int) -> void:
	print("Enemy ", enemy_type, " took ", amount, " damage. HP: ", hp, " -> ", max(0, hp - amount))
	hp = max(0, hp - amount)
	_update_hp_bar()
	if hp == 0:
		print("Enemy ", enemy_type, " died!")
		_die()

func _die() -> void:
	var gold := randi_range(gold_min, gold_max)
	died.emit(self, gold)
	queue_free()

func set_selected(selected: bool) -> void:
	is_selected = selected
	$SelectRing.visible = selected

func _update_hp_bar() -> void:
	var pct: float = float(hp) / float(max_hp)
	var new_width: float = 20.0 * pct
	print("  Updating HP bar for ", enemy_type, ": ", hp, "/", max_hp, " (", pct * 100, "%) - bar width: ", new_width)
	$HPBarContainer/HPBarFill.size.x = new_width
