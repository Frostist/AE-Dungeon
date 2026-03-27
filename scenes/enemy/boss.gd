extends "res://scenes/enemy/enemy.gd"

var _taunt_bonus_active: bool = false

func setup_boss(floor_num: int) -> void:
	enemy_type = "boss"
	var boss_floor: int = floor_num / 5
	hp = 150 + boss_floor * 30
	max_hp = hp
	attack_damage = 20 + boss_floor * 5
	gold_min = 50
	gold_max = 100
	_update_hp_bar()

func _physics_process(delta: float) -> void:
	_attack_timer += delta
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	match behavior:
		"attack":
			_move_toward(player.global_position, ATTACK_SPEED, delta)
			if global_position.distance_to(player.global_position) <= MELEE_RANGE:
				_try_boss_attack(player)
		"taunt":
			velocity = Vector2.ZERO
			_taunt_bonus_active = true
		"charge":
			_move_toward(player.global_position, CHARGE_SPEED, delta)
			if global_position.distance_to(player.global_position) <= MELEE_RANGE:
				_try_boss_attack(player)
		"patrol":
			_patrol(delta)
		"flee":
			_move_away_from(player.global_position, PATROL_SPEED, delta)
	move_and_slide()

func _try_boss_attack(player: Node) -> void:
	if _attack_timer >= ATTACK_COOLDOWN:
		_attack_timer = 0.0
		var dmg: int = attack_damage * 2 if _taunt_bonus_active else attack_damage
		_taunt_bonus_active = false
		player.take_damage(dmg)
