# Develop Log

## 2026-06-30 Battle UI inventory/debug split

- Moved the run inventory from the old left drawer into a dedicated backpack
  panel opened by the bottom-right `背包` button.
- Moved event history and debug status into the bottom-right `菜单` panel so
  `BattlePanel` stays focused on key-slot programming and enemy intent.
- Added a unified player position / facing box to `BattleHud`, and boxed the
  in-world facing marker over the player sprite to reduce visual separation
  during movement.

## 2026-06-29 256x256 building stamp stabilization and map generation cost trim

- Kept the first-pass footprint placement architecture, but made it more diagnosable and less brute-force on larger maps.
- Building placement now:
  - records per-POI failure summaries and last failure context in `MapData`;
  - normalizes common stamp failure reasons into clearer buckets such as:
    - `overlaps_spawn`
    - `forbidden_terrain`
    - `overlaps_existing_poi`
    - `overlaps_existing_structure`
    - `not_enough_front_clearance`
    - `not_enough_interaction_space`
    - `max_attempts_exceeded`
  - uses staged candidate search instead of scanning every local origin:
    - anchor-local sample
    - expanded local fallback
    - reachable-global fallback
- Kept legacy single-cell POI picks as scaffolding, but reduced their large-map cost by sampling candidate walkable/reachable cells before scoring.
- Reworked world-map connectivity to avoid repeated high-cost whole-map region stitching passes:
  - added a faster packed-byte walkable-region collector;
  - stitches sampled secondary regions into the main region in batches;
  - keeps local tree-gap cleanup for tiny near-touching regions;
  - preserves the smoke-test guarantee that all walkable cells remain connected from spawn.
- Expanded `MapPrintProbe.gd` so large-map inspection now also reports building failure summary / fallback context in addition to footprint counts and timing.

## 2026-06-29 First-pass building PatternStamp scaffold

- Added a first-pass data-first building footprint layer for the world map instead of keeping POI as single-cell markers only.
- Added:
  - `scripts/core/BuildingPatternLibrary.gd`
  - `scripts/core/PatternStampService.gd`
  - `scripts/core/BuildingPlacementService.gd`
- Extended `MapCell` / `MapData` so stamped structures can carry:
  - footprint occupancy
  - interaction cells
  - entrance cells
  - per-cell display symbol overrides
  - building / structure / stamp tags
  - generation-time stamp success/failure records
- Wired `POIPlacementService.gd` to replace the current legacy single-cell POI markers with footprint-based building placement during world generation, while leaving the old pick logic in place as fallback/demo scaffold.
- Expanded `MapPrintProbe.gd` to print:
  - building counts
  - stamp success/failure totals
  - per-building metadata
  - local windows around each stamped building footprint
- Extended `SmokeTest.gd` world-slice checks so the generated map now validates footprint-based POI records and basic reachability of stamped interaction cells.

## 2026-06-29 Data-first world map scaffold tuning

- Continued the data-first world-slice map scaffold instead of expanding room rewards or combat features.
- Added map-generation core scripts and kept them separate from GridModel / combat runtime ownership:
  - `MapCell.gd`
  - `MapData.gd`
  - `MapGenConfig.gd`
  - `WorldGenerator.gd`
  - `MountainGenerator.gd`
  - `TerrainGenerator.gd`
  - `RiverGenerator.gd`
  - `POIPlacementService.gd`
  - `ConnectivityService.gd`
  - `VisibilityService.gd`
- Wired `WorldSliceController.gd` to build world-slice state from generated `MapData` and copy only walk-blocking terrain into `GridModel`.
- Updated `BoardView.gd` to render terrain/data-layer cells instead of only generic floor/wall output.
- Updated world-slice sidebar/debug output with map seed / terrain counts / POI / reachability summary and debug hotkeys.
- Fixed a real connectivity bug: carved mountain passes were previously allowed to form diagonal-only links, which did not match the project's cardinal movement rules.
  - `ConnectivityService.gd` now carves cardinal corridors instead of Bresenham diagonal lines.
  - Smoke coverage was added so carved passes must stay cardinally connected.
- Tightened world-slice runtime scope so large maps do not behave like full-map active simulations by default:
  - enemy planning / threat preview now only considers visible enemies in world-slice mode;
  - actor presentation only maintains views for the player plus visible actors in world-slice mode.
- Tuned early map-generation defaults after manual ASCII inspection showed mountain/peak belts were over-blocking routes:
  - reduced ridge width / branch count / noise strength;
  - raised hill/mountain/peak thresholds;
  - increased spawn openness requirements;
  - adjusted POI scoring so challenge/rest/event sites prefer more cardinally open reachable cells instead of hugging the tightest mountain edges.

Validation:

- `SmokeTest passed`
- Used `scripts/tests/MapPrintProbe.gd` to print sample ASCII maps and inspect route pressure / pass carving / POI reachability.

## 2026-06-23

- Continued the interrupted safe refactor around scripts/view/Game.gd.
- Added scripts/core/ActionProgramController.gd as the owner of key-slot programming state:
  - default U/D/L/R slot setup;
  - token-to-action plan building;
  - token moves between slots and the pool;
  - key-program save/load payloads;
  - token display labels.
