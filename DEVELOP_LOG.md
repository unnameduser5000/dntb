# Develop Log

## 2026-07-06 CI smoke-test timeout fix

- Symptom: every GitHub Actions `Smoke Test` run on `main` hung until manually
  cancelled after ~6 hours.
- Root cause: `scripts/view/Game.gd` referenced `BattleUI.AUTO_PAUSE`,
  `BattleUI.AUTO_PLAY`, and `BattleUI.AUTO_FAST` through the `class_name`
  global identifier. In CI the `.godot/` cache is absent, so `Game.gd` (the
  root script of `Game.tscn`) was parsed before `BattleUI.gd` was loaded and
  the `BattleUI` class name was not registered, producing a parse error. The
  smoke test then failed to call `quit()`, leaving the headless Godot process
  running forever.
- Fix:
  - Replaced the `BattleUI.*` references with local constants
    (`AUTO_ADVANCE_PAUSE`, `AUTO_ADVANCE_PLAY`, `AUTO_ADVANCE_FAST`) in
    `Game.gd`.
  - Added `godot --headless --path . --import` to `.github/workflows/smoke-test.yml`
    before the smoke-test step so CI has imported textures/audio available.
  - Added `timeout-minutes: 15` to the workflow job so any future hang fails
    fast instead of consuming the full runner quota.
- Verification: new run `28754609501` on `main` completed successfully in under
  two minutes; cancelled the backlog of stuck pre-fix runs.

## 2026-07-06 World-slice tile texture import optimization

- Follow-up to the enemy-spawn and walking stutter fixes: board renders in
  camera-follow world-slice mode still produced occasional multi-hundred
  millisecond spikes.
- Root cause: the imported world tile textures were configured with
  `process/size_limit=0`, so Godot kept them at full source resolution (up to
  2048×2048). `BoardView` scaled and cropped them at runtime, but the initial
  load/decode cost and the per-pixel POI cropping still showed up as large
  `board` spikes in `_refresh_views()`.
- Set `process/size_limit=128` in the `.import` files for all world-slice tile
  sources:
  - `art/imported/world/biomes/*.png.import` (6 files)
  - `art/imported/world/poi/*.png.import` (5 files)
  - `art/imported/world/biomes/tall_grass_generated.png.import`
  - `art/imported/world/dungeon/dungeon_concept.jpg.import`
- Deleted the old cached `.ctex` files and reimported the project with
  `godot --headless --path . --import`; the regenerated `.ctex` files are now
  ~20–35 KB each instead of several megabytes.
- Kept the runtime scaling, POI cropping cache, and render-window cap
  (`MAX_RENDER_WINDOW_CELLS_PER_AXIS = 40`) in `BoardView.gd` as a defensive
  fallback for any future large textures.
- Removed the temporary profiling prints from `BoardView._apply_cell_visual()`
  and `Game._refresh_views()`.
- Result: the remaining board-render spikes are gone; steady-state world-slice
  refreshes stay well under the frame budget and `SmokeTest` passes cleanly.

Validation:

- `godot --headless --path . --import`
- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-06 Enemy-spawn stutter fix: lazy enemy texture loading

- Investigated the stutter that occurred when enemies first became visible in
  world-slice mode.
- Root cause: `EnemyActorView._build_debug_enemy_frames()` synchronously loaded
  and processed eight large imported PNG textures for every new enemy view, even
  though only one texture was needed for the actor type. The per-pixel alpha
  boost was also applied to full-resolution images before resizing, making the
  cost proportional to the source PNG size.
- Added static texture and `SpriteFrames` caches in `EnemyActorView.gd` so each
  imported texture is loaded and fitted once per session.
- Rewrote `_texture_fitted_to_box()` to resize to the target box size before the
  per-pixel alpha pass, reducing pixel work by two orders of magnitude.
- Refactored `_build_debug_enemy_frames()` to load only the texture(s) required
  for the specific `actor_def_id`, falling back to the generic slime body only
  when necessary.
- Result: the first-time `sync_views` spike when enemies appear dropped from
  ~13 s to ~230 ms; steady-state refresh stayed around ~150 ms.
- Removed the temporary `scripts/tests/EnemyPerfProbe.gd` probe script.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-06 Hold-to-repeat movement

- Added `_process` polling in `Game.gd` so directional keys (`W/A/S/D` and
  arrow keys) repeat while held.
- Non-movement key slots still trigger only once per physical press, preserving
  the deliberate action cadence for attacks/skills.
- Uses an initial delay of 0.28 s and a repeat interval of 0.12 s, matching the
  existing world-slice fast timing feel. The repeat stops automatically when
  the key is released, the phase leaves `planning`, or UI overlays open.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-06 Walking stutter fix: board cell visual caching

- Investigated walking stutter in world-slice mode by adding timing probes to
  `Game._refresh_views()` and `BoardView.render()`.
- Root cause: every player step re-applied theme/style overrides to every
  visible board cell. In a dense camera-follow window this dominated frame time
  (hundreds of milliseconds per step).
- Added a lightweight per-Label content key in `BoardView._apply_cell_visual()`.
  If the cell's style, character, colors, and texture have not changed, the
  expensive theme override calls are skipped.
- Result: repeated refreshes dropped from ~300-400 ms to ~60 ms in the headless
  probe, with the board render portion dropping from ~250 ms to ~20 ms.
- Removed the temporary probe prints and script; kept basic timing fields on
  `GameState` for future diagnostics.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-05 Arrow-key binding migration

- Root cause of arrow keys not working: the local `user://input_bindings.cfg`
  still stored the directional actions (`player_key_up/down/left/right`) as WASD
  keycodes, overriding the new defaults every launch.
- Added `DIRECTION_ACTIONS` constant and a migration check in `load_bindings()`:
  if any directional action is bound to `KEY_W`, all four are reset to arrow keys
  and the file is resaved.
- Kept `DEFAULT_EXTRA_EVENTS` so WASD stays bound as secondary inputs for the
  directional actions.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-05 Settings menu volume sliders

