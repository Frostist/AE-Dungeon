extends CharacterBody2D

const PLAYER_SPEED: float = 180.0
const DEAD_ZONE: float = 10.0
const TAP_TIME: float = 0.15
const TAP_MAX_DIST: float = 10.0
const LONG_TAP_TIME: float = 0.4

var _touch_start: Vector2 = Vector2.ZERO
var _touch_time: float = 0.0
var _is_touching: bool = false
var _move_dir: Vector2 = Vector2.ZERO
var is_dead: bool = false

signal tapped(world_pos: Vector2)
signal long_tapped(world_pos: Vector2)

func _ready() -> void:
	add_to_group("player")

func _input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_time = 0.0
			_is_touching = true
			_move_dir = Vector2.ZERO
		else:
			if _is_touching and event.position.distance_to(_touch_start) < TAP_MAX_DIST:
				var world_pos := get_viewport().get_canvas_transform().affine_inverse() * event.position
				if _touch_time >= LONG_TAP_TIME:
					long_tapped.emit(world_pos)
				else:
					tapped.emit(world_pos)
			_is_touching = false
			_move_dir = Vector2.ZERO
	elif event is InputEventScreenDrag and _is_touching:
		var dist := event.position.distance_to(_touch_start)
		if dist > DEAD_ZONE:
			_move_dir = (event.position - _touch_start).normalized()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_touch_time += delta
	velocity = _move_dir * PLAYER_SPEED
	move_and_slide()

func take_damage(amount: int) -> void:
	GameState.hp = max(0, GameState.hp - amount)
	if GameState.hp == 0:
		die()

func die() -> void:
	is_dead = true
	set_physics_process(false)

func disable() -> void:
	die()
