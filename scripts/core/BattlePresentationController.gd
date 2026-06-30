class_name BattlePresentationController
extends RefCounted

const ActorViewScene := preload("res://scenes/actors/ActorView.tscn")
const BattleEffectControllerScript := preload("res://scripts/core/BattleEffectController.gd")
const LEGACY_TIMING_PROFILE := {
	"move_duration": 0.12,
	"hit_flash_in_duration": 0.05,
	"hit_flash_out_duration": 0.08,
	"die_squash_duration": 0.04,
	"die_fade_duration": 0.12,
	"action_start_expand_duration": 0.04,
	"action_start_settle_duration": 0.05,
	"animation_speed_scale": 1.0,
	"effect_duration_scale": 1.0,
	"action_pause_duration": 0.04,
}
const WORLD_SLICE_FAST_TIMING_PROFILE := {
	"move_duration": 0.055,
	"hit_flash_in_duration": 0.028,
	"hit_flash_out_duration": 0.04,
	"die_squash_duration": 0.03,
	"die_fade_duration": 0.08,
	"action_start_expand_duration": 0.02,
	"action_start_settle_duration": 0.025,
	"animation_speed_scale": 1.45,
	"effect_duration_scale": 0.65,
	"action_pause_duration": 0.0,
}

var board_view
var actor_root
var effect_root
var actor_views: Dictionary = {}
var animation_enabled: bool = true
var action_pause_duration: float = 0.04
var _wait_for_presentation_completion: bool = true
var _timing_profile: Dictionary = LEGACY_TIMING_PROFILE.duplicate(true)
var effect_controller = null


func setup(board, root: Node, new_effect_root: Node = null) -> void:
	board_view = board
	actor_root = root
	effect_root = new_effect_root
	animation_enabled = DisplayServer.get_name() != "headless"
	effect_controller = BattleEffectControllerScript.new()
	effect_controller.setup(board_view, effect_root)


func reset_for_state(state) -> void:
	clear_views()
	sync_views(state, true)


func should_wait_for_presentation() -> bool:
	return animation_enabled and _wait_for_presentation_completion


func set_wait_for_presentation_completion(enabled: bool) -> void:
	_wait_for_presentation_completion = enabled


func debug_wait_for_presentation_completion() -> bool:
	return _wait_for_presentation_completion


func use_world_slice_fast_timing_profile() -> void:
	_apply_timing_profile(WORLD_SLICE_FAST_TIMING_PROFILE)


func use_legacy_timing_profile() -> void:
	_apply_timing_profile(LEGACY_TIMING_PROFILE)


func debug_current_timing_profile_name() -> String:
	if is_equal_approx(action_pause_duration, 0.0):
		return "world_slice_fast"
	return "legacy"


func clear_views() -> void:
	for actor_id in actor_views.keys():
		var view = actor_views[actor_id]
		if is_instance_valid(view):
			view.queue_free()
	actor_views.clear()
	if effect_controller != null and effect_controller.has_method("clear_effects"):
		effect_controller.clear_effects()


func sync_views(state, snap_positions: bool = true) -> void:
	if state == null:
		clear_views()
		return

	var alive_ids: Dictionary = {}
	var visible_actor_ids: Dictionary = {}
	for actor in state.actors:
		if actor == null or actor.is_dead():
			continue
		alive_ids[int(actor.id)] = true
		if not _should_render_actor_view(state, actor):
			continue
		visible_actor_ids[int(actor.id)] = true
		var view = _ensure_actor_view(actor)
		if view != null:
			_bind_actor_view(view, actor)
			if snap_positions:
				view.position = _grid_to_actor_world(actor.grid_pos)

	var stale_ids: Array = []
	for actor_id in actor_views.keys():
		if not alive_ids.has(int(actor_id)) or not visible_actor_ids.has(int(actor_id)):
			stale_ids.append(actor_id)

	for actor_id in stale_ids:
		var stale_view = actor_views[actor_id]
		if is_instance_valid(stale_view):
			stale_view.queue_free()
		actor_views.erase(actor_id)

	state.entity_visual_count = visible_actor_ids.size()


func handle_actor_moved(actor, _from_cell: Vector2i, to_cell: Vector2i) -> void:
	var view = _ensure_actor_view(actor)
	if view == null:
		return
	_bind_actor_view(view, actor)
	if not animation_enabled:
		view.position = _grid_to_actor_world(to_cell)
		return
	_play_view_move(view, _grid_to_actor_world(to_cell))


func handle_actor_damaged(actor, _amount: int) -> void:
	var view = _ensure_actor_view(actor)
	if view == null:
		return
	_bind_actor_view(view, actor)
	if effect_controller != null and effect_controller.has_method("play_frame"):
		effect_controller.play_frame({
			"kind": "actor_damaged",
			"actor": actor,
			"amount": _amount,
		})
	if not animation_enabled:
		return
	_play_view_hit(view)


