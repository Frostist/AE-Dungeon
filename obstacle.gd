extends Area2D

func _physics_process(delta: float) -> void:
	position.x -= GameState.speed * delta
	if position.x < -60.0:
		queue_free()