- Added two volume sliders to the settings menu:
  - `音乐音量` (Music volume) controlling the `Music` audio bus.
  - `战斗音效音量` (SFX volume) controlling the `SFX` audio bus.
- Created a reusable `UiSliderRow` component (`scenes/ui/components/UiSliderRow.tscn`
  + `scripts/view/UiSliderRow.gd`) for labeled HSlider rows.
- `SettingsService` now persists `audio/music_volume` and `audio/sfx_volume` in
  `user://settings.cfg` and applies them to the audio buses on load.
- Added `music_volume_changed` and `sfx_volume_changed` signals for future UI
  reactions.
- Updated `SettingsMenu.gd` to initialize sliders from saved values and write
  changes back to `SettingsService`.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-05 Menu/backpack music ducking

- Added `AudioService.set_duck_active(active)` and `menu_duck_volume_db` export
  (default -12 dB, roughly half perceived volume) to lower music while menus or
  the backpack are open.
- Ducking is applied with the existing 1-second crossfade duration, and new
  music starts at the ducked level when ducking is active.
- Wired ducking into `App.gd`:
  - `_show_pause_menu()` / `_show_settings()` / `_show_settings_from_pause()`
    activate ducking.
  - `_resume_game()` and `_show_main_menu()` restore normal volume.
- Wired ducking into `Game.gd`:
  - `_toggle_bag()` activates ducking when the bag opens, restores when closed.
  - `_close_bag_if_open()` restores volume when closing the bag.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-05 AudioService keeps music alive during pause

- Set `AudioService.process_mode = PROCESS_MODE_ALWAYS` so music playback and
  crossfade tweens continue when the game tree is paused (e.g. backpack open).
- Pause menu itself intentionally does not stop music; only returning to the
  main menu switches to the title track.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-05 Directional keys default to WASD

- Changed the default keycodes for the independent directional actions:
  - `player_key_up`    → `KEY_W`
  - `player_key_down`  → `KEY_S`
  - `player_key_left`  → `KEY_A`
  - `player_key_right` → `KEY_D`
- Added `DEFAULT_EXTRA_EVENTS` so the original arrow keys remain bound as
  secondary inputs for the same directional actions, keeping both WASD and
  arrow keys functional.
- Updated the settings-menu labels for the directional actions to remove the
  arrow-key implication.
- Existing saved bindings in `user://input_bindings.cfg` are preserved; the new
  defaults apply to fresh installs or after resetting bindings.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-05 Title/main menu music

- Added `Pixel Dungeon` as the title/main menu music track.
- `AudioService` now exposes a `title` music key mapped to
  `res://music/Pixel Dungeon.mp3`.
- `Game._play_music_for_state()` plays the title track when the title overlay is
  visible instead of stopping music.
- `Game.return_to_title()` now crossfades to the title track so music continues
  (and loops) when returning to the main menu from in-game pause/settings.
- Updated `music/info.txt` to document the title track usage.
- Hardened `AudioService` against early calls before `_ready()` initializes the
  music players.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- `godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd`
- `godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd`

- Updated the enemy-death token flow so monster drops no longer land on the map
  as pickup items.
- When an enemy resolves a token drop, it now enters the player's spare action
  pool immediately on death.
- Kept map/world token pickup intact for ordinary world items; this change only
  affects the monster-death drop path.
- Updated the smoke test to assert that:
  - no token is left on the death cell
  - the dropped token is immediately present in the spare pool

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-05 Boss node upgraded into a large dungeon layer

- Reworked the Boss node from a small `8x8` combat room into a large dungeon
  layer that matches the world-slice map scale.
- The Boss layer now:
  - still enters through `challenge_entrance` interaction in the overworld
  - still resolves as `MAP_NODE_BOSS` in run progression
  - but internally uses a large `MapData + FOV + BoardView` state instead of the
    old small-room setup
- Current first pass content is intentionally simple:
  - a centered dungeon chamber carved out of a `256x256` map
  - structure-wall perimeter and a few pillars
  - one Boss as the main encounter target
- Kept overworld-only features out of the Boss layer:
  - no tavern edit zone
  - no POI hint sidebar
  - no streamed enemy refresh on actor movement inside the Boss dungeon
- Updated SmokeTest to verify that:
  - the Boss node now builds a large map
  - overworld interaction still enters the Boss node correctly
  - key editing remains locked

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-05 Boss entrance POI interaction

- Added a direct world-slice Boss入口交互:
  - when the player stands on a `challenge_entrance` `interaction_cell`
  - pressing confirm now enters the existing Boss node immediately
  - the transition reuses the current `MAP_NODE_BOSS` room setup instead of
    creating a separate world-boss runtime path
- Kept ruin interaction on the same POI-interaction pattern, but separated the
  test flow so Boss入口 and ruin调查 are both covered explicitly.
- Documented the current Boss-related asset placement convention:
  - enemy defs in `data/actors/`
  - boss actions in `data/actions/`
  - room layout in the existing `ROOMS` run config until a stronger need for
    standalone room data appears
  - world entrance remains the existing `challenge_entrance` POI type

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-04 Token stack pool and single-slot key mapping

- Replaced the short-lived shared-use experiment with a more direct inventory model:
  - each left-side key slot now holds at most one token
  - the right-side pool now shows stacked counts for duplicate tokens
  - dragging a token from the pool into a key slot consumes exactly one copy
- Updated the relative starter preset so it stays compatible with single-slot keys:
  - `W -> F`
  - `S -> B`
  - `A -> SL`
  - `D -> SR`
- Restored map token acquisition and first-kill reward language back to token pickup / pool semantics.
- Kept enemy-specific goblin attack actions, but removed the temporary enemy-death token-learning hook.
- Extended `SmokeTest.gd` to cover:
  - single-token-per-key behavior
  - duplicate token stacking in the pool
  - dragging from the pool decreasing stack count

## 2026-07-04 Token pickup dedupe and event goblins

- Clarified the current drop architecture:
  - `ActorDef.default_drop_key` / `ActorState.drop_key` already exist as data fields
  - but there is still no unified "enemy death -> actor-configured token drop" runtime module
  - live token acquisition still comes from map pickups and scripted rewards
