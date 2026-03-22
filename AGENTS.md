# AGENTS.md — Codex Instructions for Royal Mint

This file governs how Codex operates on this repository. Read it fully before touching any file.

---

## Project Identity

**Game:** Royal Mint  
**Engine:** Godot 4 (GDScript)  
**Repo:** https://github.com/JakubRasken/Royal-Mint.git  
**Genre:** Management simulation — pipeline micromanagement, medieval Bohemia (KCD/KCD2 aesthetic)  
**Full design spec:** `GDD.md` — read it before implementing any feature

---

## Behaviour Rules

### Think before acting
- Before writing any code, state in a comment block what you are implementing and why
- If a task is ambiguous, pick the most conservative interpretation and note your assumption
- Never implement a feature not listed in `SCOPE.md` without explicit instruction
- If you notice scope creep in your own plan, stop and reduce it

### One task at a time
- Complete one logical unit (one scene, one system, one script) before moving to the next
- Do not refactor unrelated files while implementing a feature
- Do not rename files or nodes unless the task explicitly requires it

### Self-check before every commit
Run through this checklist mentally before staging anything:

```
[ ] Does this code match what the task asked for — nothing more?
[ ] Does it follow GDScript style (see STYLE_GUIDE.md)?
[ ] Are there any hardcoded magic numbers that should be constants?
[ ] Are all signals connected — not left dangling?
[ ] Does the scene tree match the conventions in SCENE_STRUCTURE.md?
[ ] Have I introduced any file or node that is not referenced anywhere?
[ ] Does the UI match the visual spec in STYLE_GUIDE.md?
```

If any answer is no, fix it before committing.

---

## Git Workflow

### Commit rules
- One commit per logical unit of work — never batch unrelated changes
- Commit message format: `type(scope): short description`
  - Types: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`
  - Examples: `feat(pipeline): add smelting stage worker assignment`
  - Examples: `fix(ui): correct fatigue bar overflow on small screens`
- Never commit commented-out code
- Never commit debug print statements (`print()` calls intended for testing)
- Never commit `.import` files, `.godot/` cache, or OS-specific files

### Branch discipline
- Work on `main` only unless explicitly told otherwise
- Always pull before starting a session: `git pull origin main`
- Push at the end of every completed task

### What NOT to commit
- Placeholder assets (solid-colour rects standing in for real sprites) — mark as TODO in TASKS.md instead
- Half-finished systems with broken dependencies
- Duplicate scenes or scripts created by accident

---

## What Codex Must NOT Do

- Do not install plugins or addons without being asked
- Do not modify `project.godot` settings unless the task specifically requires it
- Do not restructure the `res://` folder layout without explicit instruction
- Do not write a custom implementation of something Godot already provides natively
- Do not add dependencies to external libraries
- Do not change the game's resolution or window settings
- Do not add post-processing effects, shaders, or particles unless the task names them
- Do not generate placeholder UI with placeholder text like "Label", "Button", "TODO" — use real in-world labels from the GDD
- Do not skip the STYLE_GUIDE.md when creating any visual node

---

## When Something Is Unclear

1. Check `GDD.md` first
2. Check `SCOPE.md` second
3. If still unclear, implement the minimum that satisfies the task and add a `# QUESTION:` comment in the relevant file describing what needs clarification
4. Never silently guess at design intent for player-facing systems
