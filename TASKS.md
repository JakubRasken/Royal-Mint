# TASKS.md - Royal Mint Task Tracker

Codex updates this file as tasks are completed. Do not reorder sections. Add new tasks under the correct section. Never delete completed tasks - move them to Done.

---

## In Progress

_(Codex: move a task here when you start it)_

---

## Up Next

### Foundation

### Data

### MVP Scenes

### UI Polish (after systems work)

---

## Done

- [x] 2026-03-23 Gameplay: add active coin striking minigame to striking stage (`commit: pending current gameplay commit`)
- [x] 2026-03-23 UI Polish: force root control to true full-rect viewport fill (`commit: f657b72`)
- [x] 2026-03-23 UI Polish: prevent shift report from being obscured by end shift button (`commit: e0e5076`)
- [x] 2026-03-23 UI Polish: add animated day urgency to header (`commit: f08000b`)
- [x] 2026-03-23 UI Polish: add flavour status lines to worker roster (`commit: 09c266d`)
- [x] 2026-03-23 Gameplay: add coin grade feedback after each shift (`commit: 923f16b`)
- [x] 2026-03-23 Gameplay: surface the Sigismund threat earlier (`commit: 7667d1f`)
- [x] 2026-03-23 Gameplay: make the quota bar actually hurt when failing (`commit: df8252f`)
- [x] 2026-03-23 UI Polish: add candlelight vignette to background (`commit: c074142`)
- [x] 2026-03-23 UI Polish: restore header to top of layout flow (`commit: 4fef615`)
- [x] 2026-03-23 UI Polish: correct fatigue bar fill direction (`commit: 79dbb68`)
- [x] 2026-03-23 UI Polish: push roster watermark behind worker rows (`commit: 5a7c193`)
- [x] 2026-03-23 UI Polish: fix viewport scaling and unclipped layout (`commit: 498da42`)
- [x] 2026-03-23 UI Polish: add manuscript header bar (`commit: 7021146`)
- [x] 2026-03-23 UI Polish: reshape fatigue bars as candle segments (`commit: 17d6fd5`)
- [x] 2026-03-23 UI Polish: add stage icon hierarchy (`commit: d7ec51e`)
- [x] 2026-03-23 UI Polish: turn quota status into urgency banner (`commit: 1cc202d`)
- [x] 2026-03-23 UI Polish: elevate the end shift action (`commit: 200e0e2`)
- [x] 2026-03-23 UI Polish: add roster status stripes (`commit: b300576`)
- [x] 2026-03-23 Core Systems: correct zero-output collapse to check literal coin production (`commit: 4ea9476`)
- [x] 2026-03-22 Core Systems: polish gameplay feedback and event consequences (`commit: 1780697`)
- [x] 2026-03-22 MVP Scenes: Ledger balance update (coin income minus wages) (`commit: cbbe73d`)
- [x] 2026-03-22 MVP Scenes: Instant loss conditions: zero balance, three zero-output days, all workers incapacitated (`commit: e449176, 853e5ba, cbbe73d`)
- [x] 2026-03-22 UI Polish (after systems work): Style FatigueBar as candle-segment motif (`commit: e75a22c`)
- [x] 2026-03-22 UI Polish (after systems work): Add coin logo to main screen header (`commit: e75a22c`)
- [x] 2026-03-22 UI Polish (after systems work): Add day counter with Gothic numeral styling (`commit: e75a22c`)
- [x] 2026-03-22 MVP Scenes: `Main.tscn` - entry point, loads MintingFloor (`commit: pending next gameplay commit`)
- [x] 2026-03-22 MVP Scenes: `MintingFloor.tscn` - 3 stages + roster + ledger layout (`commit: pending next gameplay commit`)
- [x] 2026-03-22 MVP Scenes: `WorkerRoster.tscn` - worker list with assign + rest controls (`commit: pending next gameplay commit`)
- [x] 2026-03-22 MVP Scenes: `LedgerPanel.tscn` - quota, balance, day counter display (`commit: pending next gameplay commit`)
- [x] 2026-03-22 MVP Scenes: `MorningBrief.tscn` - narrative popup with event choices (`commit: pending next gameplay commit`)
- [x] 2026-03-22 MVP Scenes: `AuditorScreen.tscn` - day 14 ending screen (`commit: pending next gameplay commit`)
- [x] 2026-03-22 Core Systems: Worker assignment to pipeline stages (`commit: pending next gameplay commit`)
- [x] 2026-03-22 Core Systems: Daily coin output formula (skill x fatigue multiplier) (`commit: pending next gameplay commit`)
- [x] 2026-03-22 Core Systems: Coin quality grading (4 tiers) (`commit: pending next gameplay commit`)
- [x] 2026-03-22 Core Systems: Fatigue increase per shift + rest day reset (`commit: pending next gameplay commit`)
- [x] 2026-03-22 Core Systems: Daily quota check (pass/fail) (`commit: pending next gameplay commit`)
- [x] 2026-03-22 Core Systems: Event trigger system (Sigismund bribe offer) (`commit: pending next gameplay commit`)
- [x] 2026-03-22 Core Systems: Day advance flow: morning brief -> shift -> evening results -> next day (`commit: pending next gameplay commit`)
- [x] 2026-03-22 Core Systems: Day 14 audit evaluation (quota + ledger check) (`commit: pending next gameplay commit`)
- [x] 2026-03-22 UI Polish (after systems work): Apply parchment StyleBox to all panels (`commit: pending next gameplay commit`)
- [x] 2026-03-22 UI Polish (after systems work): Apply gold palette to all labels and borders (`commit: pending next gameplay commit`)
- [x] 2026-03-22 MVP Scenes: `PipelineStageSlot.tscn` - reusable stage template (`commit: pending scene commit`)
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

_(Codex: add `# QUESTION:` items here when design intent is unclear)_

---

## Conventions for Updating This File

- When starting a task: move it to In Progress, add today's date
- When finishing a task: move it to Done, add commit hash
- When discovering a subtask: add it under the relevant parent with indentation
- When something is blocked: move it to Blocked with a one-line reason
- Do not add tasks to this file that are outside `SCOPE.md`
