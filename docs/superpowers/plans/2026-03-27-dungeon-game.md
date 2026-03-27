# Dungeon Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a top-down pixel art dungeon roguelike for iPhone in Godot 4.6 where a Gemini AI generates room layouts, drives enemy behavior, and powers NPC conversation.

**Architecture:** Five autoloads (ConfigLoader, GameState, RoomGenerator, EnemyAI, ChatManager) manage all AI calls and shared state. Rooms are populated at runtime from a 6×8 grid returned by Gemini. Player moves freely via swipe; the grid is purely logical for spawning.

**Tech Stack:** Godot 4.6 · GDScript · Google Gemini API (gemini-2.0-flash, REST/HTTP) · iOS export (portrait, iOS 16+)

**Spec:** `docs/superpowers/specs/2026-03-27-dungeon-game-design.md`

**No automated test suite** — verification for every task is "press F5 in Godot and confirm the described behavior."

---

## File Map

| File | Responsibility |
|---|---|
| `autoloads/config_loader.gd` | Read `user://config.json`; redirect to setup screen if key missing |
| `autoloads/game_state.gd` | Player HP, gold, weapon, floor/room counters; `reset()` |
| `autoloads/room_generator.gd` | Gemini room-gen call; JSON parsing; grid validation; `room_ready` signal |
| `autoloads/enemy_ai.gd` | Sequential behavior polling queue; `clear_queue()` on room change |
| `autoloads/chat_manager.gd` | Per-NPC conversation history; Gemini chat request; typing animation |
| `resources/weapons/weapon_resource.gd` | `WeaponResource` class definition |
| `resources/weapons/*.tres` | Iron Sword, Steel Sword, War Axe, Magic Staff resource files |
| `scenes/api_key_setup.tscn` + `.gd` | First-launch key entry screen; saves to `user://config.json` |
| `scenes/main.tscn` + `.gd` | Root scene; floor/room progression; room transition + `enemy_ai.clear_queue()` |
| `scenes/room/room.tscn` + `.gd` | Walls, tile floor, entity container; populates from grid; exit door lock |
| `scenes/player/player.tscn` + `.gd` | CharacterBody2D; swipe movement; HP; weapon reference |
| `scenes/enemy/enemy.tscn` + `.gd` | CharacterBody2D; HP bar; selectable; behavior state machine |
| `scenes/enemy/boss.tscn` + `.gd` | Extends enemy.gd; boss stats; charge/taunt behavior |
| `scenes/merchant/merchant.tscn` + `.gd` | Area2D; proximity detection; triggers shop overlay |
| `scenes/chest/chest.tscn` + `.gd` | Area2D; weighted loot table; triggers loot popup |
| `scenes/ui/hud.tscn` + `.gd` | HP bar, weapon label, floor/room label, attack button |
| `scenes/ui/chat_overlay.tscn` + `.gd` | Slide-up chat panel; text input; typing animation display |
| `scenes/ui/shop_overlay.tscn` + `.gd` | Modal shop; item list; buy buttons; inline merchant chat |

---

## Phase 1 — Foundation

### Task 1: Clear Old Project and Scaffold New Structure

**Goal:** Remove the Cube Runner game files and set up the dungeon game folder structure.

**Files:**
- Delete: `game_state.gd`, `player.gd`, `player.tscn`, `main.gd`, `main.tscn`, `obstacle.gd`, `obstacle.tscn`
- Modify: `project.godot` (rename project, set main scene, register autoloads)
- Modify: `CLAUDE.md` (update to dungeon game context)
- Create: `autoloads/`, `scenes/room/`, `scenes/player/`, `scenes/enemy/`, `scenes/merchant/`, `scenes/chest/`, `scenes/ui/`, `resources/weapons/`
- Create: `.gitignore` entry for `user://` files

- [ ] **Step 1: Delete old game files**
```bash
cd /Users/willfrost/CodingProjects/Test-Game/test-game
git rm game_state.gd game_state.gd.uid player.gd player.gd.uid player.tscn \
        main.gd main.gd.uid main.tscn obstacle.gd obstacle.gd.uid obstacle.tscn \
        export_presets.cfg
```

- [ ] **Step 2: Create directory structure**
```bash
mkdir -p autoloads scenes/room scenes/player scenes/enemy scenes/merchant scenes/chest scenes/ui resources/weapons
```

- [ ] **Step 3: Add user config to .gitignore**

Append to `.gitignore`:
```
user://
*.import
.godot/
export/
```

- [ ] **Step 4: Update CLAUDE.md**

Replace contents of `CLAUDE.md` with:
```markdown
# CLAUDE.md

Godot 4.6 pixel art dungeon roguelike for iPhone. No build step — open in Godot 4.6 and press F5. No automated tests; verify by running the game.

## Architecture
- **Autoloads:** `ConfigLoader`, `GameState`, `RoomGenerator`, `EnemyAI`, `ChatManager`
- **AI backend:** Google Gemini API (gemini-2.0-flash) via HTTPRequest from GDScript
- **Room system:** 6×8 logical grid returned by Gemini; entities spawned at runtime; player moves freely
- **Controls:** Swipe to move, tap to select enemy, attack button bottom-right, long-tap NPC to chat

## Key constants
- `PLAYER_SPEED = 180` px/s
- Grid: 6 cols × 8 rows; `grid[row][col]`; doors at `grid[0][2]` (entry) and `grid[7][2]` (exit)
- Enemy melee range: 40px
- Tap threshold: < 10px movement AND < 150ms; swipe wins at exactly 10px

## Spec
`docs/superpowers/specs/2026-03-27-dungeon-game-design.md`
```

- [ ] **Step 5: Commit scaffold**
```bash
git add -A
git commit -m "chore: clear cube runner, scaffold dungeon game structure"
```

---

### Task 2: WeaponResource + GameState

**Goal:** Define the `WeaponResource` type and the `GameState` autoload that all systems share.

**Files:**
- Create: `resources/weapons/weapon_resource.gd`
- Create: `resources/weapons/iron_sword.tres`, `steel_sword.tres`, `war_axe.tres`, `magic_staff.tres`
- Create: `autoloads/game_state.gd`
- Modify: `project.godot` — register `GameState` autoload

- [ ] **Step 1: Create WeaponResource class**

Create `resources/weapons/weapon_resource.gd`:
```gdscript
class_name WeaponResource extends Resource

@export var weapon_name: String = ""
@export var damage: int = 0
@export var icon: Texture2D
```

- [ ] **Step 2: Create weapon .tres files**

In Godot editor: ResourceFile → New Resource → WeaponResource for each:
- `iron_sword.tres`: weapon_name="Iron Sword", damage=10
- `steel_sword.tres`: weapon_name="Steel Sword", damage=20
- `war_axe.tres`: weapon_name="War Axe", damage=30
- `magic_staff.tres`: weapon_name="Magic Staff", damage=25

Or create them via GDScript in a one-off tool script and save. Fields set per the table above.

- [ ] **Step 3: Create game_state.gd**

Create `autoloads/game_state.gd`:
```gdscript
extends Node

var hp: int = 100
const max_hp: int = 100
var gold: int = 0
var weapon: WeaponResource
var floor_number: int = 1
var room_number: int = 0

func _ready() -> void:
    weapon = load("res://resources/weapons/iron_sword.tres")

func reset() -> void:
    hp = max_hp
    gold = 0
    weapon = load("res://resources/weapons/iron_sword.tres")
    floor_number = 1
    room_number = 0
```

- [ ] **Step 4: Register GameState in project.godot**

In Godot editor: Project → Project Settings → Autoload → add `autoloads/game_state.gd` as `GameState`.

- [ ] **Step 5: Verify**

Press F5 (you'll get a "no main scene" error — that's fine at this stage). Open Godot's debugger and confirm no script errors in game_state.gd. In a temporary scene, add a script that prints `GameState.hp` and `GameState.weapon.weapon_name` to confirm autoload works.

- [ ] **Step 6: Commit**
```bash
git add autoloads/game_state.gd resources/weapons/
git commit -m "feat: add WeaponResource and GameState autoload"
```

---

### Task 3: ConfigLoader + API Key Setup Screen

**Goal:** On first launch, prompt for Gemini API key and persist it. Skip on subsequent launches.

**Files:**
- Create: `autoloads/config_loader.gd`
- Create: `scenes/api_key_setup.tscn` + `scenes/api_key_setup.gd`
- Modify: `project.godot` — register ConfigLoader autoload, set main scene to `api_key_setup.tscn` temporarily

- [ ] **Step 1: Create config_loader.gd**

Create `autoloads/config_loader.gd`:
```gdscript
extends Node

var gemini_api_key: String = ""

func _ready() -> void:
    var f := FileAccess.open("user://config.json", FileAccess.READ)
    if f == null or not f.is_open():
        get_tree().call_deferred("change_scene_to_file", "res://scenes/api_key_setup.tscn")
        return
    var data = JSON.parse_string(f.get_as_text())
    if data == null:
        get_tree().call_deferred("change_scene_to_file", "res://scenes/api_key_setup.tscn")
        return
    gemini_api_key = data.get("gemini_api_key", "")
    if gemini_api_key.is_empty():
        get_tree().call_deferred("change_scene_to_file", "res://scenes/api_key_setup.tscn")

func save_key(key: String) -> void:
    var f := FileAccess.open("user://config.json", FileAccess.WRITE)
    f.store_string(JSON.stringify({"gemini_api_key": key}))
    gemini_api_key = key
```

