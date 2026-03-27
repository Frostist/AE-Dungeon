extends Node

var hp: int = 100
const max_hp: int = 100
var gold: int = 0
var weapon: WeaponResource
var floor_number: int = 1
var room_number: int = 0

const ENEMY_STATS: Dictionary = {
	"goblin":   { "hp": 20,  "attack": 5,  "gold_min": 5,  "gold_max": 10 },
	"skeleton": { "hp": 35,  "attack": 8,  "gold_min": 8,  "gold_max": 15 },
	"orc":      { "hp": 50,  "attack": 12, "gold_min": 12, "gold_max": 20 },
}

func _ready() -> void:
	weapon = load("res://resources/weapons/iron_sword.tres")

func reset() -> void:
	hp = max_hp
	gold = 0
	weapon = load("res://resources/weapons/iron_sword.tres")
	floor_number = 1
	room_number = 0
