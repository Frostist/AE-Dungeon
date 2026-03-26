extends Node

const INITIAL_SPEED: float = 300.0
const MAX_SPEED: float = 900.0

var speed: float = INITIAL_SPEED
var score: float = 0.0

func reset() -> void:
	speed = INITIAL_SPEED
	score = 0.0