- [ ] **Step 2: Create api_key_setup.tscn scene**

In Godot editor, create `scenes/api_key_setup.tscn`:
- Root: `Control` (full rect, anchors = full screen)
  - `VBoxContainer` (centered)
    - `Label`: text = "Enter your Gemini API Key"
    - `LineEdit` (name: `KeyInput`): placeholder = "API key..."
    - `Button` (name: `ConfirmButton`): text = "Start Game"
    - `Label` (name: `ErrorLabel`): text = "", color red, hidden

Attach `api_key_setup.gd`.

- [ ] **Step 3: Create api_key_setup.gd**

Create `scenes/api_key_setup.gd`:
```gdscript
extends Control

@onready var key_input: LineEdit = $VBoxContainer/KeyInput
@onready var error_label: Label = $VBoxContainer/ErrorLabel

func _on_confirm_button_pressed() -> void:
    var key := key_input.text.strip_edges()
    if key.is_empty():
        error_label.text = "Key cannot be empty."
        error_label.show()
        return
    ConfigLoader.save_key(key)
    get_tree().change_scene_to_file("res://scenes/main.tscn")
```

Connect `ConfirmButton.pressed` → `_on_confirm_button_pressed` in the editor.

- [ ] **Step 4: Register ConfigLoader autoload**

In Godot editor: Project → Project Settings → Autoload → add `autoloads/config_loader.gd` as `ConfigLoader`. ConfigLoader must load **before** GameState — place it first in the autoload list.

- [ ] **Step 5: Verify**