- Added scripts/core/ActionPreviewService.gd for hover-only key-slot previews:
  - predicts move cells and attack cells without mutating real GameState;
  - keeps the current lunge/sweep/move/turn preview behavior together in one service.
- Kept Game.gd compatibility wrappers for current smoke tests and debug habits:
  - _key_slots and _pool_tokens remain as mirrored observation fields;
  - _build_key_slot_plan(), _build_key_slot_preview(), _on_key_token_move_requested(), and related entry points still exist but delegate to the new core services.
- Marked the compatibility mirror in Game.gd so it is not mistaken for the real source of truth.
- Left room/map data hardcoded for now. scripts/data/RoomDef.gd exists as a future data-driven-room scaffold, but this refactor intentionally did not migrate room definitions yet.

Validation notes:

- Static scan found no remaining Game.gd references to the moved preview helpers or moved key constants.
- Godot executable was not available on PATH or in the common local project/install locations checked from this environment, so scripts/tests/SmokeTest.gd could not be run here.

Next suggested checks:

- Run the smoke test from a machine with Godot available:
  godot --headless --path F:\\game_project\\dntb --script res://scripts/tests/SmokeTest.gd
- If Godot generates .gd.uid files for the two new scripts, keep them with the scripts.

## 2026-06-23 Repository readiness

- Added public repository collaboration files:
  - README.md
  - LICENSE
  - CONTRIBUTING.md
  - CODE_OF_CONDUCT.md
  - SECURITY.md
  - GitHub issue templates
  - GitHub pull request template
  - GitHub Actions smoke-test workflow
- Expanded .gitignore for Godot caches, exported builds, local logs, OS metadata, IDE state, and helper-script caches.
- Expanded .gitattributes and .editorconfig so collaborators get stable line endings and Godot-friendly indentation.
- Marked smoke_debug.log as generated diagnostic output that should stay out of the repository.

## 2026-06-24 Animation groundwork

- Added scripts/core/BattlePresentationController.gd as a lightweight presentation layer between combat logic and actor visuals.
- Connected Game.gd to maintain actor views under ActorRoot instead of relying only on full-board ASCII refreshes.
- Wired presentation hooks to existing combat events:
  - turn_controller.action_started
  - resolver.actor_moved
  - resolver.actor_damaged
  - resolver.actor_died
- Expanded scripts/view/ActorView.gd with small move / hit / die / action-start tweens so later sprite-sheet or AnimatedSprite2D work has a dedicated host component.
- Intentionally did not convert TurnController to an awaited per-action animation queue yet. Current battle resolution timing stays synchronous so existing behavior and smoke tests are less likely to regress.
- Result: the project now has a dedicated place to swap ASCII labels for real player/enemy sequence animation without first re-opening combat rules and state ownership.

## 2026-06-24 Awaitable action presentation

- Verified local Godot execution on F:\\Godot_v4.7-stable_win64.exe.
- Fixed a pre-existing GDScript type inference issue in Game.gd save serialization so SmokeTest could load and run under Godot 4.7.
- Extended BattlePresentationController with an awaitable playback mode for:
  - action start
  - actor move
  - actor damage
  - actor death
- Added a presentation-frame queue in ActionResolver so combat resolution can expose movement / damage / death as ordered playback events without changing game-state ownership.
- Updated TurnController to support two execution paths:
  - headless / smoke-test mode keeps the old synchronous turn flow
  - presentation mode awaits action playback between resolver steps
- Rewired Game.gd to let TurnController own the waited presentation path, avoiding duplicate visual playback from direct resolver signal handlers.
- Validation: local SmokeTest passed again after the awaited presentation step.

## 2026-06-24 Actor view host upgrade

- Upgraded the default actor presentation host in scripts/view/ActorView.gd from glyph-only fallback logic to a mixed host that can drive:
  - AnimatedSprite2D-based sequence playback when sprite frames exist;
  - Label glyph fallback when no animation resource is attached yet.

## 2026-06-27 Weapon combo smoke coverage

- Added explicit SmokeTest coverage for impact_shield combo resolution:
  - direct weapon equip in the test setup;
  - positive lunge and sweep traces;
  - negative trace cases that must not trigger combo follow-ups;
  - absolute-direction U trace recording as SL when facing right.

## 2026-06-27 Weapon combo lab scaffold

- Added a debug-only `start_weapon_combo_lab_debug()` entry on Game.gd.
- The lab uses a small safe-training state with impact_shield equipped, lunge/sweep unlocked, relative starter key slots, and two nearby enemies for manual combo testing.
- Added default animation-name conventions in ActorView for future per-actor frame sets:
  - idle / idle_up / idle_down / idle_left / idle_right
  - move / move_*
  - hit or hurt
  - die or dead
  - action_start / act / windup / attack
