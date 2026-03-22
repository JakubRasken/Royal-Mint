# GDD.md — Royal Mint: Game Design Document

**Jam:** Jame Gam #57  
**Theme:** Micromanagement  
**Special Object:** Coin (Prague Groschen)  
**Version:** 1.0 — March 2026

> *"Strike true. Strike pure. The Crown is watching."*

---

## 1. Game Overview

| Field | Value |
|-------|-------|
| Title | Royal Mint |
| Genre | Management / Strategy Simulation |
| Platform | PC — Web (HTML5) primary, Windows secondary |
| Engine | Godot 4 (GDScript) |
| Resolution | 1280×720 |
| Target Length | 15–25 minutes per run |
| Setting | Kuttenberg (Kutná Hora), Bohemia — 1403 AD |

### Elevator Pitch

You are the Mintmaster of Kuttenberg, overseer of the most powerful silver mint in Central Europe. Assign workers, control every stage of the coin-minting pipeline, satisfy the Crown's quotas, and survive the political chaos of Sigismund's approaching coup — all before the auditor arrives on Day 14.

### Jam Theme Fit

- **Micromanagement:** The entire game loop is granular pipeline control — workers, output quality, fatigue, purity ratings. No single button resolves anything for you.
- **Coin (Special Object):** The Prague Groschen is the product, the currency, the objective, and the political weapon. It is not a collectible tacked on — it is the game.

### KCD / KCD2 Connection

Kingdom Come: Deliverance 2 features Kuttenberg (Kutná Hora) as a major city, with the Italian Court (Vlašský dvůr) — the historic Royal Mint — as a central location in the story. The Prague Groschen minted here was the dominant coin of medieval Central Europe. Royal Mint uses this exact historical setting as its world, tone, and narrative spine.

---

## 2. Story & Setting

### Historical Context

The year is 1403. King Wenceslaus IV sits on the Bohemian throne, but his half-brother Sigismund of Hungary is scheming to seize control. Kuttenberg's silver mines and its Royal Mint are the financial backbone of the kingdom — whoever controls the Mint controls the war chest.

The previous Mintmaster, Konrad of Vechta, was ousted when Kuttenberg fell to Sigismund's forces. The player steps into the vacancy during the last weeks before the city's fate is decided, tasked with keeping production running — and the coinage honest — under mounting pressure from all sides.

### The Italian Court (Vlašský dvůr)

The game takes place entirely within the walls of the Italian Court. The facility includes:

- **The Silver Hall** — intake and weighing of ore and bullion
- **The Smelting Floor** — furnaces, alloy control, and pour stations
- **The Blank Workshop** — rolling, cutting, and edge filing
- **The Striking Chamber** — die presses operated by the pressmen
- **The Assay Room** — quality control and official testing
- **The Mintmaster's Office** — ledger management and political decisions

### Narrative Arc

The game is structured around a **14-day countdown** — the Royal Auditor arrives on Day 14. Each day represents one work shift. The story unfolds through:

- **Morning briefs** — a worker or courier delivers news and events
- **Shift events** — mid-session interruptions (sabotage, royal orders, worker crises)
- **Evening reports** — ledger review, morale check, narrative journal entries

> *"On the seventh day, a courier arrived bearing Sigismund's seal. He wanted two thousand groschen — unmarked, minted after dark, with no entry in the ledger. The choice was mine."*

---

## 3. Core Gameplay

### 3.1 The Production Pipeline

The central mechanic is managing a 5-stage coin production pipeline. Each stage must be staffed, monitored, and balanced. Bottlenecks propagate downstream — if blanks are cut too slowly, the Striking Chamber sits idle.

| Stage | Worker Role | Failure Risk |
|-------|-------------|--------------|
| 1. Silver Intake | Weighmaster | Short-weighed bullion → purity deficit downstream |
| 2. Smelting | Smelter | Wrong temperature → alloy impurity, coin cracking |
| 3. Blank Cutting | Cutter | Off-weight blanks → rejected in assay |
| 4. Die Striking | Pressman | Misaligned die → disfigured coins, reputation loss |
| 5. Assay & Dispatch | Assayer | Missed defects → Royal fine; over-rejection → quota fail |

**MVP uses stages 2, 4, and 5 (Smelting, Striking, Assay). Stages 1 and 3 are Should Have.**

### 3.2 Worker Management