- Tightened programmable token pickup semantics so the player's key-program inventory
  now treats token ids as unique unlocks:
  - duplicate map pickup of an already-owned token no longer appends another copy
  - existing tavern / ruin / first-kill rewards already align with this model
- Extended `ActorDef` with `attack_action_id` and updated `EnemyPlanner` so enemies
  can use per-definition attack actions instead of sharing one global melee attack.
- Added two low-pressure goblins for future event battles:
  - `goblin_scout`: light melee chaser
  - `goblin_slinger`: light ranged enemy using `bow_shot`
- Extended `SmokeTest.gd` to cover:
  - duplicate token pickup dedupe
  - goblin enemy lookup
  - goblin melee and ranged planner behavior

## 2026-07-04 Learned-action library and shared token uses

- Renamed player-facing token acquisition language from "pickup" toward "learn":
  - map tokens now represent learning a move
  - enemy-configured token drops now resolve as learning from that enemy
- Reframed the right-side bag panel from an expendable spare pool into a learned-action library:
  - dragging a token from the right side into a key slot no longer removes the source entry
  - dragging from a key slot back to the right side still clears that slot position
- Added shared per-token use limits:
  - each token id now has a max use count
  - counts are shared across every slot copy of the same token id
  - counts reset when entering a new room, rest node, or fresh world-slice state
- Added initial enemy-learning examples:
  - `goblin_scout` teaches `SL`
  - `goblin_slinger` teaches `BW`
- Updated bag UI copy and token cards so remaining uses are visible in both the key slots and the learned-action library.
- Extended `SmokeTest.gd` to cover:
  - right-side library drag no longer removing the source token
  - token-use consumption on execution
  - goblin death teaching its configured token

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

## 2026-07-04 Expanded action tokens and level-up modifier pool

- Added two new concrete action tokens:
  - `HK -> hook_pull`
  - `SB -> shield_bash`
- Added three more concrete heavy-attack tokens:
  - `HM -> hammer_smash`
  - `RA -> spin_axe`
  - `PI -> pierce_line`
- `hook_pull` now hits the first enemy within two cells in front and pulls it
  one cell closer.
- `shield_bash` now deals front-cell melee damage and applies one tile of
  knockback through the shared impact pipeline.
- `hammer_smash` now covers the forward `2x3` area.
- `spin_axe` now covers the surrounding `3x3` ring.
- `pierce_line` now hits the forward `1x4` line.
- Expanded the level-up permanent-buff pool from a fixed three-item set to a
  larger modifier roster with rotation over already-owned buffs.
- Added three new permanent modifiers:
  - `长弦校准`：ranged damage +50%
  - `收割回生`：heal 1 on kill
  - `追电步`：moving with a directional action zaps the enemy directly ahead
- Added five more permanent modifiers to make level-up builds less repetitive:
  - `锋刃校准`：all attack damage +50%
  - `壁垒猛进`：shield-bash / hammer-smash damage +50%
  - `枪锋专注`：charge-thrust / pierce-line damage +50%
  - `回旋怒潮`：spin-axe / great-sweep damage +50%
  - `战意回护`：gain guard after dealing attack damage
- Extended SmokeTest coverage for the new token mappings, runtime effects, and
  modifier behaviors.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`
- Result: `SmokeTest passed`

## 2026-07-04 Autopath startup guard when enemies are already visible

- Reintroduced the startup guard for world-slice autopath.
- Clicking `Boss遗迹` / `最近安全区` / `最近小遗迹` now refuses to start
  auto movement if a visible enemy is already on screen.
- Removed the `_world_autopath_ignore_enemy` bypass so the same visibility rule
  applies both before the run starts and while it is advancing step by step.
- Added a SmokeTest regression that clicks a POI while an enemy is visible and
  verifies that autopath does not start, consume a turn, or move the player.
- Updated the design and test docs so the rule is explicit:
  - startup requires no visible enemy
  - first visible enemy pauses autopath
  - player damage stops autopath

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`

## 2026-07-04 Autopath resume on enemy sight, stop on damage

- Removed the hard refusal to start autopath when enemies are visible.
- When autopath pauses because an enemy enters sight, the player can click the
  same destination again to resume movement.
- Autopath now stops permanently only when the player takes damage.
- Added `_on_actor_damaged()` handler connected to `resolver.actor_damaged` to
  detect player damage and stop autopath immediately.
- Updated the pause message to tell the player that clicking the target resumes
  autopath.
- Fix: clicking the destination while enemies were visible did not resume
  autopath because `_start_world_autopath()` returned early both when an enemy
  was visible and when the same target was already active. Added the
  `_world_autopath_ignore_enemy` flag so a run started while an enemy is already
  in view continues until damage; a run started with no visible enemy still
  pauses on first enemy sight.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`
- `godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd`
- Result: `ActorPresentationSandbox smoke passed`
- `godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd`
- Result: `BattleEffectSandbox smoke passed`

## 2026-07-04 World autopath A* performance fix

- Replaced the naive A* open-list sort in `Game._find_world_autopath_path()`
  with a dedicated binary min-heap (`_AStarHeap`).
- Removed per-iteration `Array.sort_custom()` and linear `Array.has()` checks,
  both of which scaled poorly on the 256×256 world slice.
- Added a `closed` set so already-processed nodes are skipped immediately
  instead of being re-examined through stale heap entries.
- Time complexity per step dropped from O(n log n) sort + O(n) membership scan
  to O(log n) heap push/pop.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`
- `godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd`
- Result: `ActorPresentationSandbox smoke passed`
- `godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd`
- Result: `BattleEffectSandbox smoke passed`

## 2026-07-04 Independent arrow-key movement bindings

- Added four new independent player input actions:
  - `player_key_up`
  - `player_key_down`
  - `player_key_left`
  - `player_key_right`
- These actions default to the arrow keys (`↑ / ↓ / ← / →`) and are
  programmatically mapped to the same physical key slots as WASD:
  - Up → `W` slot
  - Down → `S` slot
  - Left → `A` slot
  - Right → `D` slot
