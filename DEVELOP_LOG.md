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
  - _key_slots and _loose_key_tokens remain as mirrored observation fields;
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
