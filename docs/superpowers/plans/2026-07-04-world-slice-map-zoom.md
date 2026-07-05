# World-Slice Map Zoom Setting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a settings-menu option that lets the player choose a fixed map zoom level (`0.5x / 1x / 1.5x / 2x / 4x`) for world-slice mode, applying immediately and persisting across restarts.

**Architecture:** `SettingsService` owns the zoom index and persists it. `SettingsMenu` exposes a dropdown populated from `SettingsService`. `BoardView` subscribes to the zoom change signal and re-renders the world-slice layout with the new cell-size multiplier.

**Tech Stack:** Godot 4.7, GDScript, ConfigFile persistence, `UiOptionRow` reusable component.

---

## File Mapping

| File | Responsibility |
|------|----------------|
| `scripts/core/SettingsService.gd` | Own `world_slice_zoom_index`, load/save it, emit change signal. |
| `scripts/view/BoardView.gd` | Apply zoom multiplier to world-slice `cell_size`, re-render on change. |
| `scripts/view/SettingsMenu.gd` | Add zoom row UI, populate options, sync/forward selection. |
| `scenes/ui/SettingsMenu.tscn` | Add `ZoomRow` (UiOptionRow) to the scroll content. |

---

### Task 1: Extend SettingsService with zoom setting

**Files:**
- Modify: `scripts/core/SettingsService.gd`

- [ ] **Step 1: Add constants, state, and signal**

Add below the existing resolution/fullscreen members:

```gdscript
const WORLD_SLICE_ZOOM_OPTIONS := [0.5, 1.0, 1.5, 2.0, 4.0]

signal world_slice_zoom_changed(index: int)

var world_slice_zoom_index := 1
```

- [ ] **Step 2: Load the setting**

In `load_settings()`, after the display values are loaded, add:

```gdscript
world_slice_zoom_index = clampi(
    int(config.get_value("gameplay", "world_slice_zoom_index", 1)),
    0,
    WORLD_SLICE_ZOOM_OPTIONS.size() - 1
)
```

- [ ] **Step 3: Save the setting**

In `save_settings()`, after the display values are written, add:

```gdscript
config.set_value("gameplay", "world_slice_zoom_index", world_slice_zoom_index)
```

- [ ] **Step 4: Add setter and label helper**

Add new public methods at the end of the file:

```gdscript
func set_world_slice_zoom_index(index: int) -> void:
    world_slice_zoom_index = clampi(index, 0, WORLD_SLICE_ZOOM_OPTIONS.size() - 1)
    save_settings()
    world_slice_zoom_changed.emit(world_slice_zoom_index)


func get_world_slice_zoom_label(index: int) -> String:
    if index < 0 or index >= WORLD_SLICE_ZOOM_OPTIONS.size():
        return ""
    return "%gx" % WORLD_SLICE_ZOOM_OPTIONS[index]
```

- [ ] **Step 5: Verify syntax**

Run: `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

Expected: `SmokeTest passed`

- [ ] **Step 6: Commit**

```bash
git add scripts/core/SettingsService.gd
git commit -m "feat: persist world-slice zoom setting in SettingsService

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Add ZoomRow to SettingsMenu scene

**Files:**
- Modify: `scenes/ui/SettingsMenu.tscn`

- [ ] **Step 1: Add the row node**

Insert a new `UiOptionRow` instance named `ZoomRow` as a sibling immediately
below `FullscreenRow`:

```text
[node name="ZoomRow" parent="Panel/Margin/Content/Scroll/ScrollContent" instance=ExtResource("5_option_row")]
unique_name_in_owner = true
layout_mode = 2
label_text = "地图缩放"
```

- [ ] **Step 2: Commit**

```bash
git add scenes/ui/SettingsMenu.tscn
git commit -m "feat: add ZoomRow to settings menu scene

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Wire zoom dropdown in SettingsMenu script

**Files:**
- Modify: `scripts/view/SettingsMenu.gd`

- [ ] **Step 1: Cache the zoom option node**

Add below the existing `@onready` lines:

```gdscript
@onready var zoom_option: OptionButton = %ZoomRow.get_node("Option")
```

- [ ] **Step 2: Populate options and connect signal**

In `_ready()`, after the resolution option setup, add:

```gdscript
for index in range(SettingsService.WORLD_SLICE_ZOOM_OPTIONS.size()):
    zoom_option.add_item(SettingsService.get_world_slice_zoom_label(index), index)

zoom_option.item_selected.connect(_on_zoom_selected)
```

- [ ] **Step 3: Sync control value**

In `refresh_controls()`, after the fullscreen toggle sync, add:

```gdscript
zoom_option.select(SettingsService.world_slice_zoom_index)
```

- [ ] **Step 4: Handle selection**

Add a new handler method:

```gdscript
func _on_zoom_selected(index: int) -> void:
    SettingsService.set_world_slice_zoom_index(index)