- `PlayerInputService.PROGRAM_ACTIONS` now includes the new actions, so they
  appear as separate rebindable rows in `SettingsMenu`.
- `DIRECTIONS` now covers all movement actions, preserving existing direction
  resolution behavior.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`
- `godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd`
- Result: `ActorPresentationSandbox smoke passed`
- `godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd`
- Result: `BattleEffectSandbox smoke passed`

## 2026-07-04 Hide game view during start-game loading

- Changed `App._start_new_game()` to keep the game scene hidden while the world
  is being generated, so only `AppBackground` and the loading overlay are
  visible during the prompt.
- `Game.start_world_slice_debug()` now reveals the game view only after the
  world state is ready and right before the loading overlay is hidden.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`
- `godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd`
- Result: `ActorPresentationSandbox smoke passed`
- `godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd`
- Result: `BattleEffectSandbox smoke passed`

## 2026-07-04 Settings key rebind scroll preservation

- Added optional `scroll_to_top` parameter to `SettingsMenu.refresh_controls()`.
- Preserved scroll position while toggling rebind mode, rebinding, resetting
  bindings, or hiding the menu; only reset scroll when the menu is first opened.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`
- `godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd`
- Result: `ActorPresentationSandbox smoke passed`
- `godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd`
- Result: `BattleEffectSandbox smoke passed`

## 2026-07-04 Added complete system API documentation for PR handoff

- Added `docs/06_系统API清单.md` as a dedicated API-facing handoff doc.
- Documented the current branch's expanded systems by API boundary instead of
  only by design intent, including:
  - programmable token storage and resolution
  - action execution
  - enemy planning
  - world-slice POI guidance and ruin interaction
  - XP / level-up reward loop
  - BattleUI / BattleHud / RunSidebar UI responsibilities
- Updated `docs/README.md` to index that new API doc.

## 2026-07-03 Added first-kill attack-token and level-up reward loop

- Changed the first four-direction reward into a real programmable attack-token
  flow instead of a weapon pickup flow:
  - the first kill now grants the `十字刃` attack token
  - that token is auto-collected into the spare/pool inventory
  - the player still decides later which physical key slot should carry it
- Removed the stale `cross_blade` reward-chain dependency so the live first-kill
  flow now only depends on `CA -> cross_attack`.
- Renamed the player-facing `cross_attack` display text to `十字刃` so token,
  action UI, and design docs no longer split between `十字斩` and `十字刃`.
- Added a minimal XP and level system:
  - enemy kills grant `1 XP`
  - current level threshold is `level * 2`
  - BattleHud now shows both an XP bar and `等级 Lv.X · 经验 Y/Z`
- Added level-up benefits and reward choice:
  - level-up immediately increases max HP by `1`
  - level-up restores `1` HP
  - level-up opens an `升级选择` reward overlay with three permanent modifier
    choices
- Kept the implementation on top of the existing modifier reward path so level-up
  rewards and room rewards still converge through the same permanent-buff system.

## 2026-07-03 Prevented enemies from entering the tavern safe zone

- Updated world-slice enemy spawn selection so both the initial enemy batch and
  later streamed reinforcements now hard-exclude tavern safe-area walkable
  cells.
- Extended `SmokeTest.gd` to verify that no initial or streamed enemy spawns
  inside the tavern footprint rest area.

## 2026-07-03 First batch prototype: side-step token, light weapon, line enemy

- Added `SL / SR` as real programmable tokens instead of keeping them only as
  trace semantics.
- Added `step_left.tres` and `step_right.tres`, and wired them through:
  - `ActionProgramController.gd`
  - `DirectionalTechniqueResolver.gd`
  - `ActionResolver.gd`
  - `ActionPreviewService.gd`
  - `BagUI.gd`
- Kept the first-pass side-step rule intentionally narrow:
  - move one tile relative to current facing
  - do not rotate the actor
- Added `twin_daggers.tres` as the first light-weapon prototype for the
  side-step batch.
- Added `line_warden.tres` plus `line_keeper` enemy AI as the first straight-line
  pressure enemy prototype.
- Follow-up doc pass:
  - clarified that future action/token content should primarily come from map
    drops plus limited teaching rewards;
  - clarified that future weapons should primarily come from relic/ruin/chest or
    room-level reward choices instead of common map drops.
- Extended `SmokeTest.gd` to cover:
  - `SL / SR` token legality and plan mapping
  - `SL` preview and actual execution
  - `line_keeper` straight-line advance behavior
- Added the first world-slice ruin interaction loop:
  - sidebar/debug text now points to `Boss遗迹` and the nearest small ruin
  - the normal right-bottom sidebar now also shows those two direction hints
  - once the player gets close enough to a ruin, the small-ruin hint upgrades to
    `附近可调查`
  - clicking either hint now starts a minimal A*-based autopath toward that POI
  - autopath now switches to a dedicated presentation timing profile and only
    advances when the previous action's animation cycle has elapsed
  - autopath pauses immediately when a visible enemy enters the player's sight
  - standing on a ruin interaction cell and pressing confirm investigates it
  - first-pass ruin rewards grant `SL / SR` into the spare token pool
  - ruin claims are stored so the same ruin cannot be farmed repeatedly

## 2026-07-03 Clarified monster and token expansion direction docs

- Updated `docs/01_系统设计文档.md` to make the current monster boundary,
  token acquisition paths, and next-step content direction more explicit.
- Updated `docs/04_键位扩展清单.md` so token expansion is now documented
  together with the kind of enemy pressure each new token should justify.
- Added a clearer “next-step plan summary” to those docs so actions, weapons,
  and monsters are now grouped into concrete rollout batches instead of only
  being listed as separate recommendations.
- Updated `docs/03_测试与验证.md` to reflect the fixed tavern starter layout
  and the current “first talk grants attack token into pool” onboarding flow.

## 2026-07-03 Tavern keeper starter attack token gift

- Kept `rusty_sword.tres` available as data, but changed the actual starter
  reward flow to match the key-program system more closely.
- Hooked the world-slice tavern interaction flow so the spawn tavern keeper now
  grants the generic attack token on the first successful conversation:
  - reward is driven inside `Game._try_interact_with_world_npc()`
  - the token is added to the spare/pool inventory instead of being forced into
    a key slot
  - follow-up dialogue/message now tells the player to open the bag and assign
    that token to a physical key before leaving
- Persisted `world_npc_interaction_counts` in run save data so reloads do not
  re-trigger the first-talk gift.
- Extended smoke coverage to verify the first tavern-keeper dialogue adds the
  attack token to the spare pool and records the one-time interaction count in
  save payloads.
- Follow-up stability pass:
  - fixed the spawn tavern pattern orientation instead of letting that first
    safe-zone layout rotate or mirror
  - pinned the player spawn to a fixed local tavern floor cell
  - pinned the tavern keeper to a fixed adjacent starter cell next to the
    player spawn
  - auto-faced the player toward the tavern keeper on world-slice start so the
    opening sword interaction is always immediately reachable

## 2026-07-04 Settings menu resume/back buttons

- Renamed the settings-menu back button from `返回主菜单` to `返回`.
- Added a `继续游戏` button above the back button in `SettingsMenu`.
- `SettingsMenu` now emits `continue_requested` when the continue button is pressed.
- `App.gd` wires `continue_requested` to resume the active game if a run is in
  progress, or fall back to the main menu otherwise.
- The continue button is now hidden when the settings menu is opened from the
  main menu, and only shown when it is opened from the pause menu during an
  active game.
- Back-button behavior remains unchanged: it returns to the pause menu when
  settings was opened from pause, otherwise to the main menu.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`