- Kept fallback behavior intact so the current project still renders correctly without any new art assets.
- Wired ActorDef.view_scene into BattlePresentationController so each actor definition can now supply a custom Node2D battle view scene without reopening combat-state code.
- Documented ActorDef.view_scene and ActorDef.color as presentation-facing fields instead of leaving them as silent scaffold.
- Validation: local SmokeTest passed after the actor-view host upgrade using:
  F:\\Godot_v4.7-stable_win64.exe\\Godot_v4.7-stable_win64_console.exe --headless --path F:\\game_project\\dntb --script res://scripts/tests/SmokeTest.gd

Next suggested step:

- Add one real custom actor view scene plus a small SpriteFrames resource for the player or a single enemy to validate the end-to-end sequence-frame workflow before producing a full art pass.

## 2026-06-24 Custom actor view validation

- Added dedicated battle view scenes for both sides of combat:
  - scenes/actors/PlayerActorView.tscn
  - scenes/actors/EnemyActorView.tscn
- Wired actor definitions to those scenes through ActorDef.view_scene:
  - player.tres
  - monster.tres
  - brute.tres
  - boss.tres
- Validated the full custom-view path from ActorDef.view_scene -> BattlePresentationController -> ActorView animation host instead of only using the default fallback scene.
- Implemented lightweight debug sequence frames in PlayerActorView.gd and EnemyActorView.gd so the custom-view path is testable before a real art pass lands.
- Added per-actor presentation layout controls in ActorDef:
  - view_offset
  - view_scale
  This keeps future sprite-sheet integration data-driven when different actors need different pivots or apparent sizes within the same board cell.
- Cached the generated debug SpriteFrames resources so repeated actor instances reuse the same placeholder animation data instead of rebuilding it per bind.
- Fixed a Godot 4.7 type-inference parse issue in EnemyActorView.gd discovered during validation of the enemy custom-view path.

Validation:

- Smoke test passed again after the custom actor view validation step:
  F:\\Godot_v4.7-stable_win64.exe\\Godot_v4.7-stable_win64_console.exe --headless --path F:\\game_project\\dntb --script res://scripts/tests/SmokeTest.gd

Next suggested step:

- Add one editor-facing sample pass that sets non-default view_scale / view_offset on a large actor such as the boss, then verify it visually in-engine and lock down the preferred pivot convention for future art assets.

## 2026-06-24 Presentation sandbox and pivot sample

- Added a concrete large-actor sample to data/actors/boss.tres:
  - view_scale = Vector2(1.35, 1.35)
  - view_offset = Vector2(0, -8)
- Added scenes/debug/ActorPresentationSandbox.tscn and scripts/view/ActorPresentationSandbox.gd as a dedicated visual sandbox for actor presentation work.
- The sandbox instantiates player, slime, brute, and boss through their real ActorDef.view_scene wiring rather than a separate preview-only path.
- Added an automatic demo loop in the sandbox for:
  - idle
  - action start
  - hit
  - move
  - die
  This makes it easier to check whether scale and offset still look correct across the motions that matter for later sequence-frame assets.
- Added scripts/tests/ActorPresentationSandboxSmoke.gd so the sandbox scene can be instantiated headlessly during validation instead of relying only on manual editor opens.

Validation target:

- Re-run both:
  - scripts/tests/SmokeTest.gd
  - scripts/tests/ActorPresentationSandboxSmoke.gd

## 2026-06-24 Battle effect skeleton

- Added `scripts/core/BattleEffectController.gd` as a project-owned effect dispatch layer for battle feedback.
- Added `scripts/view/BattleEffect.gd` as a no-asset procedural placeholder renderer so the repository can validate hit / miss / collision / death / action-start feedback before a real art pass lands.
- Added reusable placeholder effect scenes under `scenes/effects/`:
  - `BattleActionStartedEffect.tscn`
  - `BattleHitEffect.tscn`
  - `BattleMissEffect.tscn`
  - `BattleImpactEffect.tscn`
  - `BattleDeathEffect.tscn`
- Extended `BattlePresentationController` to own an `EffectRoot` alongside `ActorRoot`, clear spawned effects between state resets, and forward presentation frames into the new effect controller.
- Added `EffectRoot` to `scenes/game/Game.tscn` and wired `Game.gd` to keep it visible with the rest of the battle presentation layer.
- Extended `ActionResolver` presentation frames so the effect layer now has ordered hooks for:
  - `attack_missed`
  - `move_collision`
  - `actor_damaged`
  - `actor_died`
- Added `scenes/debug/BattleEffectSandbox.tscn` and `scripts/view/BattleEffectSandbox.gd` as a dedicated visual sandbox that reuses the real battle effect controller and actor-view scenes instead of a preview-only path.
- Added `scripts/tests/BattleEffectSandboxSmoke.gd` so the effect sandbox can be instantiated headlessly during validation.

Validation target:

- Re-run all three:
  - `scripts/tests/SmokeTest.gd`
  - `scripts/tests/ActorPresentationSandboxSmoke.gd`
  - `scripts/tests/BattleEffectSandboxSmoke.gd`

## 2026-06-25 Derived weapon techniques from direction chains

