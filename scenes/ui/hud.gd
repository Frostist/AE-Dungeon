extends CanvasLayer

@onready var floor_label: Label = $Control/FloorLabel
@onready var hp_bar: ProgressBar = $Control/BottomHUD/VBoxContainer/HPBar
@onready var weapon_label: Label = $Control/BottomHUD/VBoxContainer/WeaponLabel
@onready var attack_button: Button = $Control/AttackButton

signal attack_pressed

func _ready() -> void:
	attack_button.pressed.connect(_on_attack_pressed)
	refresh()

func refresh() -> void:
	hp_bar.value = GameState.hp
	floor_label.text = "FLOOR %d · ROOM %d" % [GameState.floor_number, GameState.room_number]
	if GameState.weapon:
		weapon_label.text = GameState.weapon.weapon_name

func set_attack_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled

func _on_attack_pressed() -> void:
	attack_pressed.emit()
