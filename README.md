```
   ▄▄▄       ▓█████     ▓█████▄  █    ██  ███▄    █   ▄████ ▓█████  ▒█████   ███▄    █ 
  ▒████▄     ▓█   ▀     ▒██▀ ██▌ ██  ▓██▒ ██ ▀█   █  ██▒ ▀█▒▓█   ▀ ▒██▒  ██▒ ██ ▀█   █ 
  ▒██  ▀█▄   ▒███       ░██   █▌▓██  ▒██░▓██  ▀█ ██▒▒██░▄▄▄░▒███   ▒██░  ██▒▓██  ▀█ ██▒
  ░██▄▄▄▄██  ▒▓█  ▄     ░▓█▄   ▌▓▓█  ░██░▓██▒  ▐▌██▒░▓█  ██▓▒▓█  ▄ ▒██   ██░▓██▒  ▐▌██▒
   ▓█   ▓██▒▒░▒████▒    ░▒████▓ ▒▒█████▓ ▒██░   ▓██░░▒▓███▀▒░▒████▒░ ████▓▒░▒██░   ▓██░
   ▒▒   ▓▒█░░░░ ▒░ ░     ▒▒▓  ▒ ░▒▓▒ ▒ ▒ ░ ▒░   ▒ ▒  ░▒   ▒ ░░ ▒░ ░░ ▒░▒░▒░ ░ ▒░   ▒ ▒ 
    ▒   ▒▒ ░ ░ ░  ░     ░ ▒  ▒ ░░▒░ ░ ░ ░ ░░   ░ ▒░  ░   ░  ░ ░  ░  ░ ▒ ▒░ ░ ░░   ░ ▒░
    ░   ▒      ░        ░ ░  ░  ░░░ ░ ░    ░   ░ ░ ░ ░   ░    ░   ░ ░ ░ ▒     ░   ░ ░ 
        ░  ░   ░  ░       ░       ░              ░       ░    ░  ░    ░ ░           ░ 
                        ░                                                              
```
### AE — AI Enemies Dungeon

A pixel-art dungeon roguelike built in **Godot 4.6** for mobile. Every run is a little different — rooms are generated with help from Google's Gemini AI, and you can actually *talk* to the NPCs you meet.

## What It Is

Swipe through dungeons, fight monsters, loot chests, and chat with merchants — all in portrait mode on your phone. The game uses Gemini to generate room layouts and power free-form conversations with NPCs.

## Features

- **AI Room Generation** — Gemini builds the 6×8 dungeon grid each run
- **AI NPC Conversations** — Long-tap any NPC to chat; they stay in character
- **Swipe & Tap Controls** — Built for one-handed play on a 390×844 viewport
- **Pixel Art Enemies** — Goblin, Orc, Skeleton, Boss
- **Weapons & Loot** — Iron Sword, Steel Sword, Magic Staff, War Axe
- **Roguelike Structure** — Enter at `grid[0][2]`, escape at `grid[7][2]`

## Tech Stack

- **Engine:** Godot 4.6 (Mobile renderer)
- **Language:** GDScript
- **AI Backend:** Google Gemini API (`gemini-2.0-flash`)
- **Physics:** Jolt Physics (3D)
- **Platform:** iPhone / Mobile portrait

## Project Structure

```
autoloads/       # Singletons: ConfigLoader, GameState, RoomGenerator, EnemyAI, ChatManager
scenes/          # Game scenes: player, enemies, chests, merchant, UI, main
assets/sprites/  # Pixel art: player, goblin, orc, skeleton, boss, chest, merchant
resources/       # Weapon resources (.tres) and custom resource scripts
docs/            # Design specs
```

## Running the Game

1. Open the project in **Godot 4.6**
2. Press **F5** (or the play button)
3. No build step required

> You'll need a Google Gemini API key configured via the in-game setup scene on first launch.

## Controls

| Action | Input |
|--------|-------|
| Move | Swipe |
| Select Enemy | Tap |
| Attack | Bottom-right attack button |
| Talk to NPC | Long-tap |

## Key Design Constants

- `PLAYER_SPEED = 180` px/s
- Melee range: `40px`
- Tap threshold: `< 10px` movement AND `< 150ms`

---