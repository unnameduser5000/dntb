# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

《地牢编排师：禁忌之键》 / Dungeon Arranger: Forbidden Keys (`DNTB`) is a Godot 4 tactical roguelite prototype. The core idea is programmable direction keys: the player edits twelve physical key slots (`QWER / ASDF / ZXCV`) at camp/rest nodes and tavern safe areas, and during combat those slots are locked. Pressing a key executes the slot's token chain.

The project is early-stage and intentionally small. Keep gameplay systems easy to inspect, test, and refactor.

Read `AGENTS.md` first for project-specific conventions; it is written in Chinese and takes precedence over this file where they overlap.

## Requirements

- Godot 4.7 stable or a compatible Godot 4.x build.
- Git.
- Git LFS (MP3 audio assets are tracked by LFS; CI and fresh clones need LFS initialized).

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

Run other smoke tests and probes:

```powershell
godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd
godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd
godot --headless --path . --script res://scripts/tests/MapPrintProbe.gd
godot --headless --path . --script res://scripts/tests/LargeMapPlacementProbe.gd
```

Import assets headless (useful on fresh clones or CI before running tests):

```powershell
godot --headless --path . --import
```

If Godot is not on PATH, run it with the full executable path instead:

```powershell
& "C:\Path\To\Godot.exe" --headless --path . --script res://scripts/tests/SmokeTest.gd
```

There is no separate build, lint, or package step. Godot loads the project directly from `project.godot`.

### Running a single test

`SmokeTest.gd` is a single SceneTree script with a long sequence of inline assertions; it is not a test framework with selectable cases. To isolate a failing section, either temporarily comment out the unrelated parts of `_init()` or create a small focused test script under `scripts/tests/` and run it with `--script`.

### Git LFS assets

MP3 files under `music/` are tracked by Git LFS. After cloning, verify they are real binaries:

```powershell
wc -c music/*.mp3
```

If any file is only ~132 bytes (an LFS pointer), run:

```powershell
git lfs pull
```

## Entry points and scenes

- Main scene configured in `project.godot`: `res://scenes/game/App.tscn`.
- Core gameplay scene: `res://scenes/game/Game.tscn`.
- Smoke test entry: `res://scripts/tests/SmokeTest.gd`.
- System design doc (Chinese): `docs/01_系统设计文档.md`.
- Collaboration guide (Chinese): `docs/02_开发协作指南.md`.
- Testing guide (Chinese): `docs/03_测试与验证.md`.
- Development log: `DEVELOP_LOG.md`.

### Scene hierarchy

```text
App (scripts/view/App.gd)
├── AppBackground
├── Game (scripts/view/Game.gd)
│   ├── BoardView
│   ├── ActorRoot
│   ├── EffectRoot
│   ├── CanvasLayer/BattleUI
│   ├── TurnController
│   ├── ActionResolver
│   ├── EnemyPlanner
│   └── RunController          # skeleton node; run logic is still in Game.gd
└── MenuLayer
    ├── MainMenu
    ├── SettingsMenu
    └── PauseMenu
```

`Game.gd` is the composition root for a run. It owns `GameState`, wires core controllers, registers save providers, and coordinates UI refreshes. Prefer extracting new rules into core/runtime/data layers rather than growing `Game.gd`.

## High-level architecture

### Layer responsibilities

- `scripts/core/` — controllers and services. Owns turn flow, action resolution, input, save/settings, random, achievements, enemy spawning, world-slice generation, and run logic. Core scripts may coordinate multiple systems but should not contain UI layout.
- `scripts/runtime/` — short-lived per-battle state objects, usually `RefCounted`. Includes `ActorState`, `ActionInstance`, `EffectPacket`, `EffectEvent`, `EffectPipeline`, `CombatContext`, `TurnResult`, `KeyProgram`, `ActionTrace`, and `ActionTraceEntry`.
- `scripts/data/` — Godot `Resource` classes that define editable data and extension points: `ActionDef`, `ActorDef`, `WeaponDef`, `EffectModifierDef`, `AchievementDef`, `RewardDef`, `RoomDef`, etc.
- `scripts/view/` — scene and UI scripts. Responsible for rendering, signals, and forwarding user intent to core. Do not put combat rules here.
- `data/` — concrete resource instances: actions, actors, weapons, modifiers, achievements.
- `addons/dialogue_manager/` — third-party Dialogue Manager addon. Keep its structure and license intact. The project wraps it with `scripts/core/DialogueManagerAutoload.gd` and `scripts/core/DialogueService.gd` for CI/headless safety.

### Key data flow for a player key press

```text
keyboard event
→ PlayerInputService maps player_key_q ... player_key_v to a key slot id
→ Game._submit_key_chain(key_id)
→ ActionProgramController translates slot tokens into ActionInstance queue
→ DirectionalTechniqueResolver resolves the generic attack token to the actor's weapon attack_action
→ TurnController.submit_player_plan(plan)
→ ActionResolver.resolve(action, state)
→ EffectPipeline processes EffectPackets, modifiers, and event reactions
→ GameState / GridModel update
→ ActionTraceRecorder writes execution semantics
→ EnemyPlanner preview or execute enemy actions
→ Game refreshes BoardView / BattleUI / ActorRoot
```

