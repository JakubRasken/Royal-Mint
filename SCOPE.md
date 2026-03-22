# SCOPE.md — Royal Mint Jam Scope

This file defines exactly what gets built for Jame Gam #57. Nothing outside this list gets implemented without an explicit instruction that references this file and overrides it.

If a feature is not listed here, **do not build it.**

---

## Engine & Platform

- Godot 4 (GDScript only — no C#)
- Target: PC, windowed, 1280×720 base resolution
- Export: Web (HTML5) as primary jam submission target, Windows as secondary
- No mobile, no controller support, no accessibility features for jam scope

---

## MVP — Must Ship

These are required for a valid jam submission:

### Core Loop
- [ ] Day counter (1–14) with advance button
- [ ] 3 pipeline stages active: **Smelting → Striking → Assay**
- [ ] Each stage has one worker slot (assign / unassign from roster)
- [ ] Daily coin output calculated from worker skill + fatigue
- [ ] Coin quality grade (4 tiers: Royal / Merchant / Common / Debased)
- [ ] Daily quota target with pass/fail indicator
- [ ] One event type fires per day: Sigismund's bribe offer (accept/refuse)
- [ ] Ledger balance (income from coins minus wages)
- [ ] Day 14 auditor evaluation screen with single pass/fail ending

### Workers
- [ ] 3 workers: Radek (Smelter), Bozena (Assayer), Jiri (Pressman)
- [ ] Stats: Skill (1–5), Fatigue (0–100)
- [ ] Fatigue increases each shift; high fatigue reduces output
- [ ] Rest day toggle (removes worker from roster for one day, resets fatigue)

### UI Screens
- [ ] Main minting floor view (3 stage workspaces + worker roster panel)
- [ ] Morning brief panel (daily narrative text + event choice if triggered)
- [ ] Ledger sidebar (quota progress, balance, days remaining)
- [ ] Day 14 audit result screen

---

## Should Have — Build After MVP Is Stable

Do not start these until all MVP items are checked off.

- [ ] All 5 pipeline stages (add Silver Intake + Blank Cutting)
- [ ] All 5 workers (add Milota + Vanek)
- [ ] Loyalty stat on workers
- [ ] Worker bribery mechanic (Jiri loyalty check vs. Sigismund event)
- [ ] 3 additional event types (Furnace Failure, Silver Theft, Royal Inspector)
- [ ] 5-ending audit resolution (see GDD Section 7)
- [ ] Morality tracking (silent Crown Loyalty + Self-Interest axes)
- [ ] Morning brief illustration (static parchment image per day)

---

## Nice to Have — Only If Time Permits

Do not start these until Should Have items are done.

- [ ] Worker hiring / dismissal
- [ ] Die wear resource
- [ ] Firewood resource
- [ ] Silver stock resource
- [ ] Ambient SFX loop (hammer, furnace)
- [ ] Worker idle animations (simple 2-frame)

---

## Explicitly Out of Scope — Never Build These

- Any gameplay outside the Italian Court (no map, no exploration)
- Dialogue trees or branching conversations
- Voiced audio of any kind
- Combat, stealth, or action mechanics
- Inventory system
- Save/load system (jam games run in one session)
- Multiple runs / roguelike meta-progression
- Multiplayer
- Settings menu beyond a mute button
- Credits screen (add a simple text overlay on the end screen instead)
- Procedural event generation — all events are hand-authored
- Godot plugins or addons not already in the project

---

## Scene Inventory

These are the only scenes that should exist at ship:

```
res://
  scenes/
    Main.tscn              ← game entry point, loads GameManager
    MintingFloor.tscn      ← primary gameplay screen
    MorningBrief.tscn      ← daily narrative panel (popup)
    WorkerRoster.tscn      ← worker list panel (embedded in MintingFloor)
    LedgerPanel.tscn       ← resource sidebar (embedded in MintingFloor)
    AuditorScreen.tscn     ← day 14 ending screen
  scripts/
    game_manager.gd        ← autoload, day/state machine
    worker.gd              ← Worker resource class
    pipeline_stage.gd      ← PipelineStage resource class
    event_manager.gd       ← loads and fires daily events
    ledger.gd              ← tracks balance, quota, resources
  assets/
    fonts/
    ui/
    sprites/
    audio/
  data/
    workers/               ← .tres files for each worker
    events/                ← .tres files for each event
```

Any scene or script not on this list needs a justification before being created.

---

## Definition of "Scope Creep"

If Codex finds itself about to implement any of the following unprompted, it is scope creep — stop immediately:

- A feature that "would be cool" but isn't in the GDD
- A refactor of a system that already works correctly
- A new UI screen not in the scene inventory above
- Adding configuration, settings, or debug tools
- Improving visual fidelity of a system before all MVP systems are functional
