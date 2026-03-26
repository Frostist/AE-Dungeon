extends CharacterBody2D

const GRAVITY: float = 1800.0
const JUMP_VELOCITY: float = -900.0

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	move_and_slide()

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func disable() -> void:
	set_physics_process(false)
