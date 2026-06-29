# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

DNTB is a Godot 4 tactical roguelite prototype. The core idea is programmable direction keys: the player edits four physical key slots (U/D/L/R) at camp/rest nodes, and during combat those slots are locked and pressing a key executes the slot's token chain.

The project is early-stage and intentionally small. Keep gameplay systems easy to inspect, test, and refactor.

## Requirements

- Godot 4.7 stable or a compatible Godot 4.x build.
- Git.

## Common commands

Run the project from the repository root:

```powershell
godot --path .
```

Run the main scene explicitly:

```powershell
godot --path . res://scenes/game/App.tscn
```

Run the headless smoke test (used by CI and recommended before submitting changes):

```powershell
godot --headless --path . --script res://scripts/tests/SmokeTest.gd
```

Run the actor-presentation sandbox smoke test:

```powershell
godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd
```

Run the battle-effect sandbox smoke test:

```powershell
godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd
```

If Godot is not on PATH, run it with the full executable path instead:

```powershell
& "C:\Path\To\Godot.exe" --headless --path . --script res://scripts/tests/SmokeTest.gd
```

There is no separate build, lint, or package step. Godot loads the project directly from `project.godot`.

## Entry points and scenes

- Main scene configured in `project.godot`: `res://scenes/game/App.tscn`.
- Core gameplay scene: `res://scenes/game/Game.tscn`.
- Smoke test entry: `res://scripts/tests/SmokeTest.gd`.
- System design doc (Chinese): `docs/01_系统设计文档.md`.
- Collaboration guide (Chinese): `docs/02_开发协作指南.md`.
- Testing guide (Chinese): `docs/03_测试与验证.md`.
- Development log: `DEVELOP_LOG.md`.

Read `AGENTS.md` first for project-specific conventions; it is written in Chinese and takes precedence over this file where they overlap.

## High-level architecture

### Scene hierarchy

```text
App (scripts/view/App.gd)
├── AppBackground
├── Game (scripts/view/Game.gd)
│   ├── BoardView
│   ├── ActorRoot
│   ├── CanvasLayer/BattleUI
│   ├── TurnController
│   ├── ActionResolver
│   ├── EnemyPlanner
│   ├── RunController
│   └── WorldSliceController
└── MenuLayer
    ├── MainMenu
    ├── SettingsMenu
    └── PauseMenu
```

`Game.gd` is the composition root for a run. It owns `GameState`, wires core controllers, registers save providers, and coordinates UI refreshes. Prefer extracting new rules into core/runtime/data layers rather than growing `Game.gd`.

### Layer responsibilities

- `scripts/core/` — controllers and services. Owns turn flow, action resolution, input, save/settings, random, achievements, enemy spawning, and run logic. Core scripts may coordinate multiple systems but should not contain UI layout.
- `scripts/runtime/` — short-lived per-battle state objects, usually `RefCounted`. Includes `ActorState`, `ActionInstance`, `EffectPacket`, `EffectEvent`, `CombatContext`, `TurnResult`, `KeyProgram`, `ActionTrace`, and `ActionTraceEntry`.
- `scripts/data/` — Godot `Resource` classes that define editable data and extension points: `ActionDef`, `ActorDef`, `WeaponDef`, `EffectModifierDef`, `WeaponTechniqueDef`, `AchievementDef`, `RewardDef`, `RoomDef`, etc.
- `scripts/view/` — scene and UI scripts. Responsible for rendering, signals, and forwarding user intent to core. Do not put combat rules here.
- `data/` — concrete resource instances: actions, actors, weapons, modifiers, weapon techniques, achievements.
- `addons/dialogue_manager/` — third-party Dialogue Manager addon. Keep its structure and license intact.

### Key data flow for a player key press

```text
keyboard event
→ PlayerInputService maps player_move_* to a key slot id
→ Game._submit_key_chain(key_id)
→ ActionProgramController translates slot tokens into ActionInstance queue
→ TurnController.submit_player_plan(plan)
→ ActionResolver.resolve(action, state)
→ EffectPipeline processes EffectPackets, modifiers, and event reactions
→ GameState / GridModel update
→ EnemyPlanner preview or execute enemy actions
→ Game refreshes BoardView / BattleUI / ActorRoot
```

