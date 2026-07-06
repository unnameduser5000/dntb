# Contributing

Thanks for helping with Dungeon Arranger (`DNTB`). The project is still a prototype, so the best contributions are small, readable, and easy to verify.

## Setup

1. Install Godot 4.7 stable or a compatible 4.x version.
2. Clone the repository.
3. Open project.godot from the repository root.
4. Run the main scene or the smoke test before submitting changes.

Smoke test:

    godot --headless --path . --script res://scripts/tests/SmokeTest.gd

## Pull request guidelines

- Keep each pull request focused on one feature, fix, or refactor.
- Explain what changed and how you tested it.
- Update DEVELOP_LOG.md for notable gameplay, architecture, testing, or repository-maintenance changes.
- Prefer small service/controller extractions over growing scripts/view/Game.gd further.
- Preserve current smoke-test compatibility unless the pull request intentionally updates tests too.

## Godot file rules

- Commit source assets and their Godot sidecar metadata, including .import files and .gd.uid files.
- Do not commit .godot/, exported builds, local logs, or machine-specific export presets.
- If shared export settings become necessary, add a sanitized export_presets.example.cfg.

## Code style

- Use tabs for GDScript and Godot text resources.
- Keep functions short enough to scan.
- Prefer clear names over clever abbreviations.
- Put gameplay rules in core/runtime services when possible; keep view scripts focused on presentation and wiring.

## Reporting bugs

Use the bug report issue template and include:

- Godot version.
- Operating system.
- Steps to reproduce.
- Expected behavior and actual behavior.
- Any relevant log output.