func handle_actor_died(actor) -> void:
	if actor == null:
		return
	var actor_id := int(actor.id)
	var view = actor_views.get(actor_id)
	if view == null or not is_instance_valid(view):
		return
	if effect_controller != null and effect_controller.has_method("play_frame"):
		effect_controller.play_frame({
			"kind": "actor_died",
			"actor": actor,
		})
	if animation_enabled:
		var tween: Tween = _play_view_die(view)
		if tween == null:
			view.queue_free()
			actor_views.erase(actor_id)
			return
		tween.finished.connect(func() -> void:
			if is_instance_valid(view):
				view.queue_free()
			actor_views.erase(actor_id)
		)
		return
	view.queue_free()
	actor_views.erase(actor_id)


func handle_action_started(action) -> void:
	if not animation_enabled:
		return
	var actor = null if action == null else action.actor
	var view = _ensure_actor_view(actor)
	if view == null:
		return
	_bind_actor_view(view, actor)
	if effect_controller != null and effect_controller.has_method("play_action_started"):
		effect_controller.play_action_started(action)
	_play_view_action_start(view)


func present_action_started_non_blocking(action) -> void:
	handle_action_started(action)


func present_frames_non_blocking(frames: Array) -> void:
	for frame in frames:
		if frame == null:
			continue
		match String(frame.get("kind", "")):
			"actor_moved":
				_present_actor_moved_non_blocking(frame)
			"actor_damaged":
				_present_actor_damaged_non_blocking(frame)
			"actor_died":
				_present_actor_died_non_blocking(frame)
			"attack_missed", "move_collision":
				if effect_controller != null and effect_controller.has_method("play_frame"):
					effect_controller.play_frame(frame)
			_:
				pass


func play_action_started(action) -> void:
	if not animation_enabled:
		return
	var actor = null if action == null else action.actor
	var view = _ensure_actor_view(actor)
	if view == null:
		return
	_bind_actor_view(view, actor)
	if effect_controller != null and effect_controller.has_method("play_action_started"):
		effect_controller.play_action_started(action)
	await _await_tween(_play_view_action_start(view))


func play_action_finished(_action) -> void:
	if not animation_enabled or action_pause_duration <= 0.0:
		return
	var timer: SceneTreeTimer = _make_timer(action_pause_duration)
	if timer != null:
		await timer.timeout


func play_frames(frames: Array) -> void:
	for frame in frames:
		if frame == null:
			continue
		if effect_controller != null and effect_controller.has_method("play_frame"):
			effect_controller.play_frame(frame)
		match String(frame.get("kind", "")):
			"actor_moved":
				await _play_actor_moved(frame)
			"actor_damaged":
				await _play_actor_damaged(frame)
			"actor_died":
				await _play_actor_died(frame)
			"attack_missed", "move_collision":
				pass
			_:
				pass


func _ensure_actor_view(actor) -> Node2D:
	if actor == null or actor_root == null:
		return null

	var actor_id := int(actor.id)
	var view = actor_views.get(actor_id)
	if view == null or not is_instance_valid(view):
		view = _instantiate_actor_view(actor)
		if view == null:
			return null
		view.name = "ActorView_%d" % actor_id
		actor_root.add_child(view)
		actor_views[actor_id] = view

	_bind_actor_view(view, actor)
	return view


func _grid_to_actor_world(cell: Vector2i) -> Vector2:
	if board_view == null:
		return Vector2.ZERO
	var cell_size := float(board_view.cell_size)
	return board_view.grid_to_world(cell) + Vector2(cell_size * 0.5, cell_size * 0.5)


func _should_render_actor_view(state, actor) -> bool:
	if state == null or actor == null:
		return false
	if actor.team == "player":
		return true
	if not bool(state.is_world_slice):
		return true
	if board_view != null and board_view.has_method("is_cell_in_render_window"):
		if not bool(board_view.call("is_cell_in_render_window", actor.grid_pos)):
			return false
	var visible_set = state.get("visible_cell_set")
	if visible_set is Dictionary and not visible_set.is_empty():
		return visible_set.has(actor.grid_pos)
	return state.visible_cells.has(actor.grid_pos)


func _play_actor_moved(frame: Dictionary) -> void:
	var actor = frame.get("actor")
	var view = _ensure_actor_view(actor)
	if view == null:
		return
	_bind_actor_view(view, actor)
	var to_cell: Vector2i = frame.get("to_cell", Vector2i.ZERO)
	if not animation_enabled:
		view.position = _grid_to_actor_world(to_cell)
		return
	await _await_tween(_play_view_move(view, _grid_to_actor_world(to_cell)))