### Important ownership boundaries

- `ActionProgramController.gd` is the single source of truth for key-slot and pool-token state. It manages twelve physical slots (`QWER / ASDF / ZXCV`) and a pool of unassigned tokens. `Game.gd` only exposes read accessors; any older mirrored fields in `Game.gd` are observation-only and should not be treated as authoritative.
- `TurnController.gd` owns turn phase and action execution order. It records `ActionTrace` entries after each resolved action but does not implement specific combat rules.
- `ActionResolver.gd` owns movement, attacks, turns, guards, jumps, death, and win/loss checks.
- `EffectPipeline.gd` (in `scripts/runtime/`) owns effect-packet modification, execution, and event reactions. Relics, status effects, and weapon affixes should extend `EffectModifierDef`.
- `GameState.gd` owns the mutable battle state, including `action_trace` and run-progress fields.
- `DirectionalTechniqueResolver.gd` translates input tokens (`U/D/L/R`, `F/B/SL/SR/DS/HK/SB/HM/RA/PI/TH/SW/BW/CA/TL/TR/A/I/G/W/J`) into base executable actions. The generic attack token `A` resolves to the actor's equipped weapon `attack_action`.
- `ActionTraceRecorder.gd` writes execution semantics (`F/B/SL/SR/TL/TR`) after actions resolve. `ActionTrace` is consumed by debug UI and is the intended hook for future combo recognition.
- `BattlePresentationController.gd` and `ActorRoot` handle actor visuals; `EffectRoot` / `BattleEffectController.gd` handle battle feedback effects. They are presentation-only and do not own combat state.
- `ActorInteractionService.gd` handles world-slice NPC/POI interactions. `ActorDef` carries interaction fields (`interaction_enabled`, `interaction_title`, `interaction_lines`) so both monsters and NPCs can be interacted with or killed through the same rules.

### Weapon model

`WeaponDef.gd` is a thin data resource: one weapon corresponds to one `attack_action`. The generic attack token `A` is resolved by `DirectionalTechniqueResolver` into the actor's `active_weapon.attack_action`. Weapon differences are expressed through distinct `ActionDef` resources, not through per-weapon combat hooks.

Current examples:

- `impact_shield` → `attack`
- `iron_spear` → `charge_thrust`
- `greatblade` → `great_sweep`

`ActionTrace` records the real executed outcome (e.g., blocked moves drop their relative-move symbol). Any future weapon combo or technique recognition should read `ActionTrace` rather than raw input tokens.

### Effect pipeline extension

Extend `EffectModifierDef` for new relics, status effects, or weapon rules:

- `modify_packets(packet, context)` — alter, amplify, duplicate, or cancel effect packets before execution.
- `react_to_event(event, context)` — generate follow-up packets in response to damage, movement, kills, knockback, etc.
- `priority` controls modifier order.
- `max_generation_depth` / `max_event_depth` limit recursive generation.

### World-slice mode

`WorldSliceController.gd` generates a large open map (`WORLD_GRID_SIZE = 256×256`). When `state.is_world_slice` is true:

- `BoardView` renders a moving window around the player with fog-of-war.
- `Game._update_world_slice_editability()` enables key-slot editing only while the player stands on a tavern safe-area footprint walkable cell (`building_floor`, `building_door`, `building_open_ground`, or tavern interactable).
- Safe-zone NPCs are spawned from `npc_spawn_slots` declared in `BuildingPatternLibrary.tavern`; the starting tavern generates a `tavern_keeper`.
- POI hints in the sidebar show relative directions to `Boss遗迹` (`challenge_entrance`) and `最近小遗迹` (nearest `ruin`). Clicking them starts an auto-path that pauses when enemies become visible or the player takes damage.
- Entering a `challenge_entrance` switches to a large-map Boss dungeon layer (`MAP_NODE_BOSS`) with overworld systems disabled.
- Debug keys while in world-slice mode:
  - `V` — toggle reveal-all fog.
  - `M` — print map summary.
  - `F5` — regenerate with the same seed.
  - `F6` — regenerate with a new seed.

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
- `DialogueManager` (project wrapper in `scripts/core/DialogueManagerAutoload.gd`)
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
- When changing UI layouts, check at least 1280×720, 1600×900, and 1920×1080.

## CI

`.github/workflows/smoke-test.yml` runs the smoke test on every push to `main` and on every pull request using `chickensoft-games/setup-godot@v2` with Godot 4.7.0.

The workflow checks out with `lfs: true` and runs `git lfs pull` before importing assets, because MP3 audio files are tracked by Git LFS and the runner needs real binaries for Godot's import step.
