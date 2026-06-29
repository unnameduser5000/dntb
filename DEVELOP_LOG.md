# Develop Log

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