```

- [ ] **Step 5: Verify syntax**

Run: `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

Expected: `SmokeTest passed`

- [ ] **Step 6: Commit**

```bash
git add scripts/view/SettingsMenu.gd
git commit -m "feat: wire world-slice zoom dropdown in SettingsMenu

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Apply zoom multiplier in BoardView

**Files:**
- Modify: `scripts/view/BoardView.gd`

- [ ] **Step 1: Cache last rendered state**

Add a member variable:

```gdscript
var _last_state = null
```

At the top of `render(state)`:

```gdscript
_last_state = state
```

- [ ] **Step 2: Add zoom helper**

Add a method that returns the current zoom factor:

```gdscript
func _get_world_slice_zoom_factor() -> float:
    if SettingsService == null:
        return 1.0
    var index: int = SettingsService.world_slice_zoom_index
    if index < 0 or index >= SettingsService.WORLD_SLICE_ZOOM_OPTIONS.size():
        return 1.0
    return float(SettingsService.WORLD_SLICE_ZOOM_OPTIONS[index])
```

- [ ] **Step 3: Connect to the zoom change signal**

In `_ready()`, after the existing setup, add:

```gdscript
if SettingsService != null:
    SettingsService.world_slice_zoom_changed.connect(_on_world_slice_zoom_changed)
```

Add the handler:

```gdscript
func _on_world_slice_zoom_changed(_index: int) -> void:
    if _last_state != null and bool(_last_state.is_world_slice):
        render(_last_state)
```

- [ ] **Step 4: Apply zoom in camera-follow layout**

In `_apply_world_slice_layout()`, inside the `world_slice_camera_follow` branch,
after `cell_size = compute_world_slice_cell_size()`, add:

```gdscript
var zoom_factor: float = _get_world_slice_zoom_factor()
cell_size = int(round(float(cell_size) * zoom_factor))
cell_size = clampi(cell_size, world_slice_min_cell_size, world_slice_max_cell_size)
```

- [ ] **Step 5: Verify behavior**

Run all three smoke tests:

```bash
godot --headless --path . --script res://scripts/tests/SmokeTest.gd
godot --headless --path . --script res://scripts/tests/ActorPresentationSandboxSmoke.gd
godot --headless --path . --script res://scripts/tests/BattleEffectSandboxSmoke.gd
```

Expected:
- `SmokeTest passed`
- `ActorPresentationSandbox smoke passed`
- `BattleEffectSandbox smoke passed`

- [ ] **Step 6: Commit**

```bash
git add scripts/view/BoardView.gd
git commit -m "feat: apply settings zoom to world-slice map and re-render on change

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Update documentation

**Files:**
- Modify: `DEVELOP_LOG.md`

- [ ] **Step 1: Add a changelog entry**

Append a new `## 2026-07-04 World-slice map zoom setting` section documenting:
- Added `SettingsService.world_slice_zoom_index` with five fixed zoom levels.
- Added `ZoomRow` to `SettingsMenu` populated from `WORLD_SLICE_ZOOM_OPTIONS`.
- `BoardView` applies the zoom multiplier to world-slice `cell_size` and
  re-renders immediately when the setting changes.
- Persistence via `user://settings.cfg` under the `gameplay` section.
- Validation commands and expected `passed` results for the three smoke tests.

- [ ] **Step 2: Commit**

```bash
git add DEVELOP_LOG.md
git commit -m "docs: log world-slice map zoom setting

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

### Spec coverage

| Spec Requirement | Plan Task |
|---|---|
| Five fixed zoom options | Task 1, Task 3 |
| Persist in `user://settings.cfg` | Task 1 |
| Expose in SettingsMenu as dropdown | Task 2, Task 3 |
| Apply only to world-slice mode | Task 4 (guarded by `world_slice_camera_follow` and `is_world_slice`) |
| Immediate effect on change | Task 1 (signal), Task 4 (re-render handler) |
| Manual + smoke test validation | Task 4, Task 5 |

### Placeholder scan

No TBD/TODO/"implement later"/"appropriate error handling"/"similar to" patterns.
Each step contains exact file paths and code.

### Type consistency

- Signal name: `world_slice_zoom_changed(index: int)` used in Task 1 and Task 4.
- Setting name: `world_slice_zoom_index` used in Task 1, Task 3, Task 4.
- Options constant: `WORLD_SLICE_ZOOM_OPTIONS` used in Task 1, Task 3, Task 4.
- Label helper: `get_world_slice_zoom_label(index: int)` used in Task 1, Task 3.

All names match across tasks.
