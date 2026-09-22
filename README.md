# Word Bomb Auto-Typer

A Roblox LocalScript suite that automatically types words in the **Word Bomb** game, with configurable word-length modes, typing speeds, smart prompt detection, and a polished in-game UI.

---

## Files

| File | Purpose |
|------|---------|
| `word-bomb-typer.lua` | **Entry point** — run this one |
| `config.lua` | Settings management & persistence |
| `word-database.lua` | Word list loading, indexing & filtering |
| `typer-engine.lua` | Keystroke simulation & round detection |
| `ui.lua` | In-game settings panel |
| `wordlist-286594-words.txt` | 286,594-word dictionary |

---

## Installation

### Using an Executor (e.g. Synapse X, KRNL, Script-Ware)

1. Place **all six files** in the same folder that your executor reads scripts from (usually the executor's `workspace/` or `scripts/` directory).
2. Make sure `wordlist-286594-words.txt` is in the **same directory** as the Lua files.
3. Execute `word-bomb-typer.lua` while in the Word Bomb game.

> **Note:** If your executor does not support `readfile()`, the script will automatically attempt to download the word list from GitHub via HTTP (requires *HttpService* to be enabled in game settings — only works if the game allows it).

### Using Roblox Studio (testing only)

1. Create a `LocalScript` under `StarterPlayerScripts`.
2. Add each `.lua` file as a child `ModuleScript` with the matching name (without `.lua`).
3. The main script will `require()` them automatically.

---

## Controls

| Key | Action |
|-----|--------|
| **F6** | Toggle UI visibility |
| **F8** | Emergency stop — halts typing immediately |

---

## Settings

### Word Mode
Controls the target word length range typed per round.

| Mode | Length |
|------|--------|
| SUPER LONG | 20+ characters |
| LONG | 15–19 characters |
| MEDIUM | 10–14 characters *(default)* |
| SHORT | 5–9 characters |
| TINY | 1–4 characters |
| CUSTOM | Your own min/max |

### Typing Speed
| Speed | Delay |
|-------|-------|
| INSTANT | No delay (immediate) |
| FAST | 50ms per key |
| NORMAL | 100ms per key *(default)* |
| SLOW | 200ms per key |
| HUMAN LIKE | Random 80–250ms with occasional hesitation pauses |

### Other Options

| Option | Default | Description |
|--------|---------|-------------|
| Auto-submit | ✓ On | Press Enter automatically after typing |
| Smart pattern match | ✓ On | Filter words to match the round's letter prompt (e.g. "TH") |
| Fallback to shorter | ✓ On | If no word found in current mode, tries shorter categories |

---

## How It Works

```
┌─────────────────────────────────────────┐
│  Script loads → Config.Load()           │
│  → WordDB loads 286k words into buckets │
│  → UI appears (top-right, draggable)    │
│                                         │
│  User clicks ▶ Start                    │
│       ↓                                 │
│  Loop: every 0.3s scan PlayerGui for    │
│        Word Bomb's input TextBox        │
│       ↓ (when found)                   │
│  Wait startDelay (0.4s default)         │
│  Read current prompt from game UI       │
│  Query WordDB: FindLongest(min, max,    │
│      prompt)                            │
│  TyperEngine.TypeWord(word)             │
│    → VirtualInputManager keystroke loop │
│    → Auto-press Enter if enabled        │
│  Loop until round ends or stopped       │
└─────────────────────────────────────────┘
```

### Performance

- Words are pre-indexed into length buckets at load time — no repeated full-list scans.
- Pattern matching uses random weighted sampling (biased toward longer words) with up to 200 tries, falling back to a full bucket scan only for `FindLongest`.
- The round-detection loop runs at ~3Hz to avoid frame-rate impact.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Could not load module" | All `.lua` files must be in the same directory as the main script |
| Word list won't load | Enable *Allow HTTP Requests* in game settings, or place `wordlist-286594-words.txt` in the executor's script folder |
| Typing doesn't appear | Word Bomb may have updated their UI — the script scans for TextBoxes with "type here" / "word" in their name/placeholder. Report the new placeholder text to update `INPUT_PLACEHOLDERS` in `typer-engine.lua` |
| No words found for prompt | The prompt letters may be very rare. The script falls back to shorter word modes automatically |
| UI overlaps game elements | Drag the title bar to reposition. The position is saved between sessions |

---

## Configuration File Locations

Settings are saved to a hidden `WBTyperConfig` folder inside `PlayerGui` and persist for the session. They reload automatically next time the script runs in the same game session.

---

## Disclaimer

This script is provided for **educational purposes**. Using auto-typers in online games may violate the game's Terms of Service. Use responsibly.
