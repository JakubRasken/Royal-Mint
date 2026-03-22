# STYLE_GUIDE.md — Royal Mint Visual & Code Style

Every node, script, sprite, and UI element must follow this guide. When in doubt, ask: "does this look like it belongs in Kingdom Come: Deliverance?"

---

## Colour Palette

These are the only colours used in UI. Do not invent new ones.

| Name        | Hex       | Use |
|-------------|-----------|-----|
| Gold        | `#8B6914` | Primary accent, borders, headings |
| Dark Gold   | `#5C4409` | Text, deep borders, shadows |
| Light Gold  | `#F5E6B2` | Panel highlights, table headers |
| Cream       | `#FDF6E3` | Panel backgrounds, parchment |
| Charcoal    | `#222222` | Body text |
| Iron Grey   | `#555555` | Secondary text, inactive states |
| Deep Brown  | `#2A1A02` | Drop shadows, extreme darks |
| Danger Red  | `#8B1A1A` | Warnings, critical alerts |
| Safe Green  | `#2A5A2A` | Positive states, quota met |

Never use pure white (`#FFFFFF`) or pure black (`#000000`) in UI — use Cream and Dark Gold instead.

---

## Typography

| Use | Font | Weight | Size |
|-----|------|--------|------|
| Panel headings | `res://assets/fonts/MedievalSharp.ttf` (or closest available) | Bold | 18–22px |
| Body / labels | System serif fallback or DynamicFont with serif | Regular | 13–15px |
| Numbers / stats | Monospace or tabular serif | Regular | 13px |
| Flavour quotes | Italic serif | Italic | 13px |

All UI text is sentence case. Never ALL CAPS or Title Case in gameplay UI.

---

## UI Panels

All panels use `StyleBoxTexture` or `StyleBoxFlat` with:
- Background: `#FDF6E3` (Cream)
- Border colour: `#8B6914` (Gold), 2px
- Corner radius: 0 — no rounded corners (medieval, not modern)
- Inner padding: 8px all sides

**Do not use the default Godot theme.** The default theme (grey panels, blue accents) must not appear anywhere in the game. Every Control node must have an explicit StyleBox override.

Panel structure pattern:
```
PanelContainer (StyleBox: parchment_panel)
  VBoxContainer
    Label (heading style)
    HSeparator (colour: #8B6914)
    [content nodes]
```

---

## Sprites & Icons

### Style rules
- **Line art, not rasterised gradients** — clean ink-on-parchment look
- Outlines: 2px, Dark Gold (`#5C4409`) or near-black
- Fill: flat colours from the palette — no airbrushing, no glow
- All sprites exported as PNG with transparency
- Resolution: 64×64px for icons, 128×128px for worker portraits, 256×256px for stage illustrations
- No anti-aliasing halos against transparency — clean edges

### What sprites look like
- Worker portraits: medieval silhouette bust, ink-sketch style, monochrome or two-tone gold
- Stage icons: simple object (anvil, furnace, scales) in gold line art on transparent
- Coin sprite: use `assets/ui/logo_coin_gold.svg` as the reference — that exact style
- Fatigue bar: segmented, looks like a candle burning down — not a modern health bar
- Loyalty icon: wax seal motif

### What sprites must NOT look like
- Pixel art (this is not a pixel game)
- Cartoon / chibi proportions
- Glowing or neon outlines
- Drop shadows on individual sprites (shadows go on containers, not sprites)
- Modern flat design icons (no Material Design, no SF Symbols style)

---

## Scene & Node Naming

```
# Scenes: PascalCase, descriptive
MintingFloor.tscn
WorkerRoster.tscn
MorningBrief.tscn
AuditorEndscreen.tscn

# Nodes: PascalCase, role-first
WorkerSlot_Smelter
FatigueBar
LoyaltyIcon
QuotaCounter
DayTimer

# Scripts: snake_case matching scene name
minting_floor.gd
worker_roster.gd
morning_brief.gd
```

Never use Godot's default node names (`Node2D`, `Label`, `Button`) as final names. Rename everything meaningfully before committing.

---

## GDScript Style

```gdscript
# Constants at top, SCREAMING_SNAKE_CASE
const MAX_FATIGUE := 100
const COIN_GRADE_THRESHOLD := 65

# Exported vars with type hints
@export var worker_name: String = ""
@export var skill_level: int = 1

# Private vars prefixed with underscore
var _current_fatigue: int = 0

# Signal declarations at top of class
signal worker_collapsed(worker: Worker)
signal quota_updated(current: int, target: int)

# Function order: _ready, _process, public, private
func _ready() -> void:
    pass

func assign_worker(worker: Worker) -> void:
    pass

func _update_fatigue_bar() -> void:
    pass
```

- Always use static typing (`: int`, `: String`, `: Worker`)
- Never use `get_node()` with string paths when `@onready` works
- Prefer signals over direct node references for cross-scene communication
- No `await get_tree().process_frame` hacks — use proper state machines or timers
- Resource files for game data (workers, events) — not hardcoded arrays in scripts

---

## Audio

- No audio implementation until explicitly tasked
- When tasked: all AudioStreamPlayer nodes go under a dedicated `AudioManager` autoload
- Sound files: `.ogg` format, mono for SFX, stereo for music
- No audio from Godot's asset library — source or generate original assets only

---

## What "Done" Means for Any Task

A task is done when:
1. The feature works correctly
2. All nodes are named per this guide
3. No default Godot styling is visible
4. No debug prints remain
5. The scene can be run in isolation without errors
6. It has been committed with a proper message