Each worker has three stats:

- **Skill (1–5):** Determines base output quality and speed. Increases slowly through experience.
- **Fatigue (0–100):** Rises each shift. High fatigue causes errors. Workers need rest days.
- **Loyalty (0–100):** *(Should Have)* Affected by pay, treatment, and events. Low loyalty opens them to bribery.

Workers are individuals with names and personalities — in keeping with KCD's characterful NPC design.

#### Daily Output Formula

```
base_output = skill_level * 10          # coins per shift
fatigue_penalty = fatigue / 100.0       # 0.0 (fresh) to 1.0 (exhausted)
effective_output = base_output * (1.0 - fatigue_penalty * 0.7)
```

Fatigue increases by 20 per shift. Rest day resets fatigue to 0 but produces 0 coins for that stage.

### 3.3 Coin Quality System

Every coin produced has a Purity Rating (0–100) derived from pipeline decisions. Final grade:

| Grade | Purity Range | Consequence |
|-------|-------------|-------------|
| Royal Grade | 85–100 | Crown approval, reputation bonus |
| Merchant Grade | 65–84 | Accepted — meets quota |
| Common Grade | 40–64 | Technically valid — triggers a warning |
| Debased | Below 40 | Rejected, fine levied, possible arrest |

Only **Merchant Grade and above** count toward the daily quota.

### 3.4 Daily Quota & Resources

Each day the Crown expects a minimum number of Merchant Grade+ groschen.

| Day Range | Daily Quota Target |
|-----------|-------------------|
| Days 1–4 | 20 coins |
| Days 5–9 | 30 coins |
| Days 10–14 | 40 coins |

Resources tracked in the Ledger:

- **Ledger Balance** — running income (coins × value) minus wages and fines
- **Silver Stock** *(Should Have)* — consumed per coin batch
- **Firewood** *(Should Have)* — consumed by smelting furnaces
- **Die Condition** *(Nice to Have)* — degrades silently, reduces quality

### 3.5 The Morality System *(Should Have)*

Two silent axes tracked by GameManager:

- **Crown Loyalty vs. Self-Interest** — take the honest line or pocket a cut?
- **Worker Welfare vs. Output Pressure** — protect workers or push them hard?

No visible meters. Outcomes emerge from accumulated choices in the final audit.

---

## 4. Events & Disruption Systems

### 4.1 Shift Events

Each shift has a chance of triggering one event. MVP ships with one event type; Should Have adds more.

| Event | Description & Choice |
|-------|----------------------|
| **Sigismund's Agent** *(MVP)* | A nobleman arrives demanding off-book coins. Refuse (loyalty risk) or comply (auditor risk). Triggers Days 3, 7, 11. |
| Furnace Failure | The smelting furnace cracks mid-shift. Pay emergency repairs or reduce output today. |
| Silver Theft | A batch is missing. Interrogate all workers (morale hit) or absorb the loss silently. |
| Royal Inspector Visit | Unannounced. Worker stats and ledger are scrutinised. |
| Mine Strike | Silver supply halved for 3 days. |
| Talented Vagrant | A skilled foreign moneyer offers to work for half-wages, no questions asked. |
| Worn Die Discovered | Assayer flags 20% coin failure rate. Stop and re-engrave (costs time) or push through? |
| Worker Illness | Key worker collapses. Re-assign or halt that stage. |

### 4.2 The Auditor Countdown

Day 14 is fixed. The Royal Auditor examines four weighted pillars:

| Pillar | Weight | Measured By |
|--------|--------|-------------|
| Production Quota | 35% | Total Merchant Grade+ coins vs. cumulative target |
| Ledger Integrity | 30% | Unexplained silver deficits, off-book transactions |
| Coin Quality | 20% | Average Purity Rating of last 3 days' output |
| Worker Loyalty | 15% | Average loyalty score — determines worker testimony |

**MVP uses Quota (50%) and Ledger (50%) only. Full 4-pillar evaluation is Should Have.**

---

## 5. Interface & UX

### 5.1 Main View — The Minting Floor

Primary gameplay screen. Layout:

- **Left column:** 3 (or 5) pipeline stage panels stacked vertically
- **Right column:** Ledger panel (top) + Worker Roster panel (bottom)
- **Bottom:** Day Advance button

Each stage panel shows: stage name, assigned worker (portrait + name), estimated output, fatigue bar.

