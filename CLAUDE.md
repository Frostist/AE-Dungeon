# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.6 2D endless runner ("Cube Runner"). No build step — open the project folder in Godot 4.6 and press F5 to run. There is no automated test suite; verification is done by running the game.

## Architecture

**Scrolling-world endless runner.** The player cube stays visually fixed; obstacles move left. A `GameState` autoload singleton owns the two shared values (`speed`, `score`) so all on-screen obstacles always reflect the current difficulty without needing to be notified.

### Key files

| File | Role |
|---|---|
| `game_state.gd` | Autoload singleton. `speed` (px/s) and `score` (seconds). `reset()` called before scene reload on restart. |
| `player.gd` | `CharacterBody2D`. Gravity + single jump. `disable()` called by main on hit. Added to `"player"` group in `_ready()`. |
| `obstacle.gd` | `Area2D`. Reads `GameState.speed` every physics frame — do **not** cache speed locally. Despawns at `position.x < -60`. |
| `main.gd` | Owns all game logic: one-shot Timer spawner, score/difficulty scaling, `_on_obstacle_hit`, `_game_over`, restart via `reload_current_scene()`. |

### Why Area2D for obstacles

Obstacles use `Area2D` (not `StaticBody2D`). Directly setting `position` on a `StaticBody2D` each frame doesn't reliably update Godot 4's physics broadphase. `Area2D.body_entered` is connected per-instance in `_on_spawn_timer_timeout` after `add_child`.

### Collision geometry

All bottoms align at Y=580 (ground top):
- Player: body at (200, 516), CollisionShape2D center offset (32, 32) → shape spans Y 516–580
- Obstacle: spawned at Y=480, CollisionShape2D center offset (20, 50) → shape spans Y 480–580
- Ground: `StaticBody2D` at (0, 580), shape 1152×68 centered at (576, 34)

### Difficulty scaling

In `main.gd._process`: speed increases by 10 px/s every 5 seconds (capped at `GameState.MAX_SPEED = 900`). Spawn interval shrinks by 0.1s per bound every 10 seconds, floored at 0.8–1.2s. Uses subtraction accumulator pattern (`elapsed -= threshold`) to avoid drift.

## Tuning constants

| Constant | File | Value | Notes |
|---|---|---|---|
| `GRAVITY` | `player.gd` | 1800 | px/s² |
| `JUMP_VELOCITY` | `player.gd` | -900 | px/s upward; was -600, raised so cube clears obstacles |
| `INITIAL_SPEED` | `game_state.gd` | 300 | px/s |
| `MAX_SPEED` | `game_state.gd` | 900 | px/s cap |
