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