### Important ownership boundaries

- `ActionProgramController.gd` is the single source of truth for key-slot and pool-token state. `Game.gd` only exposes read accessors; any older mirrored fields in `Game.gd` are observation-only and should not be treated as authoritative.
- `TurnController.gd` owns turn phase and action execution order. It does not implement specific combat rules.
- `ActionResolver.gd` owns movement, attacks, turns, guards, jumps, weapon hooks, death, and win/loss checks.
- `EffectPipeline.gd` owns effect-packet modification, execution, and event reactions. Relics, status effects, and weapon affixes should extend `EffectModifierDef`.
- `GameState.gd` owns the mutable battle state, including `action_trace`, `weapon_combo_matches_by_actor`, and `unlocked_weapon_technique_ids`.
- `DirectionalTechniqueResolver.gd` only translates absolute input tokens (`U/D/L/R`, and control tokens like `F/TL/TR/J`) into base executable actions. It no longer derives weapon techniques directly.
- `ActionTraceRecorder.gd` writes execution semantics (`F/B/SL/SR/TL/TR/J`) after actions resolve.
- `WeaponComboResolver.gd` matches `ActionTrace` against a weapon's `combo_techniques`. `TurnController.gd` executes the matched technique's follow-up `ActionDef`.
- `BattlePresentationController.gd` and `ActorRoot` handle actor visuals; `EffectRoot` / `BattleEffectController.gd` handle battle feedback effects. They are presentation-only and do not own combat state.

### Weapon techniques and combos

Weapon techniques are no longer created by direction chains in `ActionProgramController`. The live flow is:

1. `KeyProgram` stores editable tokens in the four physical slots.
2. `DirectionalTechniqueResolver` maps tokens to base actions (e.g., `R` → `move_key`).
3. Combat resolves the base actions, and `ActionTraceRecorder` writes the relative trace.
4. `WeaponComboResolver` reads the trace and the weapon's `combo_techniques`.
5. `TurnController` executes the matched technique's follow-up `ActionDef`.

To add a new weapon technique:

1. Add or reuse a follow-up `ActionDef` in `data/actions/`.
2. Add a `WeaponTechniqueDef` in `data/weapon_techniques/`.
3. Reference it from the weapon's `combo_techniques` array.
4. Decide how the run unlocks that technique id.

Rest-site preview may predict likely combo hits from a planned token chain, but actual battle triggering uses the real `ActionTrace`, so terrain, collisions, and effect-driven movement can prevent a combo even when the planned chain looks correct.

### Effect pipeline extension

Extend `EffectModifierDef` for new relics, status effects, or weapon rules:

- `modify_packets(packet, context)` — alter, amplify, duplicate, or cancel effect packets before execution.
- `react_to_event(event, context)` — generate follow-up packets in response to damage, movement, kills, knockback, etc.
- `priority` controls modifier order.
- `max_generation_depth` / `max_event_depth` limit recursive generation.

### Autoloads

`project.godot` registers these autoloads:

- `SettingsService`
- `SaveService`
- `SceneService`
- `AudioService`
- `AchievementService`
- `RandomService`
- `PlayerInputService`
- `CurseService`
- `EnemySpawnService`
- `EconomyService`
- `DialogueManager` (third-party)
- `DialogueService`

Prefer adding scene-local nodes/Resources over new autoloads unless the service truly needs global lifetime.

## Collaboration rules

- Use tabs for GDScript and Godot text resources.
- Keep functions short and names clear.
- Do not commit `.godot/`, exported builds, local logs, temporary script caches, or personal IDE state.
- Keep Godot-generated `.gd.uid` and `.import` sidecar files alongside the resources they belong to.
- Keep text resources UTF-8.
- Avoid editing `project.godot` fields by hand unless you understand their impact; prefer the Godot editor.
- Avoid modifying `addons/dialogue_manager/` unless the change is genuinely needed.
- Update `DEVELOP_LOG.md` for notable gameplay, architecture, testing, or repository-process changes.
- Run the smoke test when possible before opening a pull request.

## CI

`.github/workflows/smoke-test.yml` runs the smoke test on every push to `main` and on every pull request using `chickensoft-games/setup-godot@v2` with Godot 4.7.0.
