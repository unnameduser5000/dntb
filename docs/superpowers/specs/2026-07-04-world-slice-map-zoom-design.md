# Design: Settings-Based World-Slice Map Zoom

## Goal

Add a "Map Zoom" option to the in-game settings menu. It offers five fixed
magnification levels (`0.5x / 1x / 1.5x / 2x / 4x`), applies only to the
world-slice map mode, takes effect immediately, and persists across restarts.

## Scope

- Affects only `state.is_world_slice == true` rendering in `BoardView`.
- Traditional 8×8 rooms keep their existing fixed `cell_size` and layout.
- The setting is stored alongside display settings in `user://settings.cfg`.

## Architecture

### 1. SettingsService (`scripts/core/SettingsService.gd`)

New constants and state:

```gdscript
const WORLD_SLICE_ZOOM_OPTIONS := [0.5, 1.0, 1.5, 2.0, 4.0]

var world_slice_zoom_index := 1
```

New public API:

```gdscript
func set_world_slice_zoom_index(index: int) -> void
func get_world_slice_zoom_label(index: int) -> String
```

Persistence:

- `load_settings()` reads `gameplay.world_slice_zoom_index`.
- `save_settings()` writes `gameplay.world_slice_zoom_index`.
- Default index is `1` (`1x`).

Notification:

```gdscript
signal world_slice_zoom_changed(index: int)
```

Emitted by `set_world_slice_zoom_index()` after the value is saved so that
`BoardView` can re-render immediately.

### 2. BoardView (`scripts/view/BoardView.gd`)

- Cache the last rendered `state` in a `_last_state` variable.
- In `_ready()`, connect to `SettingsService.world_slice_zoom_changed`.
- Provide `set_world_slice_zoom_index(index: int)` or a private
  `_on_world_slice_zoom_changed(index: int)` that re-applies layout using the
  cached state.
- In `_apply_world_slice_layout()` camera-follow branch, multiply the computed
  base `cell_size` by `SettingsService.WORLD_SLICE_ZOOM_OPTIONS[zoom_index]`
  before clamping to `world_slice_min_cell_size` / `world_slice_max_cell_size`.

The zoom factor is applied to the base cell size that already fills the
viewport, so `1x` matches the current behavior and `2x` makes each cell twice as
large (showing fewer cells on screen).

### 3. SettingsMenu (`scripts/view/SettingsMenu.gd` + `scenes/ui/SettingsMenu.tscn`)

- Add a `UiOptionRow` named `ZoomRow` below `FullscreenRow`.
- In `_ready()`, populate it with labels from
  `SettingsService.get_world_slice_zoom_label(index)` for each option.
- In `refresh_controls()`, select the current
  `SettingsService.world_slice_zoom_index`.
- Connect `item_selected` to `_on_zoom_selected(index)` which calls
  `SettingsService.set_world_slice_zoom_index(index)`.

## Data Flow

```
User selects a zoom level in SettingsMenu
  → SettingsService.set_world_slice_zoom_index(index)
    → saves user://settings.cfg
    → emits world_slice_zoom_changed(index)
      → BoardView._on_world_slice_zoom_changed(index)
        → re-applies world-slice layout with new zoom
        → calls render(_last_state)
```

## Error Handling

- Clamp `world_slice_zoom_index` to the valid option range on load and set.
- If `BoardView` receives the signal while not in world-slice mode, it stores
  the zoom for the next world-slice render and does nothing else.

## Testing

- Run the three existing smoke tests to confirm no regressions.
- Manual verification:
  1. Start a run and enter the world-slice map.
  2. Open settings and switch zoom levels.
  3. Confirm the map re-renders immediately with larger/smaller cells.
  4. Close and restart the game; confirm the last selected zoom is restored.
  5. Enter a traditional 8×8 room and confirm its layout is unchanged.

## Open Questions

None. The user confirmed:

- Fixed zoom levels: `0.5x / 1x / 1.5x / 2x / 4x`.
- Scope: world-slice mode only.
- Timing: immediate effect.