Set main scene to `api_key_setup.tscn`. Press F5. Confirm setup screen appears. Enter a key and press confirm — expect a "scene not found" error for main.tscn (acceptable). Relaunch — confirm setup screen appears again (key isn't persisted yet to a real main scene flow). Delete `user://config.json` if created: in Godot, open FileSystem and look under `user://`.

- [ ] **Step 6: Commit**
```bash
git add autoloads/config_loader.gd scenes/api_key_setup.tscn scenes/api_key_setup.gd
git commit -m "feat: add ConfigLoader and API key setup screen"
```

---

### Task 4: Player Scene + Swipe Movement

**Goal:** Player CharacterBody2D that moves continuously in swipe direction at 180 px/s.

**Files:**
- Create: `scenes/player/player.tscn` + `scenes/player/player.gd`

- [ ] **Step 1: Create player.tscn**

In Godot editor, create `scenes/player/player.tscn`:
- Root: `CharacterBody2D` (name: `Player`)
  - `CollisionShape2D`: RectangleShape2D, size 16×16
  - `Sprite2D` (name: `Sprite`): placeholder colored rectangle (blue, 16×16 px)

Attach `player.gd`.

- [ ] **Step 2: Create player.gd**

Create `scenes/player/player.gd`:
```gdscript
extends CharacterBody2D

const PLAYER_SPEED: float = 180.0
const DEAD_ZONE: float = 10.0
const TAP_TIME: float = 0.15
const TAP_MAX_DIST: float = 10.0

var _touch_start: Vector2 = Vector2.ZERO
var _touch_time: float = 0.0
var _is_touching: bool = false
var _move_dir: Vector2 = Vector2.ZERO
var is_dead: bool = false

signal tapped(world_pos: Vector2)

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
            if _is_touching and _touch_time < TAP_TIME and \
               event.position.distance_to(_touch_start) < TAP_MAX_DIST:
                tapped.emit(get_global_mouse_position())
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
```

- [ ] **Step 3: Create a temporary test scene**

Create a throwaway scene with a `Player` node, a `StaticBody2D` floor, and some walls. Set it as main scene. Press F5. Swipe on screen — confirm player moves. Verify dead zone (short touches don't move). Verify player stops when finger lifts. Delete the test scene after.

- [ ] **Step 4: Commit**
```bash
git add scenes/player/
git commit -m "feat: add player scene with swipe movement"
```

---

### Task 5: Room Scene + HUD

**Goal:** A static dungeon room (no AI yet) with stone floor tiles, walls, hardcoded entry/exit doors, and the persistent HUD.

**Files:**
- Create: `scenes/room/room.tscn` + `scenes/room/room.gd`
- Create: `scenes/ui/hud.tscn` + `scenes/ui/hud.gd`

- [ ] **Step 1: Create hud.tscn**

In Godot editor, create `scenes/ui/hud.tscn`:
- Root: `CanvasLayer`
  - `Control` (full rect)
    - `Label` (name: `FloorLabel`): top-center, text = "FLOOR 1 · ROOM 1", font size 12
    - `HBoxContainer` (name: `BottomHUD`): anchored bottom-left
      - `VBoxContainer`:
        - `Label`: text = "HP", color red
        - `ProgressBar` (name: `HPBar`): min=0, max=100, value=100, width=120
        - `Label` (name: `WeaponLabel`): text = "Iron Sword", font size 10
    - `Button` (name: `AttackButton`): anchored bottom-right, text = "⚔", size 64×64, disabled=true

Attach `hud.gd`.

- [ ] **Step 2: Create hud.gd**

Create `scenes/ui/hud.gd`:
```gdscript
extends CanvasLayer

@onready var floor_label: Label = $Control/FloorLabel
@onready var hp_bar: ProgressBar = $Control/BottomHUD/VBoxContainer/HPBar
@onready var weapon_label: Label = $Control/BottomHUD/VBoxContainer/WeaponLabel
@onready var attack_button: Button = $Control/AttackButton

signal attack_pressed

func _ready() -> void:
    attack_button.pressed.connect(_on_attack_pressed)
    refresh()

func refresh() -> void:
    hp_bar.value = GameState.hp
    floor_label.text = "FLOOR %d · ROOM %d" % [GameState.floor_number, GameState.room_number]
    if GameState.weapon:
        weapon_label.text = GameState.weapon.weapon_name

func set_attack_enabled(enabled: bool) -> void:
    attack_button.disabled = not enabled

func _on_attack_pressed() -> void:
    attack_pressed.emit()
```

- [ ] **Step 3: Create room.tscn**

In Godot editor, create `scenes/room/room.tscn`:
- Root: `Node2D` (name: `Room`)
  - `TileMapLayer` (name: `Floor`): 16×16 pixel tiles, warm stone palette — configure a simple TileSet with at least two alternating stone colors
  - `TileMapLayer` (name: `Walls`): wall border tiles on all 4 edges
  - `Node2D` (name: `Entities`): empty container for spawned objects
  - `StaticBody2D` (name: `WallCollision`): CollisionPolygon2D matching the wall border (keeps player inside)
  - `Area2D` (name: `ExitDoor`): positioned at bottom-center (`grid[7][2]` mapped position); `CollisionShape2D` 16×24 px; `monitoring = true`
  - `Sprite2D` (name: `ExitDoorSprite`): golden door sprite placeholder
  - `Sprite2D` (name: `EntryDoorSprite`): top-center door sprite
  - `HUD` (instance of `hud.tscn`)
  - `Player` (instance of `player.tscn`): positioned at entry door

Attach `room.gd`.

- [ ] **Step 4: Create room.gd (static version)**

Create `scenes/room/room.gd`:
```gdscript
extends Node2D

# Grid constants
const GRID_COLS: int = 6
const GRID_ROWS: int = 8
const ENTRY_ROW: int = 0
const ENTRY_COL: int = 2
const EXIT_ROW: int = 7
const EXIT_COL: int = 2

# Room play area bounds (set these to match your TileMap dimensions)
@export var room_origin: Vector2 = Vector2(32, 48)  # top-left of playable area
@export var cell_size: Vector2 = Vector2(32, 32)

@onready var entities: Node2D = $Entities
@onready var exit_door: Area2D = $ExitDoor
@onready var hud = $HUD
@onready var player = $Player

var exit_locked: bool = true
var active_enemies: Array = []

signal exit_reached

func _ready() -> void:
    exit_door.body_entered.connect(_on_exit_door_body_entered)
    hud.attack_pressed.connect(_on_attack_pressed)
    player.tapped.connect(_on_player_tapped)
    _lock_exit(true)
    hud.refresh()

func grid_to_world(row: int, col: int) -> Vector2:
    return room_origin + Vector2(col * cell_size.x, row * cell_size.y) + cell_size / 2

func _lock_exit(locked: bool) -> void:
    exit_locked = locked
    # Visual feedback: dim/highlight exit door sprite
    $ExitDoorSprite.modulate = Color(0.4, 0.4, 0.4) if locked else Color(1, 1, 1)

func _on_exit_door_body_entered(body: Node) -> void:
    if body.is_in_group("player") and not exit_locked:
        exit_reached.emit()

func _on_attack_pressed() -> void:
    pass  # implemented in Task 8

func _on_player_tapped(_pos: Vector2) -> void:
    pass  # implemented in Task 8

func check_exit_unlock() -> void:
    if active_enemies.is_empty():
        _lock_exit(false)
```

- [ ] **Step 5: Set room.tscn as main scene and verify**

Press F5. Confirm:
- Stone floor tiles visible
- Walls on all 4 edges
- HUD visible: HP bar full, "FLOOR 1 · ROOM 1", "Iron Sword", attack button grayed
- Player spawns at top-center
- Swipe moves player around the room
- Player cannot pass through walls

- [ ] **Step 6: Commit**
```bash
git add scenes/room/ scenes/ui/hud.tscn scenes/ui/hud.gd
git commit -m "feat: add room scene with floor/walls and HUD"
```

---

## Phase 2 — Core Game Loop

### Task 6: Main Scene + Floor/Room Progression

**Goal:** Root scene that loads rooms, tracks floor/room, and wires the exit door to load the next room.

**Files:**
- Create: `scenes/main.tscn` + `scenes/main.gd`
- Modify: `project.godot` — set main scene to `main.tscn`

- [ ] **Step 1: Create main.tscn**

In Godot editor, create `scenes/main.tscn`:
- Root: `Node` (name: `Main`)

Attach `main.gd`. No child nodes — room is loaded dynamically.

- [ ] **Step 2: Create main.gd**

Create `scenes/main.gd`:
```gdscript
extends Node

const ROOM_SCENE: PackedScene = preload("res://scenes/room/room.tscn")
const GAME_OVER_SCENE: String = "res://scenes/ui/game_over.tscn"  # created in Task 12

var current_room: Node = null

func _ready() -> void:
    GameState.reset()
    _load_next_room()

func _load_next_room() -> void:
    if current_room:
        EnemyAI.clear_queue()
        current_room.queue_free()
        current_room = null

    GameState.room_number += 1
    if GameState.room_number > 5:
        GameState.room_number = 1
        GameState.floor_number += 1

    current_room = ROOM_SCENE.instantiate()
    add_child(current_room)
    current_room.exit_reached.connect(_on_exit_reached)

    # Request AI room generation (implemented in Task 9)
    # For now, load an empty room
    current_room.populate_grid([])

func _on_exit_reached() -> void:
    _load_next_room()

func game_over() -> void:
    if current_room:
        EnemyAI.clear_queue()
        current_room.queue_free()
    get_tree().change_scene_to_file(GAME_OVER_SCENE)
```

- [ ] **Step 3: Add populate_grid stub to room.gd**

Add to `room.gd`:
```gdscript
func populate_grid(grid: Array) -> void:
    # grid is Array of 8 Arrays of 6 Strings
    # Called by main.gd after AI generation; for now accepts empty array
    pass  # entity spawning implemented in Task 9
```

- [ ] **Step 4: Add EnemyAI stub autoload**

Create `autoloads/enemy_ai.gd`:
```gdscript
extends Node

func clear_queue() -> void:
    pass  # implemented in Task 10
```

Register as `EnemyAI` in Project Settings → Autoload.

- [ ] **Step 5: Set main.tscn as main scene and verify**

Press F5. Confirm:
- Room loads and displays
- Walking to exit door (and all enemies cleared — none yet, so door unlocks immediately) transitions to a new room
- `GameState.room_number` and `floor_number` increment correctly (add a `print` to `_load_next_room` to verify in Output panel)
- Room 6 → floor increments, room resets to 1

- [ ] **Step 6: Commit**
```bash
git add scenes/main.tscn scenes/main.gd autoloads/enemy_ai.gd
git commit -m "feat: add main scene with room/floor progression"
```

---

### Task 7: Enemy Scene + Stats

**Goal:** Enemy CharacterBody2D with HP bar, selection highlight, and stat lookup by type.

**Files:**
- Create: `scenes/enemy/enemy.tscn` + `scenes/enemy/enemy.gd`
- Create: `scenes/enemy/boss.tscn` + `scenes/enemy/boss.gd`

- [ ] **Step 1: Define enemy stats constant**

Add to `autoloads/game_state.gd`:
```gdscript
const ENEMY_STATS: Dictionary = {
    "goblin":   { "hp": 20,  "attack": 5,  "gold_min": 5,  "gold_max": 10 },
    "skeleton": { "hp": 35,  "attack": 8,  "gold_min": 8,  "gold_max": 15 },
    "orc":      { "hp": 50,  "attack": 12, "gold_min": 12, "gold_max": 20 },
}
```

- [ ] **Step 2: Create enemy.tscn**

In Godot editor, create `scenes/enemy/enemy.tscn`:
- Root: `CharacterBody2D` (name: `Enemy`); add to group `"enemies"`
  - `CollisionShape2D`: RectangleShape2D 14×14
  - `Sprite2D` (name: `Sprite`): placeholder colored rectangle (red tones, varies by type)
  - `Node2D` (name: `HPBarContainer`): positioned above sprite
    - `ColorRect` (name: `HPBarBg`): size 20×3, color dark red
    - `ColorRect` (name: `HPBarFill`): size 20×3, color bright red
  - `Node2D` (name: `SelectRing`): visual ring indicator, hidden by default

Attach `enemy.gd`.

- [ ] **Step 3: Create enemy.gd**

Create `scenes/enemy/enemy.gd`:
```gdscript
extends CharacterBody2D

var enemy_type: String = "goblin"
var hp: int = 0
var max_hp: int = 0
var attack_damage: int = 0
var gold_min: int = 0
var gold_max: int = 0
var behavior: String = "patrol"
var is_selected: bool = false

const PATROL_SPEED: float = 40.0
const ATTACK_SPEED: float = 70.0
const CHARGE_SPEED: float = 140.0
const MELEE_RANGE: float = 40.0

var _attack_timer: float = 0.0
const ATTACK_COOLDOWN: float = 1.5
var _patrol_dir: Vector2 = Vector2.RIGHT
var _patrol_timer: float = 0.0

signal died(enemy: CharacterBody2D, gold_amount: int)

func setup(type: String) -> void:
    enemy_type = type
    var stats: Dictionary = GameState.ENEMY_STATS.get(type, GameState.ENEMY_STATS["goblin"])
    hp = stats["hp"]
    max_hp = stats["hp"]
    attack_damage = stats["attack"]
    gold_min = stats["gold_min"]
    gold_max = stats["gold_max"]
    _update_hp_bar()

func _physics_process(delta: float) -> void:
    _attack_timer += delta
    _patrol_timer += delta
    var player := get_tree().get_first_node_in_group("player")
    if not player:
        return
    match behavior:
        "attack":
            _move_toward(player.global_position, ATTACK_SPEED, delta)
            if global_position.distance_to(player.global_position) <= MELEE_RANGE:
                _try_attack(player)
        "patrol":
            _patrol(delta)
        "flee":
            _move_away_from(player.global_position, PATROL_SPEED, delta)
    move_and_slide()

func _move_toward(target: Vector2, speed: float, _delta: float) -> void:
    velocity = (target - global_position).normalized() * speed

func _move_away_from(target: Vector2, speed: float, _delta: float) -> void:
    velocity = (global_position - target).normalized() * speed

func _patrol(delta: float) -> void:
    if _patrol_timer > 2.0:
        _patrol_timer = 0.0
        _patrol_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
    velocity = _patrol_dir * PATROL_SPEED

func _try_attack(player: Node) -> void:
    if _attack_timer >= ATTACK_COOLDOWN:
        _attack_timer = 0.0
        player.take_damage(attack_damage)

func take_damage(amount: int) -> void:
    hp = max(0, hp - amount)
    _update_hp_bar()
    if hp == 0:
        _die()

func _die() -> void:
    var gold := randi_range(gold_min, gold_max)
    died.emit(self, gold)
    queue_free()

func set_selected(selected: bool) -> void:
    is_selected = selected
    $SelectRing.visible = selected

func _update_hp_bar() -> void:
    var pct: float = float(hp) / float(max_hp)
    $HPBarContainer/HPBarFill.size.x = 20.0 * pct
```

- [ ] **Step 4: Create boss.tscn and boss.gd**

Create `scenes/enemy/boss.tscn`: duplicate `enemy.tscn`, use larger sprite (purple/gold tones).

Create `scenes/enemy/boss.gd`:
```gdscript
extends "res://scenes/enemy/enemy.gd"

var _taunt_bonus_active: bool = false

func setup_boss(floor_num: int) -> void:
    enemy_type = "boss"
    var boss_floor: int = floor_num / 5
    hp = 150 + boss_floor * 30
    max_hp = hp
    attack_damage = 20 + boss_floor * 5
    gold_min = 50
    gold_max = 100
    _update_hp_bar()

# Override: boss uses taunt/charge in addition to attack/patrol/flee
func _physics_process(delta: float) -> void:
    _attack_timer += delta
    var player := get_tree().get_first_node_in_group("player")
    if not player:
        return
    match behavior:
        "attack":
            _move_toward(player.global_position, ATTACK_SPEED, delta)
            if global_position.distance_to(player.global_position) <= MELEE_RANGE:
                _try_boss_attack(player)
        "taunt":
            velocity = Vector2.ZERO
            # Next attack hits harder
            _taunt_bonus_active = true
        "charge":
            _move_toward(player.global_position, CHARGE_SPEED, delta)
            if global_position.distance_to(player.global_position) <= MELEE_RANGE:
                _try_boss_attack(player)
        "patrol":
            _patrol(delta)
        "flee":
            _move_away_from(player.global_position, PATROL_SPEED, delta)
    move_and_slide()

func _try_boss_attack(player: Node) -> void:
    if _attack_timer >= ATTACK_COOLDOWN:
        _attack_timer = 0.0
        var dmg: int = attack_damage * 2 if _taunt_bonus_active else attack_damage
        _taunt_bonus_active = false
        player.take_damage(dmg)
```

- [ ] **Step 5: Add a test enemy to the room and verify**

Temporarily add an Enemy instance to `room.tscn`. Call `enemy.setup("goblin")` in `room.gd._ready()`. Press F5. Confirm:
- Enemy appears with red HP bar
- Enemy patrols randomly
- Player runs into enemy — console shows `take_damage` firing (add a print)

Remove the test enemy from the scene after.

- [ ] **Step 6: Commit**
```bash
git add scenes/enemy/ autoloads/game_state.gd
git commit -m "feat: add enemy and boss scenes with stats and behavior"
```

---

## Phase 3 — AI Integration

### Task 8: Combat System

**Goal:** Player can select an enemy by tapping it, then tap the attack button to deal damage. Enemy attacks player. Deaths handled.

**Files:**
- Modify: `scenes/room/room.gd`
- Modify: `scenes/ui/hud.gd`
- Create: `scenes/ui/game_over.tscn` + `scenes/ui/game_over.gd`

- [ ] **Step 1: Wire enemy selection in room.gd**

Replace `_on_player_tapped` and `_on_attack_pressed` stubs in `room.gd`:
```gdscript
var selected_enemy: CharacterBody2D = null

func _on_player_tapped(world_pos: Vector2) -> void:
    # Deselect previous
    if selected_enemy and is_instance_valid(selected_enemy):
        selected_enemy.set_selected(false)
    selected_enemy = null

    # Find tapped enemy — select at any range, pick nearest to tap point
    var nearest_dist: float = 80.0  # tap hit radius in screen px
    for enemy in active_enemies:
        if not is_instance_valid(enemy):
            continue
        var d: float = enemy.global_position.distance_to(world_pos)
        if d < nearest_dist:
            nearest_dist = d
            selected_enemy = enemy

    if selected_enemy:
        selected_enemy.set_selected(true)

    hud.set_attack_enabled(selected_enemy != null)

func _on_attack_pressed() -> void:
    if selected_enemy and is_instance_valid(selected_enemy):
        selected_enemy.take_damage(GameState.weapon.damage)
        hud.refresh()
        if not is_instance_valid(selected_enemy):
            selected_enemy = null
            hud.set_attack_enabled(false)
            check_exit_unlock()
```

- [ ] **Step 2: Connect enemy died signal when spawning**

In `room.gd`, update enemy spawn logic (will be fully used in Task 9):
```gdscript
func _register_enemy(enemy: CharacterBody2D) -> void:
    active_enemies.append(enemy)
    enemy.died.connect(_on_enemy_died)

func _on_enemy_died(enemy: CharacterBody2D, gold: int) -> void:
    active_enemies.erase(enemy)
    GameState.gold += gold
    if selected_enemy == enemy:
        selected_enemy = null
        hud.set_attack_enabled(false)
    hud.refresh()
    check_exit_unlock()
```

- [ ] **Step 3: Connect player death to main.game_over**

In `room.gd._ready`, connect player's death signal:
```gdscript
# Player emits no signal currently — poll in _process instead
func _process(_delta: float) -> void:
    if GameState.hp <= 0 and not _game_over_triggered:
        _game_over_triggered = true
        get_tree().get_first_node_in_group("main").game_over()

var _game_over_triggered: bool = false
```

Add `Player` to group `"player"` in `player.gd._ready()`:
```gdscript
func _ready() -> void:
    add_to_group("player")
```

Add `Main` to group `"main"` in `main.gd._ready()`:
```gdscript
func _ready() -> void:
    add_to_group("main")
    GameState.reset()
    _load_next_room()
```

- [ ] **Step 4: Create game_over.tscn**

In Godot editor, create `scenes/ui/game_over.tscn`:
- Root: `Control` (full rect, dark semi-transparent background)
  - `VBoxContainer` (centered):
    - `Label`: text = "GAME OVER"
    - `Label` (name: `StatsLabel`): shows floor reached and gold
    - `Button` (name: `RestartButton`): text = "Play Again"

Attach `game_over.gd`:
```gdscript
extends Control

func _ready() -> void:
    $VBoxContainer/StatsLabel.text = "Floor %d reached\nGold collected: %d" % [
        GameState.floor_number, GameState.gold
    ]
    $VBoxContainer/RestartButton.pressed.connect(_on_restart)

func _on_restart() -> void:
    get_tree().change_scene_to_file("res://scenes/main.tscn")
```

- [ ] **Step 5: Temporarily add enemies to room for testing**

In `room.gd._ready()`, spawn 2 test goblins:
```gdscript
var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
for i in 2:
    var e = enemy_scene.instantiate()
    entities.add_child(e)
    e.setup("goblin")
    e.global_position = grid_to_world(2 + i, 1 + i)
    _register_enemy(e)
```

- [ ] **Step 6: Verify combat**

Press F5:
- Two goblins appear, patrol
- Tap goblin → selection ring appears, attack button activates
- Tap attack → goblin HP bar shrinks
- Goblin attacks player — HP bar in HUD decreases
- Kill both goblins → exit door unlocks (turns bright)
- Walk to exit → new room loads
- Let goblins kill player → game over screen → restart → new run

Remove the test spawn code from `room.gd._ready()` after verifying.

- [ ] **Step 7: Commit**
```bash
git add scenes/room/room.gd scenes/ui/ scenes/player/player.gd scenes/main.gd
git commit -m "feat: implement combat — enemy selection, attack, death, game over"
```

---

### Task 9: Room Generator (Gemini AI)

**Goal:** Before each room loads, call Gemini to get a JSON grid, parse it, and spawn entities.

**Files:**
- Create: `autoloads/room_generator.gd`
- Modify: `autoloads/game_state.gd` — add chest loot constants
- Modify: `scenes/room/room.gd` — implement `populate_grid`
- Modify: `scenes/main.gd` — call RoomGenerator before loading room

- [ ] **Step 1: Create room_generator.gd**

Create `autoloads/room_generator.gd`:
```gdscript
extends Node

signal room_ready(grid_data: Dictionary)

const API_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
const TIMEOUT: float = 8.0

var _http: HTTPRequest

# Fallback room used on any error
const FALLBACK_GRID: Dictionary = {
    "grid": [
        ["empty","empty","empty","empty","empty","empty"],
        ["empty","empty","empty","empty","empty","empty"],
        ["empty","empty","empty","empty","empty","empty"],
        ["empty","empty","chest","empty","empty","empty"],
        ["empty","empty","empty","empty","empty","empty"],
        ["empty","empty","empty","empty","empty","empty"],
        ["empty","empty","empty","empty","empty","empty"],
        ["empty","empty","empty","empty","empty","empty"],
    ],
    "description": "A quiet chamber.",
    "room_type": "treasure"
}

func _ready() -> void:
    _http = HTTPRequest.new()
    _http.timeout = TIMEOUT
    add_child(_http)
    _http.request_completed.connect(_on_response)

func request_room(floor_num: int, room_num: int) -> void:
    var is_boss_room: bool = floor_num % 5 == 0 and room_num == 5
    var prompt: String = (
        "Generate room %d of 5 on floor %d. " % [room_num, floor_num] +
        "Grid: 6 columns × 8 rows. grid[row][col] — grid[0] is the top row. " +
        "Valid cell values: empty, enemy:goblin, enemy:skeleton, enemy:orc, chest, merchant, trap, " +
        ("boss (this IS a boss room). " if is_boss_room else "boss (NOT a boss room — do not use boss). ") +
        "Rules: max 3 enemies per room. Boss rooms: boss + 1 optional chest, no other enemies. " +
        "Merchant rooms: 1 merchant, no enemies. grid[0][2] and grid[7][2] must be empty (doors). " +
        "Respond with JSON only, no markdown."
    )

    var body: Dictionary = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "systemInstruction": {"parts": [{"text":
            "You are a dungeon master for a pixel roguelike. Generate varied rooms. " +
            "Increase difficulty with floor number. Return ONLY valid JSON, no commentary, no code fences."
        }]}
    }

    var url: String = API_URL + "?key=" + ConfigLoader.gemini_api_key
    var headers: PackedStringArray = ["Content-Type: application/json"]
    var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
    if err != OK:
        push_warning("RoomGenerator: request failed, using fallback")
        room_ready.emit(_validated(FALLBACK_GRID))

func _on_response(result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        push_warning("RoomGenerator: HTTP error %d, using fallback" % result)
        room_ready.emit(_validated(FALLBACK_GRID))
        return

    var text: String = body.get_string_from_utf8()
    var parsed = JSON.parse_string(text)
    if parsed == null:
        push_warning("RoomGenerator: outer JSON parse failed")
        room_ready.emit(_validated(FALLBACK_GRID))
        return

    # Gemini wraps response in candidates[0].content.parts[0].text
    var inner_text: String = ""
    if parsed.has("candidates"):
        inner_text = parsed["candidates"][0]["content"]["parts"][0]["text"]
    else:
        push_warning("RoomGenerator: unexpected response shape")
        room_ready.emit(_validated(FALLBACK_GRID))
        return

    var grid_data = JSON.parse_string(inner_text.strip_edges())
    if grid_data == null or not grid_data.has("grid"):
        push_warning("RoomGenerator: grid JSON parse failed")
        room_ready.emit(_validated(FALLBACK_GRID))
        return

    room_ready.emit(_validated(grid_data))

func _validated(data: Dictionary) -> Dictionary:
    var grid: Array = data.get("grid", [])
    # Pad/trim to 8 rows
    while grid.size() < 8:
        grid.append(["empty","empty","empty","empty","empty","empty"])
    grid = grid.slice(0, 8)
    # Pad/trim each row to 6 cols; replace unknown tokens
    var valid_tokens: Array = ["empty","enemy:goblin","enemy:skeleton","enemy:orc",
                               "chest","merchant","trap","boss"]
    var floor_num: int = GameState.floor_number
    var room_num: int = GameState.room_number
    for r in 8:
        var row: Array = grid[r]
        while row.size() < 6:
            row.append("empty")
        row = row.slice(0, 6)
        for c in 6:
            if not (row[c] in valid_tokens):
                push_warning("RoomGenerator: unknown token '%s' → empty" % row[c])
                row[c] = "empty"
            # Strip invalid boss placements
            if row[c] == "boss" and not (floor_num % 5 == 0 and room_num == 5):
                push_warning("RoomGenerator: boss token in non-boss room → orc")
                row[c] = "enemy:orc"
        grid[r] = row
    # Force door cells clear
    grid[0][2] = "empty"
    grid[7][2] = "empty"
    data["grid"] = grid
    return data
```

Register as `RoomGenerator` in Project Settings → Autoload.

- [ ] **Step 2: Implement populate_grid in room.gd**

Add scene preloads at top of `room.gd`:
```gdscript
const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/enemy/boss.tscn")
const MERCHANT_SCENE := preload("res://scenes/merchant/merchant.tscn")
const CHEST_SCENE := preload("res://scenes/chest/chest.tscn")
```

Replace `populate_grid` stub:
```gdscript
func populate_grid(grid_data: Dictionary) -> void:
    var grid: Array = grid_data.get("grid", [])
    if grid.is_empty():
        return
    for row in grid.size():
        for col in grid[row].size():
            var token: String = grid[row][col]
            if token == "empty":
                continue
            var world_pos: Vector2 = grid_to_world(row, col)
            _spawn_entity(token, world_pos)
    check_exit_unlock()

func _spawn_entity(token: String, pos: Vector2) -> void:
    match token:
        "enemy:goblin", "enemy:skeleton", "enemy:orc":
            var type: String = token.split(":")[1]
            var e = ENEMY_SCENE.instantiate()
            entities.add_child(e)
            e.setup(type)
            e.global_position = pos
            _register_enemy(e)
        "boss":
            var b = BOSS_SCENE.instantiate()
            entities.add_child(b)
            b.setup_boss(GameState.floor_number)
            b.global_position = pos
            _register_enemy(b)
        "merchant":
            var m = MERCHANT_SCENE.instantiate()
            entities.add_child(m)
            m.global_position = pos
        "chest":
            var c = CHEST_SCENE.instantiate()
            entities.add_child(c)
            c.global_position = pos
        "trap":
            # Trap: visible damage tile. Spawn a simple Area2D with a red Sprite2D.
            # Connect body_entered → player.take_damage(10). One-shot (despawn after trigger).
            var trap := Area2D.new()
            var shape := CollisionShape2D.new()
            shape.shape = RectangleShape2D.new()
            shape.shape.size = Vector2(16, 16)
            trap.add_child(shape)
            var spr := ColorRect.new()  # replace with pixel art sprite in Task 14
            spr.size = Vector2(14, 14)
            spr.color = Color(0.8, 0.1, 0.1)
            trap.add_child(spr)
            entities.add_child(trap)
            trap.global_position = pos
            trap.body_entered.connect(func(body):
                if body.is_in_group("player"):
                    body.take_damage(10)
                    trap.queue_free()
            )
```

- [ ] **Step 3: Stub merchant and chest scenes**

Create minimal placeholder scenes so the code doesn't crash:

`scenes/merchant/merchant.tscn`: Area2D + Sprite2D (orange square placeholder) + CollisionShape2D. Attach empty `merchant.gd` (`extends Area2D`).

`scenes/chest/chest.tscn`: Area2D + Sprite2D (gold square placeholder) + CollisionShape2D. Attach empty `chest.gd` (`extends Area2D`).

- [ ] **Step 4: Update main.gd to call RoomGenerator**

Replace `_load_next_room` in `main.gd`:
```gdscript
func _load_next_room() -> void:
    if current_room:
        EnemyAI.clear_queue()
        current_room.queue_free()
        current_room = null

    GameState.room_number += 1
    if GameState.room_number > 5:
        GameState.room_number = 1
        GameState.floor_number += 1

    # Show loading indicator while waiting for AI
    # (simple: block until room_ready fires — acceptable for now)
    RoomGenerator.room_ready.connect(_on_room_ready, CONNECT_ONE_SHOT)
    RoomGenerator.request_room(GameState.floor_number, GameState.room_number)
    # Show "…" loading label at exit door while waiting for AI response
    # Add a Label node named "LoadingLabel" as child of ExitDoorSprite in room.tscn
    # set_door_loading(true) shows it; _on_room_ready calls set_door_loading(false)

func _on_room_ready(grid_data: Dictionary) -> void:
    # Hide the "…" loading indicator on the old room's exit door if it exists
    if current_room and is_instance_valid(current_room):
        if current_room.has_method("set_door_loading"):
            current_room.set_door_loading(false)
    current_room = preload("res://scenes/room/room.tscn").instantiate()
    add_child(current_room)
    current_room.exit_reached.connect(_on_exit_reached)
    current_room.populate_grid(grid_data)
```

- [ ] **Step 5: Verify AI room generation**

Ensure `user://config.json` exists with a valid Gemini API key. Press F5:
- First room loads with AI-placed entities (goblins/skeletons/chests)
- Open Godot Output panel — no "fallback" warnings
- Walk to exit (clear enemies first) — next room generates with different contents
- Kill network connection, reload — confirm fallback room appears without crash

- [ ] **Step 6: Commit**
```bash
git add autoloads/room_generator.gd scenes/room/room.gd scenes/main.gd \
        scenes/merchant/ scenes/chest/
git commit -m "feat: AI room generation via Gemini — grid parsing and entity spawning"
```

---

### Task 10: Enemy AI Behavior Polling

**Goal:** EnemyAI polls Gemini every ~3s per enemy (sequential queue) and updates behavior state.

**Files:**
- Modify: `autoloads/enemy_ai.gd`

- [ ] **Step 1: Implement enemy_ai.gd**

Replace stub with:
```gdscript
extends Node

const API_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
const POLL_INTERVAL: float = 3.0
const TIMEOUT: float = 4.0

var _active_enemies: Array = []
var _poll_index: int = 0
var _timer: float = 0.0
var _request_in_flight: bool = false
var _http: HTTPRequest
var _current_enemy: CharacterBody2D = null

func _ready() -> void:
    _http = HTTPRequest.new()
    _http.timeout = TIMEOUT
    add_child(_http)
    _http.request_completed.connect(_on_response)

func register_enemies(enemies: Array) -> void:
    _active_enemies = enemies
    _poll_index = 0

func clear_queue() -> void:
    _active_enemies = []
    _poll_index = 0
    _request_in_flight = false
    _current_enemy = null

func _process(delta: float) -> void:
    if _active_enemies.is_empty() or _request_in_flight:
        return
    _timer += delta
    if _timer < POLL_INTERVAL:
        return
    _timer = 0.0
    # Clean up freed enemies
    _active_enemies = _active_enemies.filter(func(e): return is_instance_valid(e))
    if _active_enemies.is_empty():
        return
    _poll_index = _poll_index % _active_enemies.size()
    _poll_enemy(_active_enemies[_poll_index])
    _poll_index += 1

func _poll_enemy(enemy: CharacterBody2D) -> void:
    var player := get_tree().get_first_node_in_group("player")
    if not player:
        return
    _current_enemy = enemy
    var dist: float = enemy.global_position.distance_to(player.global_position) / 32.0  # in tiles

    var is_boss: bool = enemy.enemy_type == "boss"
    var action_options: String = "attack | taunt | charge" if is_boss else "attack | patrol | flee"
    var prompt: String = (
        "Enemy: %s. HP: %d/%d. Player distance: %.1f tiles. " % [
            enemy.enemy_type, enemy.hp, enemy.max_hp, dist] +
        "Player HP: %d. Current behavior: %s. " % [GameState.hp, enemy.behavior] +
        "Return ONLY JSON: { \"action\": \"%s\" }" % action_options
    )

    var body: Dictionary = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}]
    }
    var url: String = API_URL + "?key=" + ConfigLoader.gemini_api_key
    var headers: PackedStringArray = ["Content-Type: application/json"]
    _request_in_flight = true
    var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
    if err != OK:
        _request_in_flight = false

func _on_response(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    _request_in_flight = false
    if not is_instance_valid(_current_enemy):
        return
    var text: String = body.get_string_from_utf8()
    var parsed = JSON.parse_string(text)
    if parsed == null or not parsed.has("candidates"):
        return
    var inner: String = parsed["candidates"][0]["content"]["parts"][0]["text"]
    var action_data = JSON.parse_string(inner.strip_edges())
    if action_data == null or not action_data.has("action"):
        return
    _current_enemy.behavior = action_data["action"]
```

- [ ] **Step 2: Register enemies with EnemyAI from room.gd**

In `room.gd`, after all enemies are spawned in `populate_grid`, call:
```gdscript
func populate_grid(grid_data: Dictionary) -> void:
    # ... existing spawn loop ...
    check_exit_unlock()
    EnemyAI.register_enemies(active_enemies)
```

- [ ] **Step 3: Verify**

Press F5 with network connected. Spawn into a room with enemies. Wait 3–6 seconds — watch enemy behavior change (patrol → attack → flee). Print `_current_enemy.behavior` in `_on_response` to confirm in Output. Disconnect network — confirm enemies keep current behavior without crash.

- [ ] **Step 4: Commit**
```bash
git add autoloads/enemy_ai.gd scenes/room/room.gd
git commit -m "feat: EnemyAI sequential behavior polling via Gemini"
```

---

### Task 11: Chat System

**Goal:** Long-tap an enemy (or open merchant) to send messages to Gemini and see typed responses.

**Files:**
- Create: `autoloads/chat_manager.gd`
- Create: `scenes/ui/chat_overlay.tscn` + `scenes/ui/chat_overlay.gd`
- Modify: `scenes/room/room.gd` — wire long-tap on enemy to chat
- Modify: `scenes/player/player.gd` — emit long-tap signal

- [ ] **Step 1: Create chat_manager.gd**

Create `autoloads/chat_manager.gd`:
```gdscript
extends Node

const API_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
const HISTORY_LIMIT: int = 10  # turns (20 messages)
const TYPING_SPEED: float = 40.0  # chars per second

signal response_ready(text: String)

var _history: Array = []  # Array of {role, parts} dicts
var _npc_name: String = ""
var _npc_type: String = ""
var _http: HTTPRequest

func _ready() -> void:
    _http = HTTPRequest.new()
    _http.timeout = 10.0
    add_child(_http)
    _http.request_completed.connect(_on_response)

func start_conversation(npc_name: String, npc_type: String) -> void:
    _npc_name = npc_name
    _npc_type = npc_type
    _history = []

func clear_history() -> void:
    _history = []

func send_message(player_message: String) -> void:
    _history.append({"role": "user", "parts": [{"text": player_message}]})
    if _history.size() > HISTORY_LIMIT * 2:
        _history = _history.slice(_history.size() - HISTORY_LIMIT * 2)

    var system_text: String = (
        "You are %s, a %s in a dungeon. Stay in character at all times. " % [_npc_name, _npc_type] +
        "You may hint at dangers ahead, offer trades, tell lore, or be hostile. " +
        "Keep every response under 3 sentences. Do not break character."
    )

    var body: Dictionary = {
        "system_instruction": {"parts": [{"text": system_text}]},
        "contents": _history
    }
    var url: String = API_URL + "?key=" + ConfigLoader.gemini_api_key
    var headers: PackedStringArray = ["Content-Type: application/json"]
    _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_response(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var text: String = body.get_string_from_utf8()
    var parsed = JSON.parse_string(text)
    if parsed == null or not parsed.has("candidates"):
        response_ready.emit("...")
        return
    var reply: String = parsed["candidates"][0]["content"]["parts"][0]["text"].strip_edges()
    _history.append({"role": "model", "parts": [{"text": reply}]})
    response_ready.emit(reply)
```

Register as `ChatManager` in Project Settings → Autoload.

- [ ] **Step 2: Add long-tap detection to player.gd**

Add to `player.gd`:
```gdscript
const LONG_TAP_TIME: float = 0.4

signal long_tapped(world_pos: Vector2)

# In _input, in the touch-released branch:
# Replace existing tap check with:
func _handle_touch_released(event: InputEventScreenTouch) -> void:
    if not _is_touching:
        return
    var dist := event.position.distance_to(_touch_start)
    if dist < TAP_MAX_DIST:
        if _touch_time >= LONG_TAP_TIME:
            long_tapped.emit(get_global_mouse_position())
        else:
            tapped.emit(get_global_mouse_position())
    _is_touching = false
    _move_dir = Vector2.ZERO
```

Update `_input` to call `_handle_touch_released` on `not event.pressed`.

- [ ] **Step 3: Create chat_overlay.tscn**

In Godot editor, create `scenes/ui/chat_overlay.tscn`:
- Root: `CanvasLayer`
  - `PanelContainer` (name: `Panel`): anchored bottom, height ~45% of screen
    - `VBoxContainer`:
      - `Label` (name: `NPCNameLabel`): bold, "SKELETON GUARD"
      - `ScrollContainer`:
        - `VBoxContainer` (name: `MessageLog`): messages appended here as Labels
      - `HBoxContainer`:
        - `LineEdit` (name: `MessageInput`): placeholder "say something..."
        - `Button` (name: `SendButton`): text "→"
  - `Button` (name: `CloseButton`): top-right of panel, text "✕"

Attach `chat_overlay.gd`.

- [ ] **Step 4: Create chat_overlay.gd**

Create `scenes/ui/chat_overlay.gd`:
```gdscript
extends CanvasLayer

@onready var npc_label: Label = $Panel/VBoxContainer/NPCNameLabel
@onready var msg_log: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/MessageLog
@onready var msg_input: LineEdit = $Panel/VBoxContainer/HBoxContainer/MessageInput
@onready var send_button: Button = $Panel/VBoxContainer/HBoxContainer/SendButton
@onready var close_button: Button = $CloseButton

var _typing_text: String = ""
var _typing_index: int = 0
var _typing_timer: float = 0.0
var _typing_label: Label = null

signal closed

func _ready() -> void:
    send_button.pressed.connect(_on_send)
    msg_input.text_submitted.connect(func(_t): _on_send())
    close_button.pressed.connect(func(): closed.emit(); hide())
    ChatManager.response_ready.connect(_on_response_ready)

func open_for(npc_name: String, npc_type: String) -> void:
    npc_label.text = npc_name.to_upper()
    for child in msg_log.get_children():
        child.queue_free()
    _typing_text = ""
    msg_input.text = ""
    ChatManager.start_conversation(npc_name, npc_type)
    show()

func _on_send() -> void:
    var msg := msg_input.text.strip_edges()
    if msg.is_empty():
        return
    _add_message(msg, Color.CORNFLOWER_BLUE)
    msg_input.text = ""
    send_button.disabled = true
    ChatManager.send_message(msg)

func _on_response_ready(text: String) -> void:
    send_button.disabled = false
    _start_typing(text)

func _start_typing(text: String) -> void:
    _typing_text = text
    _typing_index = 0
    _typing_timer = 0.0
    _typing_label = Label.new()
    _typing_label.text = ""
    _typing_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    msg_log.add_child(_typing_label)

func _process(delta: float) -> void:
    if _typing_label == null or _typing_index >= _typing_text.length():
        return
    _typing_timer += delta
    # Advance by one char per (1.0 / TYPING_SPEED) seconds
    var chars_per_second: float = ChatManager.TYPING_SPEED
    var chars_to_add: int = int(_typing_timer * chars_per_second)
    if chars_to_add > 0:
        _typing_timer -= chars_to_add / chars_per_second
        _typing_index = min(_typing_index + chars_to_add, _typing_text.length())
        _typing_label.text = _typing_text.substr(0, _typing_index)
    if _typing_index >= _typing_text.length():
        _typing_label = null

func _add_message(text: String, color: Color) -> void:
    var lbl := Label.new()
    lbl.text = text
    lbl.add_theme_color_override("font_color", color)
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    msg_log.add_child(lbl)
```

- [ ] **Step 5: Wire chat into room.gd**

Add chat overlay instance to `room.tscn` (instance `chat_overlay.tscn` as child of Room).

In `room.gd._ready()`:
```gdscript
@onready var chat_overlay = $ChatOverlay
player.long_tapped.connect(_on_player_long_tapped)
chat_overlay.closed.connect(func(): pass)

func _on_player_long_tapped(world_pos: Vector2) -> void:
    for enemy in active_enemies:
        if is_instance_valid(enemy) and enemy.global_position.distance_to(world_pos) < 80.0:
            if enemy.enemy_type == "boss":
                return  # Boss no chat
            var type_label: String = enemy.enemy_type.capitalize()
            chat_overlay.open_for("Dungeon %s" % type_label, enemy.enemy_type)
            return
```

- [ ] **Step 6: Verify**

Press F5. Long-tap a goblin — chat overlay slides up. Type a message — Gemini responds with typed animation. Send a second message — conversation history maintained. Close overlay — returns to gameplay. Confirm boss has no chat option.

- [ ] **Step 7: Commit**
```bash
git add autoloads/chat_manager.gd scenes/ui/chat_overlay.tscn scenes/ui/chat_overlay.gd \
        scenes/player/player.gd scenes/room/room.gd
git commit -m "feat: NPC chat via Gemini with typing animation"
```

---

## Phase 4 — Game Systems

### Task 12: Merchant Shop

**Goal:** Merchant generates stock via Gemini; player can browse and buy; inline chat.

**Files:**
- Modify: `scenes/merchant/merchant.gd`
- Create: `scenes/ui/shop_overlay.tscn` + `scenes/ui/shop_overlay.gd`

- [ ] **Step 1: Implement merchant.gd**

Replace empty `merchant.gd`:
```gdscript
extends Area2D

const API_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
const FALLBACK_ITEMS: Array = [
    {"name": "Steel Sword", "type": "steel_sword", "description": "Sharp reliable blade.", "gold_cost": 30},
    {"name": "Health Potion", "type": "health_potion", "description": "Restores 50 HP.", "gold_cost": 15},
    {"name": "Map Scroll", "type": "map_scroll", "description": "Reveals room ahead.", "gold_cost": 20},
]

var items: Array = []
var _http: HTTPRequest

signal shop_ready(items: Array)

func _ready() -> void:
    add_to_group("merchants")
    _http = HTTPRequest.new()
    _http.timeout = 6.0
    add_child(_http)
    _http.request_completed.connect(_on_response)
    _request_stock()

func _request_stock() -> void:
    var weapon_name: String = GameState.weapon.weapon_name if GameState.weapon else "Iron Sword"
    var prompt: String = (
        "Generate 3 shop items for a merchant on floor %d. " % GameState.floor_number +
        "Item types: weapon (iron_sword, steel_sword, war_axe, magic_staff), health_potion, map_scroll. " +
        "Each item: name, type, description (max 5 words), gold_cost (weapons 20-50g, potion 15g, scroll 20g). " +
        "Do not offer iron_sword (player has: %s). Return ONLY JSON: {\"items\":[...]}" % weapon_name
    )
    var body: Dictionary = {"contents": [{"role": "user", "parts": [{"text": prompt}]}]}
    var url: String = API_URL + "?key=" + ConfigLoader.gemini_api_key
    _http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_response(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var text: String = body.get_string_from_utf8()
    var parsed = JSON.parse_string(text)
    if parsed == null or not parsed.has("candidates"):
        items = FALLBACK_ITEMS
        shop_ready.emit(items)
        return
    var inner: String = parsed["candidates"][0]["content"]["parts"][0]["text"].strip_edges()
    var data = JSON.parse_string(inner)
    if data == null or not data.has("items"):
        items = FALLBACK_ITEMS
    else:
        items = data["items"]
    shop_ready.emit(items)
```

- [ ] **Step 2: Create shop_overlay.tscn**

In Godot editor, create `scenes/ui/shop_overlay.tscn`:
- Root: `CanvasLayer`
  - `PanelContainer` (centered, ~80% width, ~90% height):
    - `VBoxContainer`:
      - `HBoxContainer`:
        - `Label`: text = "MERCHANT"
        - `Label` (name: `GoldLabel`): text = "💰 0g", right-aligned
        - `Button` (name: `CloseBtn`): text = "✕"
      - `VBoxContainer` (name: `ItemList`): items added here at runtime
      - `Label` (name: `MerchantLine`): italic, "Loading wares..."
      - `HBoxContainer`:
        - `LineEdit` (name: `ChatInput`): placeholder "haggle..."
        - `Button` (name: `ChatSend`): text = "→"

Attach `shop_overlay.gd`.

- [ ] **Step 3: Create shop_overlay.gd**

Create `scenes/ui/shop_overlay.gd`:
```gdscript
extends CanvasLayer

@onready var gold_label: Label = $PanelContainer/VBoxContainer/HBoxContainer/GoldLabel
@onready var item_list: VBoxContainer = $PanelContainer/VBoxContainer/ItemList
@onready var merchant_line: Label = $PanelContainer/VBoxContainer/MerchantLine
@onready var chat_input: LineEdit = $PanelContainer/VBoxContainer/HBoxContainer2/ChatInput
@onready var chat_send: Button = $PanelContainer/VBoxContainer/HBoxContainer2/ChatSend

const WEAPON_MAP: Dictionary = {
    "iron_sword": "res://resources/weapons/iron_sword.tres",
    "steel_sword": "res://resources/weapons/steel_sword.tres",
    "war_axe": "res://resources/weapons/war_axe.tres",
    "magic_staff": "res://resources/weapons/magic_staff.tres",
}

signal closed

func _ready() -> void:
    $PanelContainer/VBoxContainer/HBoxContainer/CloseBtn.pressed.connect(
        func(): closed.emit(); hide())
    chat_send.pressed.connect(_on_chat_send)
    chat_input.text_submitted.connect(func(_t): _on_chat_send())
    ChatManager.response_ready.connect(_on_merchant_reply)

func open_with_items(items: Array) -> void:
    gold_label.text = "💰 %dg" % GameState.gold
    for child in item_list.get_children():
        child.queue_free()
    for item in items:
        _add_item_row(item)
    merchant_line.text = '"Welcome, traveler."'
    ChatManager.start_conversation("The Merchant", "merchant")
    show()

func _add_item_row(item: Dictionary) -> void:
    var row := HBoxContainer.new()
    var name_lbl := Label.new()
    name_lbl.text = "%s — %s" % [item["name"], item.get("description","")]
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var buy_btn := Button.new()
    buy_btn.text = "%dg" % item.get("gold_cost", 0)
    buy_btn.pressed.connect(func(): _buy(item, buy_btn))
    row.add_child(name_lbl)
    row.add_child(buy_btn)
    item_list.add_child(row)

func _buy(item: Dictionary, btn: Button) -> void:
    var cost: int = item.get("gold_cost", 0)
    if GameState.gold < cost:
        merchant_line.text = '"You cannot afford that."'
        return
    GameState.gold -= cost
    gold_label.text = "💰 %dg" % GameState.gold
    btn.disabled = true
    match item["type"]:
        "health_potion":
            GameState.hp = min(GameState.hp + 50, GameState.max_hp)
        "map_scroll":
            pass  # implemented in Task 14
        _:
            if WEAPON_MAP.has(item["type"]):
                GameState.weapon = load(WEAPON_MAP[item["type"]])
    merchant_line.text = '"A fine choice."'

func _on_chat_send() -> void:
    var msg := chat_input.text.strip_edges()
    if msg.is_empty():
        return
    chat_input.text = ""
    ChatManager.send_message(msg)

func _on_merchant_reply(text: String) -> void:
    merchant_line.text = '"%s"' % text
```

- [ ] **Step 4: Wire merchant tap in room.gd**

Add shop overlay instance to `room.tscn`. In `room.gd._ready()`:
```gdscript
@onready var shop_overlay = $ShopOverlay

func _on_player_tapped(world_pos: Vector2) -> void:
    # Check for merchant tap first
    for merchant in get_tree().get_nodes_in_group("merchants"):
        if merchant.global_position.distance_to(world_pos) < 40.0:
            if not merchant.items.is_empty():
                # Stock already fetched — open immediately
                shop_overlay.open_with_items(merchant.items)
            else:
                # Still fetching — wait for signal (connect only once)
                if not merchant.shop_ready.is_connected(_on_merchant_shop_ready):
                    merchant.shop_ready.connect(_on_merchant_shop_ready, CONNECT_ONE_SHOT)
            return
    # ... existing enemy selection logic

func _on_merchant_shop_ready(items: Array) -> void:
    shop_overlay.open_with_items(items)
```

- [ ] **Step 5: Verify**

In Godot, temporarily place a Merchant in room.tscn. Press F5. Tap merchant → shop opens with 3 items. Buy an item — gold deducts; confirm weapon changes in HUD. Chat with merchant — typed response appears. Close shop — gameplay resumes.

- [ ] **Step 6: Commit**
```bash
git add scenes/merchant/ scenes/ui/shop_overlay.tscn scenes/ui/shop_overlay.gd \
        scenes/room/room.gd
git commit -m "feat: merchant shop with AI stock generation and inline chat"
```

---

### Task 13: Chest + Loot + Map Scroll

**Goal:** Chest spawns with weighted loot by floor; Map Scroll previews next room.

**Files:**
- Modify: `scenes/chest/chest.gd`
- Modify: `scenes/ui/shop_overlay.gd` — implement map scroll

- [ ] **Step 1: Implement chest.gd**

Replace empty `chest.gd`:
```gdscript
extends Area2D

var _opened: bool = false

func _ready() -> void:
    add_to_group("chests")

func open() -> String:
    if _opened:
        return ""
    _opened = true
    $Sprite2D.modulate = Color(0.4, 0.4, 0.4)  # dim to show opened
    return _roll_loot()

func _roll_loot() -> String:
    var floor_n: int = GameState.floor_number
    # Weighted table per spec
    var weights: Dictionary
    if floor_n <= 4:
        weights = {"gold": 60, "health_potion": 30, "weapon": 10}
    elif floor_n <= 9:
        weights = {"gold": 45, "health_potion": 30, "weapon": 25}
    else:
        weights = {"gold": 25, "health_potion": 20, "weapon": 55}

    var roll: int = randi_range(1, 100)
    var result: String
    if roll <= weights["gold"]:
        result = "gold"
    elif roll <= weights["gold"] + weights["health_potion"]:
        result = "health_potion"
    else:
        result = "weapon"

    return _apply_loot(result)

func _apply_loot(loot_type: String) -> String:
    match loot_type:
        "gold":
            var amount: int = randi_range(
                GameState.floor_number * 5,
                GameState.floor_number * 10
            )
            GameState.gold += amount
            return "+%d gold" % amount
        "health_potion":
            GameState.hp = min(GameState.hp + 50, GameState.max_hp)
            return "+50 HP"
        "weapon":
            return _give_weapon_upgrade()
    return ""

func _give_weapon_upgrade() -> String:
    # Weapon upgrade order: iron(10) → steel(20) → staff(25) → axe(30)
    var progression: Array = ["iron_sword", "steel_sword", "magic_staff", "war_axe"]
    var weapon_paths: Dictionary = {
        "iron_sword": "res://resources/weapons/iron_sword.tres",
        "steel_sword": "res://resources/weapons/steel_sword.tres",
        "magic_staff": "res://resources/weapons/magic_staff.tres",
        "war_axe": "res://resources/weapons/war_axe.tres",
    }
    var current_type: String = ""
    if GameState.weapon:
        # Identify current weapon type by damage
        match GameState.weapon.damage:
            10: current_type = "iron_sword"
            20: current_type = "steel_sword"
            25: current_type = "magic_staff"
            30: current_type = "war_axe"

    # Find next upgrade
    var current_idx: int = progression.find(current_type)
    if current_idx == -1 or current_idx >= progression.size() - 1:
        # Already at max — reroll to gold
        var amount: int = randi_range(
            GameState.floor_number * 5,
            GameState.floor_number * 10
        )
        GameState.gold += amount
        return "+%d gold (max weapon)" % amount

    var next_type: String = progression[current_idx + 1]
    GameState.weapon = load(weapon_paths[next_type])
    return "Found: %s" % GameState.weapon.weapon_name
```

- [ ] **Step 2: Wire chest tap in room.gd**

In `room.gd._on_player_tapped`:
```gdscript
# Check for chest tap
for chest in get_tree().get_nodes_in_group("chests"):
    if chest.global_position.distance_to(world_pos) < 40.0:
        var loot_msg: String = chest.open()
        if not loot_msg.is_empty():
            # Show brief floating label (or print for now)
            print("Loot: ", loot_msg)
            hud.refresh()
        return
```

- [ ] **Step 3: Implement Map Scroll in shop_overlay.gd**

Replace the `"map_scroll"` match case in `_buy`:
```gdscript
"map_scroll":
    # Preview the next room — handle room/floor wrap
    var preview_room: int = GameState.room_number + 1
    var preview_floor: int = GameState.floor_number
    if preview_room > 5:
        preview_room = 1
        preview_floor += 1
    RoomGenerator.room_ready.connect(_on_preview_ready, CONNECT_ONE_SHOT)
    RoomGenerator.request_room(preview_floor, preview_room)

func _on_preview_ready(grid_data: Dictionary) -> void:
    merchant_line.text = '"Ahead: %s — %s"' % [
        grid_data.get("room_type", "???").capitalize(),
        grid_data.get("description", "")
    ]
```

- [ ] **Step 4: Verify**

Press F5. Open chest — loot message appears. Open chest again — grayed out, no loot. At max weapon, confirm reroll to gold. Buy map scroll — merchant line shows next room description.

- [ ] **Step 5: Commit**
```bash
git add scenes/chest/chest.gd scenes/ui/shop_overlay.gd scenes/room/room.gd
git commit -m "feat: chest loot with weighted table and map scroll preview"
```

---

## Phase 5 — Polish & Export

### Task 14: Pixel Art Sprites + Tile Set

**Goal:** Replace placeholder colored rectangles with proper 16×16 pixel art sprites.

**Files:**
- Create: `assets/sprites/` — player, goblin, skeleton, orc, boss, merchant, chest sprites
- Modify: all scene Sprite2D nodes to use real textures

- [ ] **Step 1: Create or source pixel art sprites**

For each entity, create a 16×16 PNG sprite with classic 8-bit dungeon palette (warm stone tones, torchlight orange accents):
- Player: blue adventurer
- Goblin: small green creature
- Skeleton: grey bones
- Orc: large brown warrior
- Boss: large purple/gold armored figure
- Merchant: orange-robed figure
- Chest: brown box with gold trim

Place in `assets/sprites/`. These can be hand-drawn in any pixel art editor (Aseprite, Pixelorama) or use freely licensed dungeon sprite packs.

- [ ] **Step 2: Update all Sprite2D references in scenes**

For each scene, open in Godot editor and set the `Sprite2D.texture` to the corresponding `.png`. Enable `texture_filter = Nearest` on all sprites (prevents blurry scaling on high-res screens).

- [ ] **Step 3: Set up TileMap stone floor and wall tiles**

In `room.tscn`'s `TileMapLayer`:
- Configure TileSet with a 16×16 pixel stone tile spritesheet
- Use two alternating stone tile variants for the checkerboard floor pattern
- Add wall tiles for all four edges (darker stone, with a top-highlight)

- [ ] **Step 4: Add torch light effect**

Add two `PointLight2D` nodes to `room.tscn` at top-left and top-right corners, with warm orange tint, energy ~0.8, texture a soft circle gradient. Animates slightly with a flicker script:
```gdscript
# Attach to each torch PointLight2D
extends PointLight2D
func _process(_delta: float) -> void:
    energy = 0.8 + sin(Time.get_ticks_msec() * 0.003 + randf()) * 0.1
```

- [ ] **Step 5: Verify**

Press F5. Confirm all entities use pixel art sprites. Stone floor visible. Torches flicker. Sprites are crisp (not blurry) on display.

- [ ] **Step 6: Commit**
```bash
git add assets/
git commit -m "feat: pixel art sprites and dungeon tile set"
```

---

### Task 15: iOS Export + Final Verification

**Goal:** Export to iOS Simulator, verify portrait layout and all touch controls work.

**Files:**
- Modify: `project.godot` — window size, orientation, display settings
- Create: `export_presets.cfg` — iOS export configuration

- [ ] **Step 1: Configure portrait display settings**

In Godot editor: Project → Project Settings → Display → Window:
- Size: Width=390, Height=844 (iPhone 14 logical resolution)
- Stretch Mode: `canvas_items`
- Stretch Aspect: `expand`

Project → Project Settings → Display → Orientations:
- Disable all landscape orientations
- Enable Portrait only

- [ ] **Step 2: Set up iOS export preset**

In Godot editor: Project → Export → Add → iOS:
- App Name: "Dungeon Game"
- Bundle Identifier: `com.yourname.dungeongame`
- Minimum iOS Version: 16.0
- Set code signing team if deploying to device

- [ ] **Step 3: Export to iOS Simulator and verify**

Build and run on iPhone 14 Simulator. Verify:
- Portrait layout fills screen correctly
- HUD elements are tappable and correctly positioned
- Swipe movement works (dead zone, smooth direction)
- Enemy tap/select works with finger
- Attack button responds to touch
- Long-tap opens chat
- Chat text input opens iOS keyboard without covering UI
- Shop overlay scrollable with finger
- No gesture conflicts between swipe and tap

- [ ] **Step 4: Final end-to-end run**

Complete a full run from floor 1 to a floor 5 boss:
- Floor 1–4: fight enemies, find merchants, open chests
- Floor 5, room 5: boss appears, fight boss with escalated stats
- Die: game over screen, restart, new run works

- [ ] **Step 5: Final commit**
```bash
git add project.godot export_presets.cfg
git commit -m "feat: configure iOS portrait export and verify full game loop"
```