- Changed `lunge` and `sweep` from draggable key-program action tokens into derived weapon techniques.
- Added `scripts/core/DirectionalTechniqueResolver.gd` as the explicit layer that translates:
  - natural direction-token chains
  - into executable actions and derived weapon techniques
- Narrowed `ActionProgramController.gd` so the programmable key layer now owns only natural U/D/L/R direction tokens.
- Updated `ActionPreviewService.gd` so previews are generated from the resolved action queue after derived-technique translation, keeping preview and runtime execution on the same path.
- Added weapon-side technique support in `WeaponDef.gd` and marked `impact_shield.tres` as supporting:
  - `lunge`
  - `sweep`
- Reworked run rewards in `Game.gd` so these are now “unlock technique” rewards instead of “add draggable action token” rewards.
- Added run-state tracking for unlocked weapon techniques and included it in save data.
- Updated key-program comments in `Game.gd` to make the intended boundary explicit for teammates:
  - key slots own natural direction input
  - weapon techniques are derived later from direction patterns
- Added `scripts/data/TechniquePatternDef.gd` plus sample resources under `data/techniques/` so derived weapon techniques are now configured as data instead of hardcoded `if lunge / if sweep` branches.
- Reworked `DirectionalTechniqueResolver.gd` to consume an ordered pattern list, sort by consume length / priority, and build runtime actions from those pattern resources.
- Wired the default pattern list from `Game.gd`, which makes the extension path for teammates:
  - add an `ActionDef`
  - add a `TechniquePatternDef`
  - declare weapon support
  - decide how the technique is unlocked in the run
- Added the missing `scripts/core/DirectionalTechniqueResolver.gd.uid` metadata file so the repository stays consistent when shared as a public Godot project.

## 2026-06-26 KeyProgram extraction groundwork

- Added `scripts/runtime/KeyProgram.gd` as a dedicated runtime data model for programmable key-slot sequences.
- Narrowed `ActionProgramController.gd` so it now wraps key-program data concerns instead of also trying to own runtime action translation.
- Added `combo_symbol` to `ActionDef.gd` and populated the current primitive action resources with initial symbols:
  - `move_forward` -> `F`
  - `move_back` -> `B`
  - `turn_left` -> `TL`
  - `turn_right` -> `TR`
  - `attack` -> `A`
  - `wait` -> `W`
  - `guard` -> `G`
- Kept current gameplay behavior unchanged on purpose in this pass:
  - player-editable input tokens are still `U/D/L/R`
  - weapon-technique triggering is not yet migrated to ActionTrace / WeaponPattern
- This pass is the groundwork for the next combat-core refactor boundary discussed with the team:
  - `Input Token`
  - `KeyProgram`
  - `ActionTrace`
  - `Weapon Pattern`
  - `Input Interference`
- Validation:
  - `SmokeTest passed`
  - `ActorPresentationSandbox smoke passed`
  - `BattleEffectSandbox smoke passed`

## 2026-06-26 Key-program naming cleanup

- Unified the spare-token terminology around `pool_tokens`:
  - `KeyProgram.pool_tokens`
  - `ActionProgramController.get_pool_tokens()`
  - `Game.gd` mirror field `_pool_tokens`
- Removed the old `loose_key_tokens` naming path instead of keeping a second synonym alive.
- Removed the unused `Game._get_key_token_container()` helper after confirming current UI flow no longer calls it.
- Removed the temporary legacy-action-token fallback in `DirectionalTechniqueResolver.gd`; key-program input is now explicitly only natural direction tokens at this stage.
- Removed the not-yet-needed legacy save migration branch for derived weapon techniques, since the project does not currently need compatibility with an already-deployed save format.

## 2026-06-27 ActionTrace groundwork

- Added `scripts/runtime/ActionTrace.gd` and `scripts/runtime/ActionTraceEntry.gd` as the first dedicated execution-trace layer.
- Added `scripts/core/ActionTraceRecorder.gd` to translate executed actions into lightweight trace entries without changing current combat resolution rules.
- Wired `TurnController.gd` to record trace entries after each executed action for both player and enemies.
- Added `state.action_trace` to `GameState.gd` and clear it on battle start, so each battle has an isolated trace history.
- Added debug-facing accessors in `Game.gd`:
  - `get_player_action_trace_symbols()`
  - `get_player_action_trace_debug_string()`
- Current scope is intentionally narrow:
  - record only
  - no weapon-technique trigger migration yet
  - no jump/interference behavior yet
- Current relative trace semantics for natural direction-token execution:
  - `F`
  - `B`
  - `SL`
  - `SR`
  - plus turn/action symbols already declared on primitive actions
- Current rule is intentionally simple and explicit: relative movement symbols are recorded against the actor's facing before that action executes.
- Validation target for this step:
  - ensure absolute direction input now leaves behind a stable relative trace that later weapon-pattern systems can consume.

## 2026-06-27 Weapon combo recognition skeleton

