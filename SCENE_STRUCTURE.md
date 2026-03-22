# SCENE_STRUCTURE.md — Godot Scene Tree Conventions

Reference this file any time you create or modify a scene. Every scene in the project must follow these patterns.

---

## Root Node Rules

| Scene | Root Type | Reason |
|-------|-----------|--------|
| `Main.tscn` | `Node` | Pure coordinator, no visual |
| `MintingFloor.tscn` | `Control` | Full-screen UI layout |
| `MorningBrief.tscn` | `CanvasLayer` + `Control` | Overlays gameplay |
| `WorkerRoster.tscn` | `PanelContainer` | Embeddable panel |
| `LedgerPanel.tscn` | `PanelContainer` | Embeddable panel |
| `AuditorScreen.tscn` | `CanvasLayer` + `Control` | Full-screen overlay |

Never use `Node2D` as the root of a UI scene. Never use `Control` as the root of a gameplay scene that has positional sprites.

---

## MintingFloor Layout Tree

```
MintingFloor (Control)
  Background (TextureRect)               ← parchment/stone texture
  HBoxContainer
    LeftPanel (VBoxContainer)
      StageContainer (VBoxContainer)
        PipelineStage_Smelting (PanelContainer)  ← instance of stage template
        PipelineStage_Striking (PanelContainer)
        PipelineStage_Assay (PanelContainer)
    RightPanel (VBoxContainer)
      LedgerPanel (PanelContainer)        ← instanced scene
      WorkerRoster (PanelContainer)       ← instanced scene
  DayAdvanceButton (Button)
  MorningBrief (CanvasLayer)             ← hidden until triggered
```

---

## Pipeline Stage Template

Each stage is an instance of the same template scene `PipelineStageSlot.tscn`:

```
PipelineStageSlot (PanelContainer)
  VBoxContainer
    StageNameLabel (Label)               ← e.g. "Smelting"
    WorkerSlot (HBoxContainer)
      WorkerPortrait (TextureRect)       ← 64×64, shows assigned worker or empty slot
      WorkerName (Label)
      AssignButton (Button)              ← "Assign" / "Remove"
    HSeparator
    OutputPreview (HBoxContainer)
      OutputIcon (TextureRect)
      OutputLabel (Label)               ← "~12 coins / shift"
    FatigueBar (ProgressBar)            ← styled as candle, see STYLE_GUIDE
```

---

## Worker Roster Tree

```
WorkerRoster (PanelContainer)
  VBoxContainer
    RosterTitle (Label)                 ← "Workers"
    HSeparator
    WorkerList (VBoxContainer)
      WorkerRow (HBoxContainer)         ← one per worker, instanced
        Portrait (TextureRect)
        InfoColumn (VBoxContainer)
          NameLabel (Label)
          StatsRow (HBoxContainer)
            SkillIcon + SkillLabel
            FatigueIcon + FatigueLabel
            LoyaltyIcon + LoyaltyLabel  ← Should Have, hidden in MVP
        RestDayButton (Button)
```

---

## Autoloads (project.godot)

Only these autoloads are permitted:

```
GameManager   → res://scripts/game_manager.gd
EventManager  → res://scripts/event_manager.gd
Ledger        → res://scripts/ledger.gd
```

No additional autoloads without explicit instruction. Do not use autoloads for UI logic.

---

## Signal Flow

```
Worker resource  →  emits nothing (plain Resource)
PipelineStageSlot  →  signals: worker_assigned(stage_id, worker), worker_removed(stage_id)
GameManager  →  signals: day_started(day_num), day_ended(results), game_over(ending_id)
Ledger  →  signals: quota_updated(current, target), balance_changed(amount)
EventManager  →  signals: event_triggered(event_id), event_resolved(event_id, choice)
```

UI nodes listen to GameManager/Ledger signals. They never call game logic directly.  
Game logic never references UI nodes directly.

---

## Resource Classes

Workers and Events are `Resource` subclasses, not scenes:

```gdscript
# res://scripts/worker.gd
class_name Worker
extends Resource

@export var worker_name: String
@export var role: String
@export var skill: int
@export var fatigue: int
@export var loyalty: int   # Should Have
@export var portrait: Texture2D
@export var is_resting: bool
```

```gdscript
# res://scripts/game_event.gd
class_name GameEvent
extends Resource

@export var event_id: String
@export var day_trigger: int       # -1 = random chance
@export var title: String
@export var narrative: String
@export var choice_a_label: String
@export var choice_b_label: String
@export var choice_a_effect: Dictionary
@export var choice_b_effect: Dictionary
```

Worker instances live in `res://data/workers/radek.tres` etc.  
Event instances live in `res://data/events/sigismund_bribe.tres` etc.

---

## What Not To Do

- Do not nest Control nodes inside Node2D nodes
- Do not use `$"../../SomeNode"` path strings — use signals or direct child references
- Do not create singletons with `var instance = self` patterns — use autoloads
- Do not use `_process()` for things that only need to update on events — connect to signals
- Do not put game logic inside `_ready()` beyond initial setup
