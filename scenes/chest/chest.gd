extends Area2D

var _opened: bool = false

func _ready() -> void:
	add_to_group("chests")

func open() -> String:
	if _opened:
		return ""
	_opened = true
	$Sprite.modulate = Color(0.4, 0.4, 0.4)
	return _roll_loot()

func _roll_loot() -> String:
	var floor_n: int = GameState.floor_number
	var weights: Dictionary
	if floor_n <= 4:
		weights = {"gold": 60, "health_potion": 30, "weapon": 10}
	elif floor_n <= 9:
		weights = {"gold": 45, "health_potion": 30, "weapon": 25}
	else:
		weights = {"gold": 25, "health_potion": 20, "weapon": 55}

	var roll: int = randi_range(1, 100)
	var result: String
	if roll <= weights["gold"]:
		result = "gold"
	elif roll <= weights["gold"] + weights["health_potion"]:
		result = "health_potion"
	else:
		result = "weapon"

	return _apply_loot(result)

func _apply_loot(loot_type: String) -> String:
	match loot_type:
		"gold":
			var amount: int = randi_range(
				GameState.floor_number * 5,
				GameState.floor_number * 10
			)
			GameState.gold += amount
			return "+%d gold" % amount
		"health_potion":
			GameState.hp = min(GameState.hp + 50, GameState.max_hp)
			return "+50 HP"
		"weapon":
			return _give_weapon_upgrade()
	return ""

func _give_weapon_upgrade() -> String:
	var progression: Array = ["iron_sword", "steel_sword", "magic_staff", "war_axe"]
	var weapon_paths: Dictionary = {
		"iron_sword": "res://resources/weapons/iron_sword.tres",
		"steel_sword": "res://resources/weapons/steel_sword.tres",
		"magic_staff": "res://resources/weapons/magic_staff.tres",
		"war_axe": "res://resources/weapons/war_axe.tres",
	}
	var current_type: String = ""
	if GameState.weapon:
		match GameState.weapon.damage:
			10: current_type = "iron_sword"
			20: current_type = "steel_sword"
			25: current_type = "magic_staff"
			30: current_type = "war_axe"

	var current_idx: int = progression.find(current_type)
	if current_idx == -1 or current_idx >= progression.size() - 1:
		var amount: int = randi_range(
			GameState.floor_number * 5,
			GameState.floor_number * 10
		)
		GameState.gold += amount
		return "+%d gold (max weapon)" % amount

	var next_type: String = progression[current_idx + 1]
	GameState.weapon = load(weapon_paths[next_type])
	return "Found: %s" % GameState.weapon.weapon_name