func _present_actor_moved_non_blocking(frame: Dictionary) -> void:
	var actor = frame.get("actor")
	var view = _ensure_actor_view(actor)
	if view == null:
		return
	_bind_actor_view(view, actor)
	var to_cell: Vector2i = frame.get("to_cell", Vector2i.ZERO)
	if not animation_enabled:
		view.position = _grid_to_actor_world(to_cell)
		return
	_play_view_move(view, _grid_to_actor_world(to_cell))


func _play_actor_damaged(frame: Dictionary) -> void:
	var actor = frame.get("actor")
	var view = _ensure_actor_view(actor)
	if view == null:
		return
	_bind_actor_view(view, actor)
	if not animation_enabled:
		return
	await _await_tween(_play_view_hit(view))


func _present_actor_damaged_non_blocking(frame: Dictionary) -> void:
	var actor = frame.get("actor")
	var view = _ensure_actor_view(actor)
	if view == null:
		return
	_bind_actor_view(view, actor)
	if effect_controller != null and effect_controller.has_method("play_frame"):
		effect_controller.play_frame(frame)
	if not animation_enabled:
		return
	_play_view_hit(view)


func _play_actor_died(frame: Dictionary) -> void:
	var actor = frame.get("actor")
	if actor == null:
		return
	var actor_id := int(actor.id)
	var view = actor_views.get(actor_id)
	if view == null or not is_instance_valid(view):
		return
	if animation_enabled:
		var tween: Tween = _play_view_die(view)
		if tween != null:
			await tween.finished
	if is_instance_valid(view):
		view.queue_free()
	actor_views.erase(actor_id)


func _present_actor_died_non_blocking(frame: Dictionary) -> void:
	var actor = frame.get("actor")
	if actor == null:
		return
	var actor_id := int(actor.id)
	var view = actor_views.get(actor_id)
	if view == null or not is_instance_valid(view):
		return
	if effect_controller != null and effect_controller.has_method("play_frame"):
		effect_controller.play_frame(frame)
	if animation_enabled:
		var tween: Tween = _play_view_die(view)
		if tween != null:
			tween.finished.connect(func() -> void:
				if is_instance_valid(view):
					view.queue_free()
				actor_views.erase(actor_id)
			)
			return
	if is_instance_valid(view):
		view.queue_free()
	actor_views.erase(actor_id)


func _instantiate_actor_view(actor) -> Node2D:
	var actor_scene: PackedScene = ActorViewScene
	if actor != null and actor.def != null and actor.def.view_scene != null:
		actor_scene = actor.def.view_scene

	var instance = actor_scene.instantiate()
	if instance is Node2D:
		return instance

	if instance is Node:
		instance.free()

	if actor_scene != ActorViewScene:
		push_warning("Actor view scene for %s must inherit Node2D; using default ActorView." % String(actor.def.id))
		var fallback = ActorViewScene.instantiate()
		if fallback is Node2D:
			return fallback

	return null


func _bind_actor_view(view: Node2D, actor) -> void:
	if view != null and view.has_method("bind"):
		view.call("bind", actor)
	if view != null and view.has_method("set_timing_profile"):
		view.call("set_timing_profile", _timing_profile)


func _play_view_move(view: Node2D, to_pos: Vector2) -> Tween:
	if view != null and view.has_method("play_move"):
		var tween = view.call("play_move", to_pos)
		if tween is Tween:
			return tween
	if view != null:
		view.position = to_pos
	return null


func _play_view_hit(view: Node2D) -> Tween:
	if view != null and view.has_method("play_hit"):
		var tween = view.call("play_hit")
		if tween is Tween:
			return tween
	return null


func _play_view_die(view: Node2D) -> Tween:
	if view != null and view.has_method("play_die"):
		var tween = view.call("play_die")
		if tween is Tween:
			return tween
	return null


func _play_view_action_start(view: Node2D) -> Tween:
	if view != null and view.has_method("play_action_start"):
		var tween = view.call("play_action_start")
		if tween is Tween:
			return tween
	return null


func _await_tween(tween: Tween) -> void:
	if tween == null:
		return
	await tween.finished


func _make_timer(duration: float) -> SceneTreeTimer:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop.create_timer(duration)
	return null


func _apply_timing_profile(profile: Dictionary) -> void:
	_timing_profile = profile.duplicate(true)
	action_pause_duration = maxf(0.0, float(_timing_profile.get("action_pause_duration", 0.04)))
	if effect_controller != null and effect_controller.has_method("set_effect_duration_scale"):
		effect_controller.set_effect_duration_scale(float(_timing_profile.get("effect_duration_scale", 1.0)))
	for actor_id in actor_views.keys():
		var view = actor_views[actor_id]
		if is_instance_valid(view) and view.has_method("set_timing_profile"):
			view.call("set_timing_profile", _timing_profile)