- `godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd`
- Result: `ActorPresentationSandbox smoke passed`
- `godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd`
- Result: `BattleEffectSandbox smoke passed`

## 2026-07-04 World-slice map zoom setting

- Added a "地图缩放" option to the settings menu with four fixed levels:
  `1.0x / 1.5x / 2.0x / 4.0x`.
- `SettingsService` now persists `gameplay.world_slice_zoom_index` and emits
  `world_slice_zoom_changed` when the value changes.
- `SettingsMenu` populates the dropdown from `WORLD_SLICE_ZOOM_OPTIONS` and
  forwards selection to `SettingsService`.
- `BoardView` applies the zoom multiplier to the world-slice base `cell_size`
  and re-renders immediately when the setting changes.
- Added `BoardView.center_world_slice_camera_on_player()` so `Game.gd` and the
  zoom-change handler both use the same camera-position logic; zoom changes now
  recenter the camera immediately before re-rendering.
- Zoomed cell size is clamped to a separate range
  (`world_slice_min_zoom_cell_size` / `world_slice_max_zoom_cell_size`) so the
  higher magnification levels are not capped by the default 1× layout bounds.
- Scope is limited to world-slice camera-follow mode; traditional 8×8 rooms
  and the legacy manual pan/zoom mode are unaffected.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`
- `godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd`
- Result: `ActorPresentationSandbox smoke passed`
- `godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd`
- Result: `BattleEffectSandbox smoke passed`

## 2026-07-04 Camera2D-centered world-slice map

- Switched the world-slice view from a virtual pan/zoom camera to a real
  `Camera2D` that follows the player:
  - `Camera2D` is now a top-level node under `Game` and is treated as the
    source of truth for which world-pixel coordinate belongs at the viewport
    center.
  - `BoardView` reads `Camera2D.position` and renders only the grid cells that
    cover the current viewport plus a small margin, so the map tiles fill the
    rectangular window and adapts to window size.
  - The player is kept centered on screen by setting the camera position to
    the player's world-pixel center every refresh.
- Added `BoardView.world_slice_camera_follow` toggle and
  `world_slice_render_margin_cells` for the viewport-filling render window.
- Mouse drag/wheel input is disabled while camera-follow is active because the
  camera now tracks the player automatically.
- Preserved the previous pan/zoom behavior behind `world_slice_camera_follow =
  false` and `enable_pan_zoom` so the old mode can still be enabled if needed.
- `ActorRoot` / `EffectRoot` transform sync continues to work; with
  camera-follow scale locked to 1, overlays are placed directly in screen space
  via `grid_to_world()`.
- Fix for gray screen / missing map:
  - Keep the `Camera2D` node disabled for rendering; because `BoardView` is a
    `Control`, an enabled `Camera2D` scrolls the canvas and moves the board
    off-screen. We only use `Camera2D.position` as a data marker.
  - Compute the render window before computing `BoardView.position`, and use
    the clamped render-window origin so the grid aligns exactly with the
    camera center even at world edges.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`
- `godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd`
- Result: `ActorPresentationSandbox smoke passed`
- `godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd`
- Result: `BattleEffectSandbox smoke passed`

## 2026-07-03 Fullscreen draggable/zoomable world-slice map

- Reworked world-slice map layout so it now fills the full viewport instead of
  reserving a fixed right-side panel area for `BattlePanel`.
- Implemented a virtual camera inside `BoardView`:
  - panning by holding the left mouse button and dragging;
  - zooming with the mouse wheel, zooming toward the cursor position;
  - clamped offset and zoom range so the board cannot be dragged completely
    off-screen or zoomed to an unusable level.
- Kept `BattleUI` in its existing `CanvasLayer`, so buttons, sidebars, and the
  backpack stay above the map and consume input first.
- Synchronized `ActorRoot` and `EffectRoot` transforms with `BoardView` in
  `Game._refresh_views()` so actor sprites and battle effects move/scale with
  the map without changing their coordinate semantics.
- Added a `Home` key shortcut to reset the camera to the default centered,
  zoom-1 view while in world-slice mode.
- Scope is intentionally limited to world-slice mode; traditional 8x8 rooms
  keep their fixed origin and scale and do not respond to drag or wheel input.
