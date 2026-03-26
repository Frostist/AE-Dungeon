# Cube Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete 2D endless runner in Godot 4.6 where a cyan cube auto-scrolls and the player presses Space to jump over randomly spawned obstacles.

**Architecture:** Scrolling-world approach — the cube stays visually fixed while obstacles move left at increasing speed. A `GameState` Autoload singleton owns speed and score so all obstacles always reflect the current difficulty. Obstacles use `Area2D` (not `StaticBody2D` as in spec — `StaticBody2D` position updates don't reliably update the physics broadphase in Godot 4 when moved directly; `Area2D.body_entered` is the correct Godot 4 pattern for overlap detection on script-moved objects).

**Tech Stack:** Godot 4.6, GDScript, no external assets (all visuals are `ColorRect` primitives)

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `project.godot` | Modify | Add `jump` input action, `GameState` autoload, set main scene |
| `game_state.gd` | Create | Autoload singleton — owns `speed`, `score`, `reset()` |
| `obstacle.gd` | Create | `Area2D` script — scroll left, despawn, read speed from GameState |
| `obstacle.tscn` | Create | `Area2D` + `CollisionShape2D` (40×100) + `ColorRect` visual |
| `player.gd` | Create | `CharacterBody2D` — gravity, jump (with `is_on_floor()` guard), `disable()` |
| `player.tscn` | Create | `CharacterBody2D` + `CollisionShape2D` (64×64) + `ColorRect` visual |
| `main.gd` | Create | Root — spawner, score/difficulty scaling, game-over, restart |
| `main.tscn` | Create | Full scene tree: background, ground, Player instance, UI, Timer |

---

## Layout Reference

| Element | World position | Size |
|---|---|---|
| Viewport | — | 1152 × 648 |
| Ground (StaticBody2D origin) | (0, 580) | 1152 × 68 |
| Ground CollisionShape2D center | (576, 34) relative to body | 1152 × 68 |
| Player (CharacterBody2D origin = top-left of cube) | (200, 516) | 64 × 64 |
| Player CollisionShape2D center | (32, 32) relative to body | 64 × 64 |
| Obstacle (Area2D origin = top-left) | (1200, 480) on spawn | 40 × 100 |
| Obstacle CollisionShape2D center | (20, 50) relative to body | 40 × 100 |

---

## Task 1: Configure project.godot

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: Add the `jump` input action, `GameState` autoload, and main scene to `project.godot`**

Open `project.godot` and add these sections (append after the existing content):

```ini
run/main_scene="res://main.tscn"
```

Add to the existing `[application]` section:
```ini
[application]

config/name="Test-Game"
config/features=PackedStringArray("4.6", "Mobile")
config/icon="res://icon.svg"
run/main_scene="res://main.tscn"
```

Add new sections:
```ini
[autoload]

GameState="*res://game_state.gd"

[input]

jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 2: Verify project.godot**

Read back `project.godot` and confirm:
- `run/main_scene` is set to `"res://main.tscn"`
- `[autoload]` section has `GameState="*res://game_state.gd"`
- `[input]` section has the `jump` action with physical_keycode 32 (Space)

---

## Task 2: GameState autoload

**Files:**
- Create: `game_state.gd`

- [ ] **Step 1: Write `game_state.gd`**

```gdscript
extends Node

const INITIAL_SPEED: float = 300.0

var speed: float = INITIAL_SPEED
var score: float = 0.0

func reset() -> void:
	speed = INITIAL_SPEED
	score = 0.0
```

- [ ] **Step 2: Verify**

Confirm `game_state.gd` exists at `res://game_state.gd` and contains `reset()`, `speed`, and `score`.

---

## Task 3: Obstacle scene

**Files:**
- Create: `obstacle.gd`
- Create: `obstacle.tscn`

**Note:** Using `Area2D` instead of `StaticBody2D` (spec deviation). `Area2D.body_entered` is the reliable Godot 4 pattern for detecting overlap with a script-moved body.

- [ ] **Step 1: Write `obstacle.gd`**

```gdscript
extends Area2D

func _physics_process(delta: float) -> void:
	position.x -= GameState.speed * delta
	if position.x < -60.0:
		queue_free()
```

- [ ] **Step 2: Write `obstacle.tscn`**

```
[gd_scene load_steps=3 format=3 uid="uid://obstacle001"]

[ext_resource type="Script" path="res://obstacle.gd" id="1_obs"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_obs"]
size = Vector2(40, 100)

[node name="Obstacle" type="Area2D"]
script = ExtResource("1_obs")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(20, 50)
shape = SubResource("RectangleShape2D_obs")

[node name="Visual" type="ColorRect" parent="."]
offset_right = 40.0
offset_bottom = 100.0
color = Color(1, 0.267, 0, 1)
```

- [ ] **Step 3: Verify**

Confirm both files exist. Confirm `obstacle.gd` reads `GameState.speed` and calls `queue_free()`.

---

## Task 4: Player scene

**Files:**
- Create: `player.gd`
- Create: `player.tscn`

- [ ] **Step 1: Write `player.gd`**

```gdscript
extends CharacterBody2D

const GRAVITY: float = 1800.0
const JUMP_VELOCITY: float = -600.0

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	move_and_slide()

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func disable() -> void:
	set_physics_process(false)
```

- [ ] **Step 2: Write `player.tscn`**

```
[gd_scene load_steps=3 format=3 uid="uid://player001"]

[ext_resource type="Script" path="res://player.gd" id="1_plr"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_plr"]
size = Vector2(64, 64)

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_plr")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(32, 32)
shape = SubResource("RectangleShape2D_plr")

[node name="Visual" type="ColorRect" parent="."]
offset_right = 64.0
offset_bottom = 64.0
color = Color(0, 1, 1, 1)
```

- [ ] **Step 3: Verify**

Confirm both files exist. Confirm `player.gd` uses `is_on_floor()` as the jump guard (called after `move_and_slide()`). Confirm `disable()` calls `set_physics_process(false)`.

---

## Task 5: Main scene

**Files:**
- Create: `main.gd`
- Create: `main.tscn`

- [ ] **Step 1: Write `main.gd`**

```gdscript
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
		GameState.speed += 10.0

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
```

- [ ] **Step 2: Write `main.tscn`**

```
[gd_scene load_steps=4 format=3 uid="uid://main001"]

[ext_resource type="Script" path="res://main.gd" id="1_main"]
[ext_resource type="PackedScene" uid="uid://player001" path="res://player.tscn" id="2_plr"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_gnd"]
size = Vector2(1152, 68)

[node name="Main" type="Node2D"]
script = ExtResource("1_main")

[node name="Background" type="ColorRect" parent="."]
offset_right = 1152.0
offset_bottom = 648.0
color = Color(0.102, 0.102, 0.18, 1)

[node name="Ground" type="StaticBody2D" parent="."]
position = Vector2(0, 580)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Ground"]
position = Vector2(576, 34)
shape = SubResource("RectangleShape2D_gnd")

[node name="GroundVisual" type="ColorRect" parent="Ground"]
offset_right = 1152.0
offset_bottom = 68.0
color = Color(0.176, 0.208, 0.38, 1)

[node name="Player" parent="." instance=ExtResource("2_plr")]
position = Vector2(200, 516)

[node name="ObstacleContainer" type="Node2D" parent="."]

[node name="Timer" type="Timer" parent="."]
one_shot = true

[node name="UI" type="CanvasLayer" parent="."]

[node name="ScoreLabel" type="Label" parent="UI"]
offset_left = 20.0
offset_top = 20.0
offset_right = 300.0
offset_bottom = 55.0
text = "Score: 0"

[node name="GameOverPanel" type="PanelContainer" parent="UI"]
visible = false
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -80.0
offset_right = 200.0
offset_bottom = 80.0

[node name="VBoxContainer" type="VBoxContainer" parent="UI/GameOverPanel"]
anchor_right = 1.0
anchor_bottom = 1.0

[node name="GameOverLabel" type="Label" parent="UI/GameOverPanel/VBoxContainer"]
text = "Game Over"
horizontal_alignment = 1

[node name="RestartLabel" type="Label" parent="UI/GameOverPanel/VBoxContainer"]
text = "Press Space to restart"
horizontal_alignment = 1
```

- [ ] **Step 3: Verify files**

Confirm `main.gd` and `main.tscn` exist. Spot-check:
- `main.gd`: `_game_over()` calls `spawn_timer.stop()`, `player.disable()`, `game_over_panel.visible = true`
- `main.gd`: `_on_spawn_timer_timeout()` connects `body_entered` to `_on_obstacle_hit`
- `main.tscn`: Timer has `one_shot = true`
- `main.tscn`: GameOverPanel has `visible = false`
- `main.tscn`: Player node instances `res://player.tscn` at position `(200, 516)`

---

## Task 6: Smoke test checklist

Open the project in Godot 4.6 (press F5 or click the Play button). Verify each behavior:

- [ ] **Cube appears** on the left side of the screen sitting on a ground strip
- [ ] **Cube falls** briefly onto the ground when the scene starts (gravity working)
- [ ] **Press Space** → cube jumps; releases and falls back (single jump only)
- [ ] **Holding Space** does not multi-jump (is_on_floor() guard working)
- [ ] **Obstacles appear** from the right edge and scroll left
- [ ] **Obstacle speed increases** over time (5s intervals)
- [ ] **Score increments** in the top-left ("Score: 0", "Score: 1", etc.)
- [ ] **Collision with obstacle** → game freezes cube, "Game Over" panel appears, obstacles keep scrolling
- [ ] **Press Space on game over** → scene restarts, score resets to 0, speed resets

If any of these fail, check:
- **Cube falls through ground**: CollisionShape2D position (32,32) on player; ground CollisionShape2D size 1152×68 at position (576,34)
- **Jump never fires**: Confirm `jump` action has physical_keycode 32 in project.godot; confirm `is_on_floor()` is called after `move_and_slide()`
- **No obstacles spawning**: Confirm `spawn_timer.timeout` is connected in `_ready()` before `start()` is called; confirm `one_shot = true` on Timer
- **Collision not detected**: Confirm player is in `"player"` group (via `add_to_group("player")` in `_ready()`); confirm `Area2D.body_entered` is connected after `add_child(obstacle)`
- **Speed/score not resetting**: Confirm `GameState.reset()` is called before `reload_current_scene()`
