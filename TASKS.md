# TASKS.md - Royal Mint Task Tracker

Codex updates this file as tasks are completed. Do not reorder sections. Add new tasks under the correct section. Never delete completed tasks - move them to Done.

---

## In Progress

_(none)_

---

## Up Next

### Foundation

### Data

### MVP Scenes
- [ ] `Main.tscn` - entry point, loads MintingFloor
- [ ] `PipelineStageSlot.tscn` - reusable stage template
- [ ] `MintingFloor.tscn` - 3 stages + roster + ledger layout
- [ ] `WorkerRoster.tscn` - worker list with assign + rest controls
- [ ] `LedgerPanel.tscn` - quota, balance, day counter display
- [ ] `MorningBrief.tscn` - narrative popup with event choices
- [ ] `AuditorScreen.tscn` - day 14 ending screen

### Core Systems
- [ ] Worker assignment to pipeline stages
- [ ] Daily coin output formula (skill x fatigue multiplier)
- [ ] Coin quality grading (4 tiers)
- [ ] Fatigue increase per shift + rest day reset
- [ ] Daily quota check (pass/fail)
- [ ] Ledger balance update (coin income minus wages)
- [ ] Event trigger system (Sigismund bribe offer)
- [ ] Day advance flow: morning brief -> shift -> evening results -> next day
- [ ] Day 14 audit evaluation (quota + ledger check)

### UI Polish (after systems work)
- [ ] Apply parchment StyleBox to all panels
- [ ] Style FatigueBar as candle-segment motif
- [ ] Apply gold palette to all labels and borders
- [ ] Add coin logo to main screen header
- [ ] Add day counter with Gothic numeral styling

---

## Done

- [x] 2026-03-22 Foundation: Set up Godot project structure matching `SCENE_STRUCTURE.md` folder layout (`commit: pending final foundation commit`)
- [x] 2026-03-22 Foundation: Create `Worker` resource class (`res://scripts/worker.gd`) (`commit: pending final foundation commit`)
- [x] 2026-03-22 Foundation: Create `GameEvent` resource class (`res://scripts/game_event.gd`) (`commit: pending final foundation commit`)
- [x] 2026-03-22 Foundation: Create `GameManager` autoload with day state machine (`commit: pending final foundation commit`)
- [x] 2026-03-22 Foundation: Create `Ledger` autoload with quota + balance tracking (`commit: pending final foundation commit`)
- [x] 2026-03-22 Foundation: Create `EventManager` autoload (`commit: pending final foundation commit`)
- [x] 2026-03-22 Data: Author worker `.tres` files: Radek, Bozena, Jiri (`commit: pending final foundation commit`)
- [x] 2026-03-22 Data: Author event `.tres` file: Sigismund bribe (Day 3, 7, 11) (`commit: pending final foundation commit`)

---

## Blocked

_(Codex: note anything that can't proceed and why)_

---

## Questions for Developer

- [ ] # QUESTION: The GDD does not define the starting ledger balance or daily wage values, so `Ledger` currently defaults the balance to `0` until those economy numbers are specified.

---

## Conventions for Updating This File

- When starting a task: move it to In Progress, add today's date
- When finishing a task: move it to Done, add commit hash
- When discovering a subtask: add it under the relevant parent with indentation
- When something is blocked: move it to Blocked with a one-line reason
- Do not add tasks to this file that are outside `SCOPE.md`
