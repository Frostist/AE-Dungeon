extends PointLight2D

func _process(_delta: float) -> void:
	energy = 0.8 + sin(Time.get_ticks_msec() * 0.003 + randf()) * 0.1
