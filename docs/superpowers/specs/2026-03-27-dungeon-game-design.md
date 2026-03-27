# Dungeon Game — Design Spec
**Date:** 2026-03-27
**Engine:** Godot 4.6 (iOS export, portrait)
**Status:** Approved

---

## Overview

A top-down pixel art dungeon roguelike for iPhone. The player explores procedurally-populated rooms, fights enemies, trades with merchants, and descends through floors. What makes it unique: a Gemini AI backend drives all dynamic content — room layouts are generated before entry, enemy behavior changes moment-to-moment, and every NPC can hold a real conversation.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Game engine | Godot 4.6 |
| Platform | iOS 16+, portrait orientation |
| Minimum device | iPhone SE 2nd gen or newer |
| AI backend | Google Gemini API (REST/HTTP from GDScript) |
| Future LLM swap | Replace Gemini endpoint + key config — same GDScript interface |
| Visual style | Classic 8-bit pixel art — warm stone tiles, torchlight, earthy palette |

---

## Dungeon Structure

- Rooms per floor: 5 (fixed)
- Boss room at room 5 of every 5th floor (floors 5, 10, 15…)
- Permadeath — death resets the run; session-only, no persistence between app launches
- Dungeon flows **top-to-bottom**: entry door at top, exit door at bottom
- Progression: Floor 1–5 → floor 5 boss → Floor 6–10 → floor 10 boss, etc.

---

## Architecture

### Autoloads (Singletons)

| File | Role |
|---|---|
| `config_loader.gd` | Loads `user://config.json` on startup; exposes `gemini_api_key`. If missing or empty, redirects to `api_key_setup.tscn`. |
| `game_state.gd` | Player HP, max HP, gold, current weapon, floor number, room number. `reset()` on new run. |
| `room_generator.gd` | Sends room generation prompt to Gemini before room entry. Parses JSON grid. Emits `room_ready(grid_data)` signal. Falls back to a hardcoded safe room on error. |
| `enemy_ai.gd` | Sequential behavior polling queue — one Gemini call at a time across all enemies. Updates enemy `behavior` state on response. Exposes `clear_queue()` called by `main.gd` on every room transition to flush stale references. |
| `chat_manager.gd` | Maintains per-NPC conversation history (last 10 turns). Sends full Gemini request; on response, plays text character-by-character as a typing animation. Emits `response_complete()`. History cleared on room exit. |

### Scene Hierarchy

```
api_key_setup.tscn     — first-launch screen; text input for Gemini API key; validates non-empty; saves to user://config.json
main.tscn              — root; owns floor/room progression, scene transitions
  room.tscn            — walls, floor tiles, entity container; populated at runtime from grid
  player.tscn          — CharacterBody2D; swipe input, HP, weapon
  enemy.tscn           — CharacterBody2D; HP bar, selectable, behavior state machine
  boss.tscn            — separate scene; root script extends enemy.gd; boss-specific stats and prompt
  merchant.tscn        — Area2D; triggers shop overlay on tap within 2 tiles
  chest.tscn           — Area2D; triggers loot popup on tap within 2 tiles; no chat
  hud.tscn             — HP bar, weapon label, attack button (bottom-right), floor/room label (top)
  chat_overlay.tscn    — shared overlay for enemy and merchant chat; text input + scrollable message history
  shop_overlay.tscn    — modal; item list with buy buttons + inline merchant chat (reuses chat_overlay internally)
```

---

## API Key Management

The Gemini API key is **never stored in source code or committed to git**.

