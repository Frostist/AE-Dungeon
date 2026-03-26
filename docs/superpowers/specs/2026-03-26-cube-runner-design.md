# Cube Runner — Design Spec
**Date:** 2026-03-26

## Overview

A 2D endless runner in Godot 4.6. A colored square (the player) auto-advances through a scrolling world. The player presses Spacebar to jump over randomly spawned obstacles. The game ends on collision. Score is time survived; difficulty scales over time.

---

## Viewport & Layout

- **Viewport size:** 1152×648 (Godot default)
- **Ground Y:** 580 (top of ground strip; strip is 68px tall, reaching the bottom edge)
- **Ground strip:** `StaticBody2D` at Y=580, full width, 68px tall
- **Player start position:** X=200, Y=516 (sitting on top of the ground; cube is 64×64)
- **Obstacle spawn X:** 1200 (just off the right edge)
- **Obstacle spawn Y:** 480 (bottom of obstacle aligns with ground top; obstacle is 40×100)
- **Obstacle despawn X:** -60 (just off the left edge)

---

## Architecture

Three scenes + a main scene:

| Scene | Script | Role |
|---|---|---|
| `main.tscn` | `main.gd` | Root: game state, spawner timer, score, game-over UI, restart |
| `player.tscn` | `player.gd` | `CharacterBody2D`: gravity, jump, collision detection |
| `obstacle.tscn` | `obstacle.gd` | `StaticBody2D`: scrolls left, frees when off-screen |

### Node hierarchy for `main.tscn`

```
Main (Node2D)  [main.gd]
├── Background (ColorRect)          — full viewport, dark grey
├── Ground (StaticBody2D)
│   ├── CollisionShape2D            — rectangle, full width × 68px
│   └── GroundVisual (ColorRect)    — same size, dark colour
├── Player (instance of player.tscn)
├── ObstacleContainer (Node2D)      — parent for spawned obstacles
├── Timer (Timer)                   — one-shot, controls spawn interval
└── UI (CanvasLayer)
    ├── ScoreLabel (Label)          — top-left
    └── GameOverPanel (PanelContainer, hidden by default)
        └── VBoxContainer
            ├── GameOverLabel (Label)  "Game Over"
            └── RestartLabel (Label)  "Press Space to restart"
```

---

## Components

### Player (`CharacterBody2D`) — `player.gd`

- Visual: `ColorRect` 64×64, cyan (`#00ffff`)
- `CollisionShape2D`: `RectangleShape2D` 64×64 — sibling of the `ColorRect` under `CharacterBody2D`
- **Gravity:** applied each `_physics_process` frame (`velocity.y += GRAVITY * delta`, GRAVITY = 1800)
- **Jump:** if `Input.is_action_just_pressed("jump")` AND `is_on_floor()` → `velocity.y = JUMP_VELOCITY` (JUMP_VELOCITY = -600). `is_on_floor()` is authoritative (checked after `move_and_slide()`).
- **Collision detection:** after `move_and_slide()`, loop `get_slide_collision_count()`. For each collision, check if `get_slide_collision(i).get_collider()` is in the `"obstacle"` group → emit `hit` signal. Input processing is disabled on hit (`set_physics_process(false)`).
- **Signal:** `signal hit`

### Ground

- `StaticBody2D` with `CollisionShape2D` (`RectangleShape2D`, 1152×68px)
- Visual: `ColorRect` full width, 68px tall, dark colour

### Obstacle (`StaticBody2D`) — `obstacle.gd`

- Visual: `ColorRect` 40×100, orange-red (`#ff4400`)
- `CollisionShape2D`: `RectangleShape2D` 40×100
- Added to `"obstacle"` group
- `speed` is **not** stored locally. Each `_physics_process`, obstacle reads `GameState.speed` (an Autoload singleton) so all on-screen obstacles always move at the current global speed.
- Movement: `position.x -= GameState.speed * delta`
- Self-destructs when `position.x < -60`

### GameState Autoload — `game_state.gd`

- Registered as Autoload singleton `GameState`
- `var speed: float = 300.0` — current scroll speed (px/s)
- `var score: float = 0.0` — time elapsed
- `func reset()` — restores speed and score to initial values

### Spawner logic (inside `main.gd`)

- `Timer` node configured as **one-shot** (`one_shot = true`)
- On `timeout`:
  1. Instantiate `obstacle.tscn`, position at (1200, 480), add to `ObstacleContainer`
  2. Set new `wait_time = randf_range(current_min_interval, current_max_interval)`
  3. Call `timer.start()` (restarts timer with new wait_time)
- Initial interval range: 1.5–3.0s
- Minimum floor: 0.8s (both ends floor at 0.8–1.2s minimum)

### Game State & Difficulty (`main.gd`)

States: `PLAYING`, `GAME_OVER`

**While PLAYING (each frame):**
- `GameState.score += delta` → update ScoreLabel
- Every 5 seconds: `GameState.speed += 10`
- Every 10 seconds: shrink spawn interval range by 0.1s per bound, floor at (0.8, 1.2)

**On `player.hit` signal:**
- State → `GAME_OVER`
- `timer.stop()` — stops spawner
- Show `GameOverPanel`
- Existing obstacles continue to scroll off-screen naturally (intentional; no freeze needed)

**Note on restart state reset:** `main.gd`'s local difficulty variables (`current_min_interval`, `current_max_interval`) are reset by `reload_current_scene()`, not by `GameState.reset()`. Scene reload is the only supported restart path. If this ever changes to an in-place restart, `main.gd` local state and `ObstacleContainer` children must be manually reset/cleared.

**Score display format:** `"Score: {n}"` where `n` is the integer floor of elapsed seconds (e.g. `"Score: 12"`).

**Input during `GAME_OVER`:**
- `_unhandled_input`: if Space pressed → `GameState.reset()` + `get_tree().reload_current_scene()`
- Player's own input is already disabled via `set_physics_process(false)` on hit — no jump conflict

---

## Input Map

Add in Project Settings → Input Map:

| Action | Key |
|---|---|
| `jump` | Spacebar |

---

## Data Flow

```
GameState (Autoload)
  ├── speed — read by every Obstacle each frame
  └── score — updated by main.gd

main.gd
  ├── Timer (one-shot) → on timeout → spawn Obstacle → set new wait_time → restart Timer
  ├── Each frame: update score, scale speed + spawn interval
  ├── player.hit → GAME_OVER → timer.stop() → show GameOverPanel
  └── Space (GAME_OVER) → GameState.reset() → reload scene

player.gd
  ├── _physics_process: apply gravity, check jump input (is_on_floor guard), move_and_slide
  └── post-slide: check colliders for "obstacle" group → emit hit
```

---

## Visuals (no assets needed)

| Element | Color |
|---|---|
| Background | Dark grey `#1a1a2e` |
| Ground | Slate `#2d3561` |
| Player | Cyan `#00ffff` |
| Obstacles | Orange-red `#ff4400` |
| Score text | White |
| Game Over text | White |

---

## What's Out of Scope

- Sound / music
- Animations
- Multiple obstacle types
- High score persistence
- Mobile touch input
