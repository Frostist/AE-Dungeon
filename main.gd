extends Node2D

enum State { PLAYING, GAME_OVER }

const OBSTACLE_SCENE: PackedScene = preload("res://obstacle.tscn")
const INITIAL_MIN_INTERVAL: float = 1.5
const INITIAL_MAX_INTERVAL: float = 3.0
const MIN_INTERVAL_FLOOR: float = 0.8
const MAX_INTERVAL_FLOOR: float = 1.2

var state: State = State.PLAYING
var current_min_interval: float = INITIAL_MIN_INTERVAL
var current_max_interval: float = INITIAL_MAX_INTERVAL
var speed_elapsed: float = 0.0
var interval_elapsed: float = 0.0

@onready var player: CharacterBody2D = $Player
@onready var obstacle_container: Node2D = $ObstacleContainer
@onready var spawn_timer: Timer = $Timer
@onready var score_label: Label = $UI/ScoreLabel
@onready var game_over_panel: PanelContainer = $UI/GameOverPanel

func _ready() -> void:
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.wait_time = randf_range(current_min_interval, current_max_interval)
	spawn_timer.start()

func _process(delta: float) -> void:
	if state != State.PLAYING:
		return

	GameState.score += delta
	score_label.text = "Score: %d" % int(GameState.score)

	speed_elapsed += delta
	if speed_elapsed >= 5.0:
		speed_elapsed -= 5.0
		GameState.speed = minf(GameState.speed + 10.0, GameState.MAX_SPEED)

	interval_elapsed += delta
	if interval_elapsed >= 10.0:
		interval_elapsed -= 10.0
		current_min_interval = maxf(current_min_interval - 0.1, MIN_INTERVAL_FLOOR)
		current_max_interval = maxf(current_max_interval - 0.1, MAX_INTERVAL_FLOOR)

func _unhandled_input(event: InputEvent) -> void:
	if state == State.GAME_OVER and event.is_action_pressed("jump"):
		GameState.reset()
		get_tree().reload_current_scene()

func _on_spawn_timer_timeout() -> void:
	var obstacle: Area2D = OBSTACLE_SCENE.instantiate()
	obstacle.position = Vector2(1200, 480)
	obstacle_container.add_child(obstacle)
	obstacle.body_entered.connect(_on_obstacle_hit)
	spawn_timer.wait_time = randf_range(current_min_interval, current_max_interval)
	spawn_timer.start()

func _on_obstacle_hit(body: Node2D) -> void:
	if body.is_in_group("player") and state == State.PLAYING:
		_game_over()

func _game_over() -> void:
	state = State.GAME_OVER
	spawn_timer.stop()
	player.disable()
	game_over_panel.visible = true
