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