- Added `BoardView.reset_camera()` / `set_camera_offset()` / `set_camera_zoom()`
  so other systems can programmatically reset or animate the view.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`
- `godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd`
- Result: `SmokeTest passed`
- `godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd`
- Result: `SmokeTest passed`
>>>>>>> main

## 2026-07-02 Safe-zone NPC interaction pass

- Added a lightweight world-slice NPC interaction layer anchored to tavern
  safe zones instead of scattering neutral actors across the full generated
  map.
- Introduced `NpcDef.gd` plus two first-pass tavern residents:
  - `酒馆掌柜`
  - `旧路巡记员`
- Added the first world-slice interaction service layer; this later evolved into
  the current actor-based interaction path:
  - player uses `ui_accept` / 确认键
  - service resolves a nearby safe-zone resident
  - output lands in `GameState.messages`
- Updated `WorldSliceController.gd` so NPC spawn selection is derived from the
  stamped tavern footprint that contains the player spawn:
  - NPC candidates come from tavern `occupied_cells`
  - only walkable tavern-floor / yard cells are considered
  - occupied spawn, interaction, and reserved cells are excluded
  - result stays constrained to the safe area by construction
- Kept the existing world placeholder prop and enemy streaming flow intact;
  this pass only adds tavern-local neutral residents and interaction text.
- Documented the current building-generation chain more explicitly as:
  - anchor picking in `POIPlacementService.gd`
  - staged local/global candidate search in `BuildingPlacementService.gd`
  - final footprint stamping in `PatternStampService.gd`
- Follow-up pass:
  - moved NPC eligibility into tavern pattern data via `npc_spawn_slots`
  - kept the first live strategy intentionally narrow: only the player-spawn
    tavern generates one `tavern_keeper`
  - added runtime tracking fields for:
    - NPC world coordinates
    - tracked NPC id
    - relative-direction hint text
    - display-toggle bool
  - world-slice interaction was initially wired to `F` as a direct shortcut;
    later passes moved it into a real `interact` token on the physical `F`
    key slot instead of keeping the old direct-trigger path
  - added a dedicated bottom-center dialogue panel in `BattleUI` for world-slice
    NPC interaction:
    - initial live NPC is the `K` glyph tavern keeper
    - a dedicated dialogue panel was added first, then later simplified so each
      interaction only shows one line and the panel closes on any key press
    - while the panel is open, world-slice action submission is frozen so the
      next enemy turn cannot begin before the interaction ends
  - follow-up fix:
    - world-slice NPC interaction now submits a dedicated `interact` action
      through `TurnController` / `ActionResolver` instead of only calling the
      service directly from `Game.gd`
    - tavern NPC spawn candidates now hard-exclude entrance cells and their
      immediate doorway corridor, preventing the initial NPC from blocking the
      tavern exit
  - actor-system unification pass:
    - promoted interaction capability fields from `NpcDef` into `ActorDef`
    - added `ActorInteractionService.gd` as the main interaction service
    - kept `NpcInteractionService.gd` only as a compatibility shell
    - added a `talkative_slime` sample actor to prove monsters can use the same
      interaction capability pipeline
    - validated that tavern NPCs can still be damaged and killed through the
      same actor combat rules as monsters
  - interaction UX + spawn follow-up:
    - world-slice dialogue panel now shows one line at a time and closes on
      any key press instead of paging through lines with `F`
    - tavern interactable actor spawn scoring now prefers wall-adjacent cells,
      while still hard-avoiding doors and doorway corridors
    - documented the current world-slice enemy generation model: initial spawn
      pass plus distance-based streamed refill/despawn
    - `interact` target resolution is now constrained to the actor standing in
      front of the player, instead of any adjacent actor

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`

## 2026-07-02 World-slice tavern editability bug fix

- Fixed the world-slice backpack editor so it no longer unlocks only on a
  narrow subset of tavern tiles.
- The previous check only accepted tavern cells tagged as:
  - `building_floor`
  - `building_door`
  - `building_open_ground`
  which incorrectly relocked the bag when the player stood on the tavern's
  walkable interaction tile.
- The new check treats any walkable cell inside the tavern footprint as a
  valid safe editing area, as long as the cell still carries tavern-related
  structure tags.
- Updated the smoke test helper so world-slice editability assertions now also
  cover a tavern interactable tile.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`

## 2026-07-02 Bag drag-drop hitbox tolerance pass

- Relaxed bag drag-and-drop targeting so slot assignment no longer requires
  overly precise placement.
- The previous interaction issue came from child controls inside a key slot
  intercepting the drop:
  - dropping onto an occupied token did not count as dropping onto its slot;
  - dropping onto an empty placeholder cell could be swallowed before the
    parent slot received the event.
- Updated the bag UI so:
  - dropping onto an existing token now routes to that token's slot/pool;
  - empty placeholder cells ignore pointer hit-testing for drop handling, so
    the parent slot panel can accept the drop more reliably.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`

## 2026-07-02 Locked-slot visual error feedback pass

- Added explicit visual feedback for backpack key slots when the player tries
  to rearrange bindings while editing is locked.
- Locked interaction now flashes the touched key slot red instead of failing
  silently, which makes the "not editable here" state much clearer during
  battle or outside tavern safe tiles.
