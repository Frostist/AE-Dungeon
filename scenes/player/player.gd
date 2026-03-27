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
		print("Player is dead, ignoring input")
		return
	
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				print("Mouse pressed at: ", mouse_event.position)
				_touch_start = mouse_event.position
				_touch_time = 0.0
				_is_touching = true
			else:
				print("Mouse released at: ", mouse_event.position)
				if _is_touching and mouse_event.position.distance_to(_touch_start) < TAP_MAX_DIST:
					var world_pos: Vector2 = get_canvas_transform().affine_inverse() * mouse_event.position
					if _touch_time >= LONG_TAP_TIME:
						print("Long tap detected at: ", world_pos)
						long_tapped.emit(world_pos)
					else:
						print("Tap detected at: ", world_pos)
						tapped.emit(world_pos)
				_is_touching = false
	elif event is InputEventMouseMotion and _is_touching:
		var motion := event as InputEventMouseMotion
		var dist: float = motion.position.distance_to(_touch_start)
		if dist > DEAD_ZONE:
			_move_dir = (motion.position - _touch_start).normalized()
			print("Mouse drag - move_dir: ", _move_dir, " dist: ", dist)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_time = 0.0
			_is_touching = true
			_move_dir = Vector2.ZERO
		else:
			if _is_touching and event.position.distance_to(_touch_start) < TAP_MAX_DIST:
				var world_pos: Vector2 = get_canvas_transform().affine_inverse() * event.position
				if _touch_time >= LONG_TAP_TIME:
					long_tapped.emit(world_pos)
				else:
					tapped.emit(world_pos)
			_is_touching = false
			_move_dir = Vector2.ZERO
	elif event is InputEventScreenDrag and _is_touching:
		var drag := event as InputEventScreenDrag
		var dist: float = drag.position.distance_to(_touch_start)
		if dist > DEAD_ZONE:
			_move_dir = (drag.position - _touch_start).normalized()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_touch_time += delta
	velocity = _move_dir * PLAYER_SPEED
	if velocity.length() > 0:
		print("Physics: velocity=", velocity, " position=", position)
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