- Added `scripts/data/WeaponTechniqueDef.gd` as the future-facing weapon combo pattern resource.
- Added `scripts/core/WeaponComboResolver.gd` as a read-only resolver over `ActionTrace`.
- Extended `WeaponDef.gd` with `combo_techniques`.
- Added first sample weapon-technique resources for `impact_shield`:
  - `data/weapon_techniques/impact_lunge.tres`
  - `data/weapon_techniques/impact_sweep.tres`
- Wired `impact_shield.tres` to expose both:
  - the current transitional `weapon_technique_ids`
  - the new trace-driven `combo_techniques`
- Added debug-facing accessors in `Game.gd` so the current project can inspect recognized weapon combos before those combos take over execution:
  - `get_player_weapon_combo_matches()`
  - `get_player_weapon_combo_match_ids()`
- Scope intentionally remains conservative:
  - recognition only
  - no new combat trigger path yet
  - existing directional-technique execution path stays active for now

## 2026-06-27 Combo recognition ownership cleanup

- Moved weapon-combo recognition ownership out of `scripts/view/Game.gd` and into `scripts/core/TurnController.gd`.
- Added combo cache fields and helpers to `scripts/core/GameState.gd`:
  - `unlocked_weapon_technique_ids`
  - `weapon_combo_matches_by_actor`
- `TurnController.gd` now refreshes combo matches at the same chain-finished boundary used by weapon hooks, so UI/debug reads the resolved turn result instead of recomputing ad hoc.
- `Game.gd` no longer instantiates its own `WeaponComboResolver`; combo debug accessors now read cached state.
- New room/rest states now copy the current run's unlocked weapon techniques into battle state, and `_unlock_weapon_technique()` keeps that state copy in sync for mid-battle debug/tests.
- Also cleaned two small leftover transitional interfaces:
  - removed the unused action-dictionary dependency from `ActionPreviewService.gd`
  - removed the unused `DirectionalTechniqueResolver.make_action_from_token()` entry point

Validation:

- `SmokeTest passed`
- `ActorPresentationSandbox smoke passed`
- `BattleEffectSandbox smoke passed`

## 2026-06-27 Dynamic ActionTrace-driven weapon techniques

- Retired the old "KeyProgram direction chain directly becomes lunge/sweep" combat path.
- Simplified `scripts/core/DirectionalTechniqueResolver.gd` so it now only translates absolute input tokens into base executable actions.
- Removed the now-obsolete `TechniquePatternDef` route and deleted:
  - `scripts/data/TechniquePatternDef.gd`
  - `data/techniques/lunge_pattern.tres`
  - `data/techniques/sweep_pattern.tres`
- Extended `WeaponTechniqueDef.gd` with an optional follow-up `action` resource so combo recognition can point at a concrete weapon-payoff action without making that action draggable in KeyProgram.
- Wired `impact_lunge.tres` and `impact_sweep.tres` to their follow-up action resources.
- Updated `TurnController.gd` so chain-finished combo resolution now:
  - reads real `ActionTrace`
  - caches recognized matches in `GameState`
  - executes the best matched weapon technique as a follow-up action
- Tightened `WeaponComboResolver.gd` unlock gating so an empty run unlock list no longer behaves like "everything is unlocked."
- Updated `ActionTraceRecorder.gd` so blocked movement no longer records `F/B/SL/SR` just because the input intended to move that way.
  - This makes terrain/collision changes matter to combo triggering, which is the intended design direction.
- Extended `ActionPreviewService.gd` so rest-site preview can still predict likely combo hits and preview the best follow-up technique footprint without changing battle-time authority:
  - preview predicts from the planned chain
  - real triggering still uses live `ActionTrace`
- Added `Game.gd` helper `get_predicted_weapon_combo_match_ids_for_tokens()` for debug/tests.
- Updated `scripts/tests/SmokeTest.gd` to cover the new architecture:
  - unlocked lunge no longer replaces the base key plan
  - rest preview predicts combo hits from relative trace semantics
  - lunge/sweep now execute as post-trace weapon follow-ups
  - blocked movement no longer falsely triggers lunge

Validation:

- `SmokeTest passed`
- `ActorPresentationSandbox smoke passed`
- `BattleEffectSandbox smoke passed`

## 2026-06-27 Independent turn/jump programmable inputs

- Expanded the editable KeyProgram token set from pure absolute movement to:
  - `U`
  - `D`
  - `L`
  - `R`
  - `TL`
  - `TR`
  - `J`
- Updated `ActionProgramController.gd`, `KeyProgram.gd`, `PlayerInputService.gd`, `GameState.gd`, and `BattleUI.gd` so turn-left / turn-right / jump are first-class programmable input tokens instead of hidden future placeholders.
- Added `data/actions/jump.tres` and wired `Game.gd` + `DirectionalTechniqueResolver.gd` so:
  - `TL` resolves to `turn_left`
  - `TR` resolves to `turn_right`
  - `J` resolves to `jump`
- Implemented `jump` in `ActionResolver.gd` as a facing-based leap to the landing cell:
  - ignores intermediate occupancy;
  - still respects landing-cell enterability;
  - records `J` in `ActionTrace` only when the leap really resolves.