- On startup, `config_loader.gd` reads `user://config.json` (Godot's sandboxed per-app data directory on iOS)
- If the file is absent, unreadable, or `gemini_api_key` is an empty string: redirect to `api_key_setup.tscn`
- `api_key_setup.tscn` shows a text input, a confirm button, and a brief note that the key is stored locally
- Validation: key must be non-empty; no format validation beyond that
- On confirm: write `{ "gemini_api_key": "<key>" }` to `user://config.json`, then proceed to `main.tscn`
- This same flow is the re-entry path if the user clears app storage from iOS Settings
- `user://config.json` is added to `.gitignore`

```gdscript
# config_loader.gd (autoload)
var gemini_api_key: String = ""

func _ready() -> void:
    var f := FileAccess.open("user://config.json", FileAccess.READ)
    if f == null or not f.is_open():
        get_tree().call_deferred("change_scene_to_file", "res://scenes/api_key_setup.tscn")
        return
    var data = JSON.parse_string(f.get_as_text())
    gemini_api_key = data.get("gemini_api_key", "")
    if gemini_api_key.is_empty():
        get_tree().call_deferred("change_scene_to_file", "res://scenes/api_key_setup.tscn")
```

---

## Room System

### Logical Grid
- Size: **6 columns × 8 rows** (invisible to player)
- Array nesting: `grid[row][col]` — `grid[0]` is the top row, `grid[0][0]` is top-left
- Maps to the room's playable area proportionally
- Used by AI to place entities; player moves with full free motion

### Door Placement
- Doors are **hardcoded**, not AI-placed
- **Entry door:** 1 cell wide, at `grid[0][2]` (top row, column 2) — player enters here from above
- **Exit door:** 1 cell wide, at `grid[7][2]` (bottom row, column 2) — player exits downward
- `room_generator.gd` always forces `grid[0][2] = "empty"` and `grid[7][2] = "empty"` after parsing, regardless of AI output
- The AI prompt reserves only column 2 in rows 0 and 7 (single-cell door)
- Exit door is **locked** until all enemies in the room are defeated

### Room Entry Flow
1. Player touches the exit door (bottom-center)
2. `RoomGenerator` sends a prompt to Gemini — player sees a `"…"` loading indicator at the door
3. On success: parse JSON, force door cells to `"empty"`, emit `room_ready(grid_data)`, load new room scene
4. On error/timeout: use fallback room (see Error Handling below)
5. `room.gd` iterates `grid[row][col]`, instantiates scenes at mapped world positions
6. Player spawns at the entry door (`grid[0][2]`) of the new room, facing downward

### Grid Cell Values
```
"empty"           — nothing spawned
"enemy:goblin"    — spawns goblin enemy
"enemy:skeleton"  — spawns skeleton enemy
"enemy:orc"       — spawns orc enemy
"chest"           — spawns treasure chest
"merchant"        — spawns merchant NPC
"trap"            — spawns a visible damage tile (deals 10 HP on step)
"boss"            — spawns boss (floor multiples of 5, room 5 only)
```

Unknown cell tokens are treated as `"empty"` and logged with `push_warning()`.

`room_generator.gd` also validates boss placement after parsing: if a `"boss"` token appears in any room where `floor_number % 5 != 0 or room_number != 5`, it is replaced with `"enemy:orc"`. This guards against AI non-compliance with the constraint.

---

## AI Integration

### 1. Room Generation

**Called:** Once, before room entry | **Model:** `gemini-2.0-flash`

```
System: "You are a dungeon master for a pixel roguelike on mobile.
         Generate varied, interesting rooms. Increase difficulty with floor number.
         Return ONLY valid JSON — no commentary, no markdown, no code fences."

User: "Generate room {room_number} of 5 on floor {floor_number}.
       Grid: 6 columns × 8 rows. grid[row][col] — grid[0] is the top row.
       Valid cell values: empty, enemy:goblin, enemy:skeleton, enemy:orc,
       chest, merchant, trap, boss (only when floor is a multiple of 5 AND room_number is 5).
       Rules: max 3 enemies per room. Boss rooms: boss + 1 optional chest only, no other enemies.
       Merchant rooms: 1 merchant, no enemies. grid[0][2] and grid[7][2] must be empty (doors).
       Respond with JSON only."
```

**Response contract:**
```json
{
  "grid": [
    ["empty", "empty", "empty", "empty", "empty", "empty"],
    ["empty", "enemy:goblin", "empty", "empty", "chest", "empty"],
    ...
  ],
  "description": "A damp stone chamber reeking of decay.",
  "room_type": "combat | merchant | treasure | boss"
}
```

`room_type` is used for display and atmospheric flavour only. The grid is authoritative — if `room_type` says `"merchant"` but no merchant is in the grid, no merchant appears.

**Error handling:** Timeout (>8s) or non-200 → fallback: all-`"empty"` grid, `description: "A quiet chamber."`, `room_type: "treasure"`, chest at `grid[3][2]`. No retries.

---

### 2. Enemy Behavior Polling

**Called:** Sequential round-robin queue — one Gemini call in-flight at a time | **Model:** `gemini-2.0-flash`

- `EnemyAI` polls the next enemy in the active-enemy list every 3 seconds
- If the previous request is still in-flight when the timer fires, the timer resets and waits
- On error or timeout (>4s): enemy keeps current `behavior`; no crash

```
User: "Enemy: {enemy_type}. HP: {hp}/{max_hp}. Player distance: {distance} tiles.
       Player HP: {player_hp}. Player armed: {has_weapon}.
       Current behavior: {current_behavior}.
       Return ONLY JSON: { \"action\": \"attack\" | \"patrol\" | \"flee\" }"
```

**Response contract:** `{ "action": "attack" | "patrol" | "flee" }`

---

### 3. NPC Chat

**Called:** On player message send | **Model:** `gemini-2.0-flash`

**Which entities support chat:**
- ✅ Enemies (goblin, skeleton, orc) — chat via `chat_overlay.tscn`; tap enemy within 2 tiles to open
- ✅ Merchants — chat inline within `shop_overlay.tscn`; tap merchant within 2 tiles to open shop
- ❌ Boss — no chat; fight only
- ❌ Chests — no chat; tap to loot

```
System: "You are {npc_name}, a {npc_type} in a dungeon. Stay in character at all times.
         You may hint at dangers ahead, offer trades, tell lore, or be hostile.
         Keep every response under 3 sentences. Do not break character."

[last 10 turns of conversation history — array of {role, content} objects]

User: "{player_message}"
```

**Response delivery:** `chat_manager.gd` sends the request via `HTTPRequest` (full response, not streaming SSE — GDScript's `HTTPRequest` delivers the full body on completion; true SSE would require the lower-level `HTTPClient`). On `request_completed`, the full response text is displayed character-by-character at 40 chars/sec as a typing animation for a streaming-like feel.

**Note on history format:** The system prompt is passed as the `system` field in the Gemini request body, not as an entry in the `contents` history array. The history array contains only `user`/`model` role pairs. Do not include the system prompt in the history array — Gemini's role-alternation contract requires the history to start with a `user` turn. This avoids the complexity of SSE parsing in GDScript while giving a similar visual feel.

History: capped at 10 turns (20 messages); oldest dropped when exceeded. Cleared on room exit. On error: show `"…"` in the chat, no crash.

---

### 4. Merchant Shop Stock

**Called:** Once when merchant room spawns | **Model:** `gemini-2.0-flash`

```
System: "You are generating shop inventory for a pixel dungeon roguelike. Return ONLY valid JSON."

User: "Generate 3 shop items for a merchant on floor {floor_number}.
       Available item types: weapon (iron_sword, steel_sword, war_axe, magic_staff), health_potion, map_scroll.
       Each item has a name, type, description (max 5 words), and gold_cost.
       Weapons should cost 20–50g, potions 15g, map scrolls 20g.
       Do not offer iron_sword if player already has a better weapon (current weapon: {weapon_name}).
       Return ONLY JSON."
```

**Response contract:**
```json
{
  "items": [
    { "name": "Steel Sword", "type": "steel_sword", "description": "Sharp and reliable blade.", "gold_cost": 30 },
    { "name": "Health Potion", "type": "health_potion", "description": "Restores 50 HP.", "gold_cost": 15 },
    { "name": "Map Scroll", "type": "map_scroll", "description": "Reveals room ahead.", "gold_cost": 20 }
  ]
}
```

**Error handling:** Timeout or parse failure → hardcoded fallback stock: Steel Sword 30g, Health Potion 15g, Map Scroll 20g.

---

## Controls

| Input | Action |
|---|---|
| Swipe (hold + drag) | Move player continuously in swipe direction while held; stop on release |
| Short tap on enemy (any range) | Select/target that enemy (highlight ring); deselects previous |
| Long tap on enemy within 2 tiles | Open chat overlay |
| Short tap on empty space | Deselect current enemy |
| Attack button (bottom-right) | Attack selected enemy; grayed out with no selection |
| Tap merchant within 2 tiles | Open shop overlay |
| Tap chest within 2 tiles | Open loot popup |
| Chat input field + send | Send message to NPC |

**Swipe specifics:**
- Dead zone: movement begins only when finger moves **> 10px** (strict greater-than) from touch start
- Movement speed: `PLAYER_SPEED = 180` px/s (constant)
- Direction: normalized vector from swipe start to current finger position
- Tap vs. swipe: gesture under 150ms with movement **< 10px** (strict less-than) = tap; otherwise = swipe
- A touch at exactly 10px is treated as a swipe (movement side wins over tap)
- `InputEventScreenTouch` handles tap; `InputEventScreenDrag` handles movement — no conflict

---

## Combat

- Player taps enemy to select (highlight ring); taps empty space to deselect
- Attack button active only when enemy selected; grayed otherwise
- Tap attack → deal `weapon.damage` to target
- Enemy HP bar shown above sprite at all times
- `EnemyAI` updates `behavior` every ~3s; enemies act on `behavior` each physics frame:
  - `"attack"`: move toward player, deal `attack_damage` every 1.5s when within 40px ("adjacent")
  - `"patrol"`: random wander, no damage
  - `"flee"`: move away from player
- Enemy death: despawn + drop gold in `[gold_min, gold_max]`
- Player HP → 0: freeze input, show game-over overlay, `GameState.reset()`, return to `main.tscn`

---

## Enemy Stats

| Type | HP | Attack Damage | Gold Drop |
|---|---|---|---|
| Goblin | 20 | 5 | 5–10 |
| Skeleton | 35 | 8 | 8–15 |
| Orc | 50 | 12 | 12–20 |
| Boss | 150 + (floor÷5 × 30) | 20 + (floor÷5 × 5) | 50–100 |

Boss scaling example: floor 5 boss = 150 HP / 20 atk; floor 10 boss = 180 HP / 25 atk.

**Boss AI prompt (used instead of standard enemy prompt):**
```
User: "You are a dungeon boss: {boss_name}. HP: {hp}/{max_hp}. Player HP: {player_hp}.
       Floor: {floor_number}. You are powerful and aggressive.
       Choose an action: attack (move toward and strike), taunt (stay, speak a threat), or charge (fast attack this turn).
       Return ONLY JSON: { \"action\": \"attack\" | \"taunt\" | \"charge\" }"
```

**Boss behavior state definitions:**
- `"attack"`: move toward player at normal speed; deal `attack_damage` when within 40px
- `"taunt"`: no movement, no damage; next attack action deals `attack_damage × 2` (bonus resets after one attack)
- `"charge"`: move toward player at `2× speed`; deal `attack_damage` immediately on reaching within 40px

---

## Items & Progression

### WeaponResource (Godot Resource subclass at `res://resources/weapons/`)

```gdscript
class_name WeaponResource extends Resource
@export var weapon_name: String
@export var damage: int
@export var icon: Texture2D
```

| Weapon | Damage |
|---|---|
| Iron Sword (default) | 10 |
| Steel Sword | 20 |
| War Axe | 30 |
| Magic Staff | 25 |

### Consumables

| Item | Effect |
|---|---|
| Health Potion | +50 HP (capped at max_hp) |
| Map Scroll | Fires an immediate room generation call for the next room; shows only `description` and `room_type` as a popup. Does not cache the grid — full generation runs again on actual room entry. This means two Gemini calls fire per scroll use; this double-generation is intentional and accepted in exchange for implementation simplicity. |

### Chest Loot Table (weighted by floor)

| Floor Range | Gold (%) | Health Potion (%) | Weapon Upgrade (%) |
|---|---|---|---|
| 1–4 | 60 | 30 | 10 |
| 5–9 | 45 | 30 | 25 |
| 10+ | 25 | 20 | 55 |

Gold amount: `floor_number × 5` to `floor_number × 10`.

If the weapon upgrade slot is rolled but the player already has the highest-damage weapon (War Axe, 30 dmg), reroll to gold instead.

---

## Data Model

### GameState (autoload)
```gdscript
var hp: int = 100
const max_hp: int = 100   # fixed — no HP upgrades in initial scope
var gold: int = 0
var weapon: WeaponResource       # initialized to iron_sword.tres on reset()
var floor_number: int = 1
var room_number: int = 0

func reset() -> void             # restores all defaults; called on death and new run
```

### Enemy State (per instance in `enemy.gd`)
```gdscript
var enemy_type: String           # "goblin" | "skeleton" | "orc" | "boss"
var hp: int
var max_hp: int          # set at spawn from enemy type table, never modified
var attack_damage: int
var gold_min: int
var gold_max: int
var behavior: String             # "attack" | "patrol" | "flee"
var is_selected: bool
```

### Room Data (transient, passed via `room_ready` signal)
```gdscript
var grid: Array                  # grid[row][col]; 8 rows × 6 cols of String tokens; grid[0] = top row
var description: String
var room_type: String            # "combat" | "merchant" | "treasure" | "boss"; grid is authoritative
```

---

## UI Layout

### Persistent HUD (`hud.tscn`)
- **Top bar:** "FLOOR {n} · ROOM {n}"
- **Bottom-left:** HP bar + current weapon label
- **Bottom-right:** Attack button (⚔) — red when enemy selected, grayed when not

### Three Overlay States
1. **Exploring** — HUD only; swipe to move
2. **Combat/Chat** — `chat_overlay.tscn` slides up ~40% of screen; enemy HP bar visible above target; attack button stays active
3. **Merchant Shop** — `shop_overlay.tscn` modal covers room; item list + buy buttons + inline chat; close button top-right

---

## Verification

Since there is no automated test suite, verification is done by running the game in Godot:

1. **First launch:** API key setup screen appears; entering key proceeds to game; relaunching skips setup
2. **App storage cleared (iOS Settings):** Setup screen appears again on next launch
3. **Room generation:** Gemini call fires before room entry; grid parsed; entities spawn at correct positions; door cells always empty
4. **Network off → room entry:** Fallback room loads within 8s without crash
5. **Room clear:** Exit door unlocks only after all enemies defeated
6. **Combat:** Tap enemy → select; attack button active; damage dealt; enemy HP bar decreases; behavior changes over poll cycle
7. **Enemy chat:** Tap enemy within 2 tiles (long tap) → chat overlay opens; typing animation plays; 10-turn cap enforced; history clears on exit
8. **Boss:** Boss has no chat option; boss stats scale correctly on floor 5 vs floor 10; boss AI uses charge/taunt actions
9. **Merchant:** Shop overlay opens with 3 items; purchase deducts gold; inline chat works
10. **Chest loot:** Loot matches floor-appropriate weighted table
11. **Death:** HP → 0 → game-over screen → restart resets all GameState fields
12. **iOS Simulator:** Portrait layout correct; swipe moves player; tap/swipe disambiguation works; no gesture conflicts