### 5.2 The Ledger Panel

Displays:
- Daily quota progress (coins minted vs. target) — visual fill bar
- Ledger balance (total groschen)
- Days remaining until audit
- *(Should Have)* Resource levels

### 5.3 Worker Roster

Scrollable list of all workers. Each row shows:
- Portrait, name, current assignment
- Skill, Fatigue stats
- Rest Day toggle button

### 5.4 Morning Brief

Full-width popup panel on day start. Contains:
- Narrative text in period-appropriate voice (blunt, unglamorous, like KCD's dialogue)
- Event choice buttons if an event is active
- "Begin Shift" button to proceed

### 5.5 Visual & Audio Direction

**Art style:** Hand-painted or ink-wash aesthetic. Illuminated manuscript references. Muted earth tones, iron greys, candle-warm ambers. See `STYLE_GUIDE.md` for exact palette and rules.

**UI:** Aged parchment textures, Gothic script headings, wax-seal iconography, iron-stamped borders. No rounded corners. No modern UI conventions.

**Audio:** Ambient mint sounds (hammer strikes, furnace roar, grinding), single lute/hurdy-gurdy loop for morning brief. No audio in MVP — see `SCOPE.md`.

---

## 6. Endings

The auditor's final report produces one of five outcomes:

| Ending | Condition |
|--------|-----------|
| **The Royal Commendation** | All four pillars excellent. The Crown names you Master Moneyer. |
| **The Honest Mintmaster** | Quota met, ledger clean, quality acceptable. You keep your post. |
| **The Compromised Survivor** | Quota met but ledger has irregularities. You survive — at a cost. |
| **The Ousted Official** | Quota missed or quality too low. You are dismissed. |
| **The Arrested Traitor** | Debased coins found, workers testify, ledger falsified. You are arrested. |

**MVP ships with a single pass/fail ending. Full 5 endings are Should Have.**

### Instant Loss Conditions

- Ledger balance hits zero (cannot pay wages)
- Three consecutive days of zero coins produced
- All workers incapacitated

---

## 7. Characters

### Starting Workers (MVP: first three)

| Name | Role | Skill | Personality |
|------|------|-------|-------------|
| **Radek** | Smelter | 4 | Stubborn, loyal, hates shortcuts. Impossible to bribe. |
| **Bozena** | Assayer | 3 | Sharp-eyed, suspicious. Will report irregularities unprompted. |
| **Jiri** | Pressman | 2 | Young, fast, underpaid. Loyalty starts low — first bribe target. |
| Milota | Cutter | 3 | Methodical, chronically fatigued. Needs rest days or quality suffers badly. |
| Vanek | Weighmaster | 2 | Charming and light-fingered. May skim silver if Loyalty < 30. |

### External Characters

- **The Royal Auditor** — Never seen until Day 14. His standards are an ever-present threat.
- **Sigismund's Agent** — Appears Days 3, 7, and 11 with escalating demands.
- **The Silver Merchant** — Optional resource contact. Expensive but reliable.
- **The Mintmaster's Clerk** — Tutorial voice. Delivers the morning brief. Dry wit, long-suffering.

---

## 8. Win / Loss Conditions

### Day 14 Evaluation (MVP: 2 pillars)

| Pillar | MVP Weight | Full Weight |
|--------|------------|-------------|
| Production Quota | 50% | 35% |
| Ledger Integrity | 50% | 30% |
| Coin Quality | — | 20% |
| Worker Loyalty | — | 15% |

Score maps to one of five endings (see Section 6).

---

## 9. References & Inspiration

### Game References

- **Kingdom Come: Deliverance 1 & 2** — Setting, tone, historical authenticity, NPC depth
- **Mini Motorways / Mini Metro** — Clean pipeline visualisation, satisfying resource routing
- **Papers Please** — Moral pressure through bureaucratic routine; consequences of small decisions
- **Frostpunk** — Worker management under existential countdown pressure

### Historical References

- **The Italian Court (Vlašský dvůr), Kutná Hora** — Real minting facility, now a museum
- **Prague Groschen** — Silver coin minted at Kutná Hora from 1300; dominant currency of medieval Central Europe
- **Konrad of Vechta** — Historical Mintmaster ousted by Sigismund in January 1403
- **Wenceslaus IV and Sigismund** — Real political conflict that destabilised Bohemia in the early 1400s