- Extended `ActionPreviewService.gd` so rest-site preview now understands jump landing cells too.
- Tightened `TurnController.gd` chain preparation so jump breaks directional momentum stacking instead of acting like another shove/charge step.
- Removed the old `get_pressed_move_action()` compatibility wrapper from `PlayerInputService.gd`; live slot execution now reads the more accurate `get_pressed_program_action()` entry point.
- Extended `SmokeTest.gd` coverage for the new input-program layer:
  - default `TL` / `TR` / `J` slots exist;
  - keyboard bindings map to those slot ids;
  - `TL` executes as a turn and records `TL`;
  - `J` executes as a jump and records `J`.

Validation:

- `SmokeTest passed`
- `ActorPresentationSandbox smoke passed`
- `BattleEffectSandbox smoke passed`

## 2026-06-27 Four-slot rollback / cleanup

- Rolled the programmable input layer back to exactly four physical slots:
  - `U`
  - `D`
  - `L`
  - `R`
- Kept turn logic inside the original slots instead of exposing separate extra
  physical slots:
  - `L` starts with `TL + L`
  - `R` starts with `TR + R`
- Removed the old `Game.gd` key-program mirror fields and let
  `ActionProgramController` remain the single source of truth for slot / pool
  data.
- Added `PlayerInputService.get_program_actions()` so settings UI no longer
  depends on a directly exported constant.
- Updated `BattleUI` token labels so `TL`, `TR`, and `J` render as readable
  names in the slot editor.
- Tightened `KeyProgram` / `ActionProgramController` read accessors to return
  copies, not live containers.
- Updated `SmokeTest.gd` to read key-program state through the new accessors.

## 2026-06-27 Removed the old direct-action queue layer

- Deleted the transitional `player_deck` route from `Game.gd`.
  - run save data no longer serializes `player_deck`
  - run load no longer rebuilds a starter direct-action deck
  - `Game.gd` no longer exposes `_on_plan_submitted()` as a UI entry point
- Simplified `BattleUI.gd` and `BattleUI.tscn` so the combat panel now focuses on:
  - key-slot editing / preview
  - rest-site continue flow
  - battle messages / enemy intents / overlay prompts
- Removed the dead direct-action queue UI pieces:
  - queue labels
  - execute / clear buttons
  - `plan_submitted` signal
  - `_current_plan` / `_available_actions` bookkeeping
- Simplified `RunSidebar.gd` status copy to stop presenting the removed "action library count" concept.
- Updated `SmokeTest.gd` so low-level combat checks that still want primitive actions now submit them directly to `TurnController`, instead of routing through the deleted UI queue.

Validation:

- `SmokeTest passed`
- `ActorPresentationSandbox smoke passed`
- `BattleEffectSandbox smoke passed`

## 2026-06-27 Removed stale key-program mirror callsites

- Fixed a parser error in `Game.gd` caused by two leftover calls to the deleted
  `_sync_key_program_mirror()` helper.
- Replaced both callsites with `_refresh_key_program_ui()`, which already pulls
  the current state from `ActionProgramController`.
- Confirmed there are no remaining `_sync_key_program_mirror()` references in
  the repository.

## 2026-06-27 Restored pure four-direction default key slots

- Restored the default key-program initialization to exactly four physical
  slots with pure absolute-direction contents:
  - `U -> [U]`
  - `D -> [D]`
  - `L -> [L]`
  - `R -> [R]`
- Kept `TL` / `TR` as programmable tokens, but stopped preloading them into the
  default `L` / `R` slot chains.
- Updated `SmokeTest.gd` to assert the new default slot contents.

## 2026-06-27 Added starter preset selection

- Added absolute / relative starter key-program presets and hooked run start to
  choose one preset per run.

## 2026-06-27 Mixed token drop pool

- Added a shared mixed token drop pool for future room/reward drops:
  U / D / L / R / F / TL / TR.
- Kept the four physical key slots unchanged and left battle structure/UI
  untouched.
- Extended SmokeTest coverage for mixed token pickup, pool entry, slot drag,
  and token-to-action plan mapping.

## 2026-06-27 Relative starter now turns before moving

- Updated the relative starter preset so each slot now resolves as a turn plus
  forward movement:
  - `U -> [F]`
  - `D -> [TR, TR, F]`
  - `L -> [TL, F]`
  - `R -> [TR, F]`
- Added a minimal facing label to the player presentation so the active facing
  is readable during combat/debug labs.
- Refreshed SmokeTest assertions for the new relative starter chains.

## 2026-06-28 Weapon combo semantics aligned to real execution

- Kept combo recognition on real `ActionTrace` semantics.
- Lunge now matches two consecutive successful moves in the same direction.
- Sweep now matches explicit `TL -> TR` symbol runs.
- SmokeTest coverage was updated and passes.

## 2026-06-28 Collision test isolation for weapon-owned combos

- Kept the existing impact-shield collision assertions intact.
- Added a test-only impact-shield clone with `combo_techniques = []` for pure
  collision coverage, so combo follow-ups do not pollute the old movement
  collision tests.

