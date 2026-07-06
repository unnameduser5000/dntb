# 地牢编排师（DNTB）

Dungeon Arranger (`DNTB`) is a Godot 4 tactical roguelite prototype about programmable direction keys, derived weapon techniques, grid combat, relic-like modifiers, and short run progression.

The project is early-stage and intentionally small. The current focus is keeping gameplay systems easy to inspect, test, and refactor.

## Requirements

- Godot 4.7 stable or newer compatible 4.x build.
- Git for collaboration.

## Getting started

1. Clone the repository.
2. Open project.godot in Godot.
3. Run the main scene at scenes/game/App.tscn.

From a terminal with Godot on PATH:

    godot --path .

## Running tests

The project includes a headless smoke test scene tree script:

    godot --headless --path . --script res://scripts/tests/SmokeTest.gd

This test covers the current combat loop, programmable key slots, world-slice onboarding, POI hints and ruin interaction, first-kill attack-token reward, XP/level-up progression, rewards, modifiers, and achievement events.

## Repository layout

- addons/ - third-party Godot addons. Dialogue Manager keeps its own license.
- art/ - project art notes and future art assets.
- audio/ - future audio assets.
- data/ - Godot resources for actors, actions, technique patterns, modifiers, rewards, and achievements.
- scenes/ - Godot scenes.
- scripts/core/ - gameplay services and runtime controllers.
- scripts/data/ - Resource classes and data definitions.
- scripts/runtime/ - turn/action/effect runtime state.
- scripts/tests/ - headless smoke tests and test helpers.
- scripts/view/ - UI and scene-facing presentation scripts.
- DEVELOP_LOG.md - working development log for notable changes and refactor notes.

## Collaboration

Please read CONTRIBUTING.md before opening a pull request. In short:

- Keep pull requests focused.
- Run the smoke test when possible.
- Do not commit .godot caches, exported builds, local logs, or secrets.
- Keep Godot .gd.uid and .import sidecar metadata when Godot generates them for tracked resources.
- Update DEVELOP_LOG.md for notable gameplay, architecture, or repository-process changes.

## License

This repository is released under the Apache License 2.0 unless a file states otherwise. See LICENSE.

Third-party code under addons/ may carry its own license; keep those notices intact.