- Also updated the world-slice smoke helper so its manual player relocation
  path explicitly recomputes visibility/events through the world controller
  after the tavern safe-area footprint was widened.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`

## 2026-07-02 BagUI fixed-grid layout and tooltip fallback pass

- Reworked the backpack layout away from content-driven stretch sizing, which
  had started to break once the token set and per-key chains grew.
- Follow-up fix on `hotfix-bagUI`:
  - clamped each left-side physical key card to `2` visible token slots by
    default so the first stable layout does not overgrow again before per-key
    tuning is in place;
  - made the left-side key grid and its scroll region advertise an explicit
    minimum width/height so Godot no longer collapses the key cards into a
    narrow center strip when the right inventory panel claims space.
  - fixed the actual left-panel refresh blocker: `BagUI.gd` had been looking
    up `KeyGrid` and `BuffsList` as direct children of `LeftPanel`, but both
    live one level deeper under scroll containers, so the left slot area had
    silently stopped rebuilding at runtime.
- Bag UI changes:
  - right-side spare-token inventory now renders as a fixed-grid multi-row
    panel with configurable column count;
  - each left-side physical key panel now renders a configurable number of
    fixed token slots instead of a single endlessly growing row;
  - permanent buffs now live in a fixed-height scroll region instead of
    pushing the rest of the bag layout around.
- Extended token hover so each token now shows a short gameplay summary in the
  bag UI.
- Current limitation:
  - the hover summary still uses a UI-local fallback map because `ActionDef`
    does not yet expose a unified description / tooltip field.

Validation:

- `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`
- Result: `SmokeTest passed`

## 2026-07-02 CI smoke stabilization on cjy branch

- Replaced the direct `DialogueManager` autoload with a project-local CI-safe
  wrapper so headless smoke no longer compiles the third-party runtime plugin
  graph on this branch.
- Updated `DialogueService.gd` to query the wrapper's runtime availability
  instead of assuming the plugin autoload means the runtime is usable.
- Trimmed and rewritten outdated `SmokeTest.gd` sections that still depended on
  the removed weapon hook / combo architecture:
  - removed `supports_technique` assertions
  - removed combo lab / combo preview / combo follow-up expectations
  - updated token-pool expectations to match the current programmable token set
  - updated pool drag logic so tests no longer assume a fixed pool order

Validation notes:

- Did not run Godot locally in this pass.
- Used the CI failure log plus static cross-checks to remove the identified
  blocking references and parse-time dependencies.

## 2026-07-02 Weapon model rewritten into action API

- Rewrote the live weapon model away from `WeaponDef hook + combo technique`
  and into a simpler action-owned model:
  - one weapon corresponds to one attack action
  - the generic attack token now resolves to the equipped weapon's
    `attack_action`
- Simplified `WeaponDef.gd` into a thin data resource with:
  - `id`
  - `display_name`
  - `description`
  - `attack_action`
- Reconfigured the current three weapons:
  - `impact_shield` -> `attack`
  - `iron_spear` -> `charge_thrust`
  - `greatblade` -> `great_sweep`
- Removed the old combo/hook model from the main gameplay path:
  - `DirectionalTechniqueResolver.gd` now chooses weapon attack actions during
    plan build
  - `TurnController.gd` no longer executes weapon combo follow-up actions
  - `ActionPreviewService.gd` no longer predicts combo techniques
  - `ActionResolver.gd` no longer calls weapon hit/miss/collision hooks
  - `RunSidebar.gd` and `Game.gd` inventory/debug output now show weapon +
    attack action instead of weapon techniques
- Removed old run-state persistence for unlocked weapon techniques.
- Deleted the old deprecated weapon-side API artifacts that were no longer on
  the main gameplay path:
  - `scripts/data/WeaponTechniqueDef.gd`
  - `data/weapon_techniques/*`
  - `scripts/runtime/CombatContext.gd`
  - `scripts/tests/ProbeWeaponDef.gd`
- Rewrote collaboration and API checklist docs so they now describe the live
  `weapon -> attack_action -> ActionResolver` model instead of the removed
  combo / hook architecture.

Validation notes:

- Did not run `SmokeTest.gd` in this pass.
- Used static checks instead:
  - verified `A` token can resolve through `DirectionalTechniqueResolver` to
    `active_weapon.attack_action`
  - verified room/rest/player equip flow still assigns `active_weapon`
  - verified turn execution no longer references combo follow-up resolution
  - verified save/load still persists `run_weapon_id`

## 2026-07-02 Removed temporary in-game testing flow

- Removed the temporary run-start testing flow that had been added only for
  manual in-game verification:
  - no more forced opening weapon-selection reward gate
  - no more auto-seeded starter pool of extra base-action test tokens
- Rest-site copy was cleaned back to normal run-facing wording instead of
  explicit "test here" guidance.

Validation notes:

- Did not run `SmokeTest.gd` in this cleanup pass.
- Used static checks instead:
  - verified `Game.gd` no longer references `start_weapon_select`
  - verified `_setup_default_key_slots()` no longer injects extra test tokens
  - verified reward flow falls back to the normal map-advance path again

## 2026-07-02 Attack result-layer pass

- Added `scripts/runtime/AttackResult.gd` so attack execution now has a
  project-owned runtime result shape alongside `MovementResult.gd`.
- Refactored `ActionResolver.gd` so:
  - `_resolve_attack()` builds and returns an `AttackResult`
  - `_resolve_lunge()` builds and returns an `AttackResult`
- The new attack result currently records:
  - attempted cells
  - hit targets
  - hit cells
  - produced damage packets
  - miss cell
  - whether a weapon hook handled the hit
  - whether the attack also moved the actor, as in miss-then-lunge movement
- This does not yet mean move and attack are fully unified under one generic
  action-result API, but it removes the biggest asymmetry in the current
  execution layer.

Validation notes:

- Did not run `SmokeTest.gd` in this pass.
- Used static checks instead:
  - verified normal `attack` and `lunge` now both instantiate `AttackResult`
  - verified weapon hit/miss hooks still execute on the same code path
  - verified no existing callers depend on `_resolve_attack()` returning `void`

## 2026-07-02 Key-program boundary regression to design doc

- Re-aligned the programmable key system with the documented core fantasy:
  editable key slots now represent base actions, not only direction input.
- Expanded `ActionProgramController.gd` legal token set to include:
  - `B`
  - `A`
  - `G`
  - `W`
  - `J`
  while keeping `U / D / L / R / F / TL / TR`.
- Expanded `DirectionalTechniqueResolver.gd` so key-slot execution can now
  translate:
  - movement tokens
  - turn tokens
  - attack
  - guard
  - wait
  - jump
  into runtime base actions on the same path.
- Kept weapon techniques out of the key-token layer:
  - weapon combos still trigger later from real `ActionTrace`
  - `lunge` / `sweep` / `charge_thrust` / `great_sweep` remain follow-up
    payoffs instead of draggable direct tokens
- Seeded the starter unassigned-token pool with the now-implemented base action
  tokens so opening-camp testing no longer depends on reward flow before the
  player can verify attack/guard/wait/jump/backstep chains.
- Corrected documentation drift in:
  - `docs/01_系统设计文档.md`
  - `docs/04_键位扩展清单.md`
  - inline notes in `Game.gd`

Validation notes:

- Did not run `SmokeTest.gd` in this pass because repeated local smoke runs are
  known unstable in the current environment and the user explicitly asked not
  to use that route.
- Used static cross-checks instead:
  - verified corresponding `ActionDef` resources already exist for `move_back`,
    `attack`, `guard`, `wait`, and `jump`
  - verified `Game.gd` already registers those action ids in `_action_by_id`
  - verified the key-program pool/UI path consumes generic token ids without a
    separate direction-only assumption
  - verified weapon-combo follow-up flow still remains outside the token layer

## 2026-07-02 Movement API consolidation pass

- Started treating movement as a first-class runtime API instead of leaving it
  only as scattered `ActionResolver` helper behavior.
- Added `scripts/runtime/MovementResult.gd` as the shared result shape for:
  - basic move-to-cell
  - forced directional movement
  - swap
  - teleport
- Refactored `ActionResolver.gd` movement helpers so the internal authoritative
  path now goes through:
  - `resolve_move_actor_to_cell()`
  - `resolve_forced_directional_move()`
  - `resolve_swap_actors()`
  - `resolve_teleport_actor()`
  while keeping the older `try_*` helpers as compatibility wrappers.
- Kept presentation and signal emission centralized around these movement
  result objects, so later movement semantics do not need to hand-roll their
  own emit logic again.
- Rewrote the API checklist docs to state explicitly that movement should be
  treated as its own layer alongside weapon, effect, and presentation APIs.

Validation notes:

- Did not run `SmokeTest.gd` in this pass for the same local-stability reason
  already noted above.
- Used static checks instead:
  - verified `EffectPipeline.gd` still calls the existing `try_*` movement
    entry points, so the refactor remains source-compatible
  - verified swap / teleport presentation hooks still receive the same payload
    fields from `ActionResolver.gd`
  - verified `actor_moved` signal emission remains on the authoritative move
    path rather than being duplicated at callsites

## 2026-07-02 High-fit weapon pass

- Added two new combo-first weapons that fit the current `ActionTrace ->
  WeaponTechniqueDef -> follow-up ActionDef` path without reopening the combat
  architecture:
  - `iron_spear`
    - reuses `lunge`
    - adds `charge_thrust` from three consecutive same-direction moves
  - `greatblade`
    - adds mirrored heavy sweep techniques from `TL -> TR` and `TR -> TL`
- Added new follow-up action resources:
  - `charge_thrust`
  - `great_sweep`
- Updated both runtime and preview attack-shape logic so `great_sweep` uses the
  same three-cell sweep footprint as `sweep`, while keeping its own damage
  tuning.
- Added run-level weapon ownership instead of keeping the player's weapon fixed
  to the actor definition for the whole run:
  - `Game.gd` now tracks `run_weapon_id`
  - room/rest state creation now re-equips the current run weapon
  - save/load now persists the current run weapon id
- Added weapon-swap rewards for later combat rewards:
  - `更换武器：铁枪`
  - `更换武器：巨剑`
- Updated sidebar debug output so non-world-slice weapon technique lists are no
  longer hardcoded to only `lunge` / `sweep`, and now read the equipped
  weapon's real `combo_techniques`.

Validation notes:

- Did not use `SmokeTest.gd` in this pass because repeated local smoke runs are
  unstable in the current environment.
- Used static cross-checks instead:
  - verified new actions are registered in `Game.gd`
  - verified new weapon technique ids are registered in `Game.gd`
  - verified room/rest state creation re-equips the current run weapon
  - verified reward flow writes `equip_weapon` into `_apply_reward()`
  - verified save/load reads and writes `run_weapon_id`
  - verified both runtime and preview recognize `great_sweep`

## 2026-06-30 Bag pause-and-bind pass

- Reworked the backpack page into the live key-program editor/viewer for the
  current twelve physical slots: `QWER / ASDF / ZXCV`.
- The bag can now be opened either from the on-screen `背包 / Tab` button or by
  pressing `Tab` during active play, and opening it now pauses the scene tree
  until the bag is closed.
- Kept battle-area key programs locked, while camp/rest/tavern-safe areas still
  allow drag-and-drop editing.
- Clarified the bag UI so players can read:
  - current slot binding labels
  - left-to-right trigger order inside the same key slot
  - unassigned pool tokens on the right
  - permanent buff names with hover detail tooltips
- Fixed `BattleUI.set_permanent_buffs()` so permanent-buff updates refresh the
  bag immediately instead of waiting for the next full key-program refresh.

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

## 2026-06-30 Default startup switches to world slice

- Default play now enters the world-slice path instead of the old room-chain
  demo flow.
- The world-slice sandbox default size is now 256x256 so the first playable
  entry matches the larger-map work better.

## 2026-07-04 Attack token and weapon API rollback

- Fixed the `A` token back to a concrete `attack` action instead of resolving
  through `active_weapon.attack_action`.
- Removed run-time weapon swap state from the main combat loop, reward flow,
  debug/sidebar text, and save payload.
- Updated the current design/docs to treat future weapon-flavored content as
  dedicated tokens plus `ActionDef`, rather than as "change current weapon"
  APIs.

## 2026-07-04 Passive regen accumulation

- Added run-level passive healing progress:
  - base regen starts at `0.5` per non-rest turn
  - only whole points convert into actual HP recovery
  - full HP no longer banks regen progress
- Regen rate now scales slowly with level at `+0.05` per level.
- SmokeTest now covers both the two-turn `+1 HP` conversion and the higher
  level regen-rate increase.

## 2026-07-04 First batch of expanded action tokens

- Added the first new token batch to the editable key-program layer:
  - `DS -> dash`
  - `TH -> charge_thrust`
  - `SW -> great_sweep`
  - `BW -> bow_shot`
- `Dash` reuses the existing multi-step move path and is excluded from normal
  movement momentum stacking.
- `bow_shot` is a first-pass ranged action that hits the nearest enemy in front
  along a clear line, without introducing a full projectile runtime yet.
- SmokeTest now covers token legality, plan mapping, dash movement, and bow
  targeting behavior.