## 2026-06-28 Minimal world FOV slice

- Added a thin grid-based FOV layer for the world slice only.
- BoardView now distinguishes unseen / explored / visible cells.
- Added world-slice debug reveal-all and reset hotkeys plus smoke coverage.

## 2026-06-28 World slice viewport tightening

- Switched the world-slice board to a smaller player-centered render window so
  the full 30x30 state no longer crowds out the UI.
- Restored a more readable board scale for the playable slice.
- Nudged the default monster visual offset slightly toward the cell center to
  reduce the apparent sprite misalignment.

## 2026-06-29 Map connectivity stitching and wider passes

- Expanded world-map connectivity from “rescue unreachable POIs” to also stitch
  large secondary walkable regions back into the main reachable landmass.
- Added a small shortcut-pass budget plus variable pass width, while keeping
  all carved corridors cardinal so they stay valid for the current movement
  rules.
- Added smoke coverage that checks the generated world slice keeps the whole
  walkable terrain connected from spawn.

## 2026-06-29 Lighter mountain silhouette and forest blocker split

- Increased the world map scaffold to `64x64` so terrain density is easier to
  inspect than on the earlier `40x40` slice.
- Reframed forest from a broad opaque biome into walkable forest floor plus
  scattered `TREE` blockers that interrupt movement and sight in smaller
  tactical clusters.
- Softened mountains into a lighter macro silhouette and relied more on wider
  3-5 cell passes and local tree-gap cleanup instead of narrow single-cell
  chokepoints.
- Expanded `MapPrintProbe` to print larger seed samples and summarize mountain
  blocked ratio, forest blocker density, pass width, and local connectivity
  cleanup counts.

## 2026-06-29 World slice 256x256 performance boundary pass

- Raised the world-slice scaffold target to `256x256`, but kept the runtime
  optimization scope intentionally small: bounded-radius FOV, event-driven HUD,
  and a fixed active-window board render.
- Switched `BoardView` from rebuild-every-cell rendering to a reusable tile
  pool sized to the visible window, so world slice no longer instantiates or
  redraws the whole map surface on every refresh.
- Added lightweight generation / FOV / board timing counters plus render-window
  metrics to `GameState`, `MapData`, and the sidebar debug output.
- Reworked `MapPrintProbe` into summary + local-window output for `80x80`,
  `128x128`, and `256x256` maps so large-map inspection stays readable.

## 2026-06-29 World slice viewport recentered and sync loading overlay added

- Tightened the playable world-slice board to a `29x29` moving window and made
  its layout derive from the actual left-side viewport area, so the board stops
  crowding the right UI and actor overlays keep using the same origin math.
- Updated `BoardView` world/grid conversion to follow the node's live position
  instead of a stale exported origin value, which reduces visible board/FOV
  drift when the world window is recentered.
- Added a lightweight synchronous `WorldLoadingOverlay` that reports world
  generation stage progress between major map-building passes without adding
  threading or changing the core generation flow.
- Set the default playable world-slice size to `128x128` for a faster click-to-
  play loop, while keeping `MapPrintProbe` coverage for `256x256` performance
  boundary checks.

## 2026-06-30 World slice spawn semantics and map readability

- Moved the generated world-slice spawn onto the tavern footprint so the run
  now starts from a rest-building context instead of an unrelated open field.
- Upgraded the board's terrain placeholder rendering from mostly uniform tiles
  to semantic color blocks for building floors, doors, walls, tree blockers,
  hills, mountains, water, swamp, and desert.
- Kept the rendering layer data-first so later sprite / tileset integration can
  replace the placeholder palette without changing world-generation semantics.

## 2026-06-30 World slice rest-area editing gate

- Stopped treating world slice as globally editable for key-program changes.
- Key-program editing now unlocks only while the player is standing inside the
  tavern / rest-building footprint, and relocks after leaving that area.
- Kept the implementation lightweight by reusing existing building tags instead
  of adding a separate interaction-mode system.

## 2026-06-30 Tavern readability and edit-state feedback

- Split POI building colors a bit further so tavern / challenge / ruin-style
  footprints are easier to distinguish at a glance even before real tilesets.
- Added explicit world-slice status text for the current tile context and
  whether key-program editing is enabled or locked.
- Updated the battle-side title copy so players get a direct hint that editing
  unlocks inside the tavern and relocks after leaving it.

## 2026-06-30 Tavern enter/leave prompts and generated placeholder tile textures

- Added explicit world-slice messages for entering and leaving the tavern rest
  area so players get a clear interaction cue without a larger UI system.
- Upgraded board terrain presentation from flat semantic color blocks to small
  procedurally generated placeholder textures for plains, forest, trees, walls,
  buildings, hills, mountains, water, bridges, swamp, and desert.
- Kept the renderer asset-light: the current textures are generated in code, so
  the project stays easy to share while remaining ready for later sprite/tileset
  replacement.

## 2026-06-30 Real tile fallback assets

- Added a tiny project-local `art/tiles/board/` asset set for the core terrain
  and structure placeholders so the board can prefer real bitmap files first.
- Kept the procedural renderer as a safe fallback, and switched the loader to
  read workspace PNGs directly from disk so import metadata is not required.
- This gives the project a clean bridge toward future art replacement without
  changing map semantics or battle flow.

## 2026-06-30 Core tile pass toward more game-facing art

- Refined the first batch of bitmap board tiles so tavern floor/door, tree,
  wall, plain, water, hill, and mountain read more like deliberate game assets
  instead of generic debug placeholders.
- Added tavern-specific tile names and made the board renderer prefer those
  before falling back to generic building tiles.
- Kept everything inside the same resource/fallback pipeline so future art
  replacement stays incremental.

## 2026-06-30 Secondary board tile art pass

- Refined the remaining high-visibility bitmap tiles for forest, swamp, bridge,
  rock, challenge floor, ruin floor, shrine floor, river, and peak so the
  world slice reads less like placeholder debug geometry.
- Kept the same 64x64 project-local PNG workflow and direct disk-loading path,
  which means teammates can replace individual tiles later without touching the
  renderer or requiring import metadata for headless tests.
- Left map semantics unchanged: this pass is presentation-only and stays within
  the existing BoardView asset fallback pipeline.

## 2026-06-30 FOV textured fog pass and first built-in particle hook

- Fixed the explored-cell visibility presentation for real PNG board tiles by
  generating fogged texture variants instead of relying on flat palette darken
  logic that only worked well with debug-style color cells.
- This keeps world-slice FOV readable after art replacement without changing
  FOV rules, map generation, or actor logic.
- Also attached a very small GPUParticles2D burst to the existing hit effect so
  the project now has a clean in-engine example of how built-in Godot particles
  can layer on top of the current battle effect pipeline.

## 2026-06-30 Coarse world enemy streaming pass

- Replaced the strictly static "spawn four far-away test enemies once" feel
  with a rough world-slice enemy streaming pass aimed at performance testing.
- The world now keeps a local target number of active enemies near the player,
  despawns far unseen streamed enemies, and refills nearby spawn bands after
  player movement.
- This is intentionally a debug-grade density / culling scaffold for testing
  large-map pacing and hitching, not a final persistence or ecosystem system.

## 2026-06-30 World-slice layered presentation pass

- Split world-slice feel away from the legacy room-chain presentation timing:
  the world now defaults to logic-first, non-blocking presentation so movement
  resolves immediately while view tweens and effects continue asynchronously.
- Kept the legacy seeded / room-chain flow on the older blocking presentation
  path so existing combat readability and demo timing stay intact there.
- This is the first step toward a cleaner "gameplay response layer" vs
  "presentation layer" split instead of treating every animation wait as part
  of battle resolution.

## 2026-06-30 World-slice fast-feel timing preset

- Added timing profiles so world-slice can use a faster presentation preset
  while legacy room-chain scenes keep the slower readability-first preset.
- The fast preset shortens move / hit / windup / effect timing and removes the
  inter-action pause, but only for the world-slice path.
- This keeps tuning centralized and makes later feel iteration much safer than
  scattering hard-coded tween durations across multiple actor/effect scenes.

## 2026-06-30 Mountain generation coarse sampling pass

- Reworked mountain height scoring from a full per-cell ridge-distance sweep to
  a sampled height field with bilinear interpolation back onto the final grid.
- The generator now keeps exact ridge control shapes, but evaluates them on a
  coarser lattice for large maps and fills the in-between cells from local
  neighborhood samples.
- Added `mountain_height_sample_step` to `MapGenConfig` so large-map tuning can
  be adjusted explicitly later, while the default still auto-selects a step by
  map size.

## 2026-06-30 Connectivity packed-mask optimization pass

- Replaced several repeated dictionary-based full-map walkability scans with a
  packed-byte reachability / walkability path inside `ConnectivityService`.
- Region collection, POI reachability checks, and nearest reachable anchor
  lookup now reuse compact masks instead of re-running broad dictionary flood
  fills over the whole map.
- On the 1024x1024 single-seed probe this dropped connectivity time from about
  161s to about 23s while keeping `unreachable_poi = 0` and passing SmokeTest.

## 2026-06-30 Building placement shifts toward local terraforming

- Adjusted building placement scoring away from "only naturally perfect
  walkable footprints" toward "roughly suitable local regions plus controlled
  pattern terraforming".
- Candidate selection now scores footprint windows by conflict / forbidden
  terrain / terraform cost, while still protecting water, existing structures,
  existing POIs, and the player spawn from being overwritten.
- Kept this as a small directional shift rather than a full stamp-system
  rewrite so the current world generator remains handoff-friendly.

## 2026-06-30 Tavern density and interior blocker pass

- Tavern count now scales by world size by default instead of staying fixed at
  one copy on every map, while still allowing an explicit override through
  `MapGenConfig.tavern_count`.
- The base tavern pattern now includes a few interior blocker props using
  existing rock/statue semantics so taverns read more like real structures with
  occupied space instead of empty shells.
