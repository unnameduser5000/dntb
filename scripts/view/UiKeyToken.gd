class_name UiKeyToken
extends Button

signal drop_requested(target_slot_id: String, drag_data: Dictionary)
signal interaction_blocked(source_slot_id: String)

const ICON_PATHS: Dictionary = {
	"U": "res://art/imported/ui/图标/按键/上.PNG",
	"D": "res://art/imported/ui/图标/按键/下.PNG",
	"L": "res://art/imported/ui/图标/按键/左.PNG",
	"R": "res://art/imported/ui/图标/按键/右.PNG",
	"F": "res://art/imported/ui/图标/技能/前进.PNG",
	"B": "res://art/imported/ui/图标/技能/后退.PNG",
	"SL": "res://art/imported/ui/图标/技能/左侧移.PNG",
	"SR": "res://art/imported/ui/图标/技能/右侧移.PNG",
	"DS": "res://art/imported/ui/图标/技能/冲刺.PNG",
	"HK": "res://art/imported/ui/图标/技能/钩拽.PNG",
	"SB": "res://art/imported/ui/图标/技能/盾击.PNG",
	"HM": "res://art/imported/ui/图标/技能/锤击.PNG",
	"RA": "res://art/imported/ui/图标/技能/旋斧.PNG",
	"PI": "res://art/imported/ui/图标/技能/穿刺.PNG",
	"TH": "res://art/imported/ui/图标/技能/贯刺.PNG",
	"SW": "res://art/imported/ui/图标/技能/横扫.PNG",
	"BW": "res://art/imported/ui/图标/技能/弓射.PNG",
	"CA": "res://art/imported/ui/图标/技能/十字刃.PNG",
	"TL": "res://art/imported/ui/图标/技能/左转.PNG",
	"TR": "res://art/imported/ui/图标/技能/右转.PNG",
	"A": "res://art/imported/ui/图标/技能/攻击.PNG",
	"I": "res://art/imported/ui/图标/技能/交互.PNG",
	"G": "res://art/imported/ui/图标/技能/防御.PNG",
	"W": "res://art/imported/ui/图标/技能/等待.PNG",
	"J": "res://art/imported/ui/图标/技能/跳跃.PNG",
}

const REFERENCE_VIEWPORT_HEIGHT: float = 1080.0
const ICON_BASE_HEIGHT: float = 26.0
const ICON_PADDING: float = 4.0

var key_id: String = ""
var source_slot_id: String = ""
var source_index: int = -1
var editable: bool = true
var adhesive := false
var permanently_disabled := false

var _icon_texture: Texture2D = null
var _icon_rect: TextureRect = null
var _stack_label: Label = null
var _stack_count: int = 1


func setup(
	new_key_id: String,
	new_source_slot_id: String,
	new_source_index: int,
	label: String,
	is_editable: bool = true,
	custom_tooltip: String = "",
	cell_size: Vector2 = Vector2(54, 36),
	is_adhesive: bool = false,
	is_permanently_disabled: bool = false,
	stack_count: int = 1
) -> void:
	key_id = new_key_id
	source_slot_id = new_source_slot_id
	source_index = new_source_index
	editable = is_editable
	adhesive = is_adhesive
	permanently_disabled = is_permanently_disabled
	_stack_count = maxi(1, stack_count)
	tooltip_text = custom_tooltip if not custom_tooltip.is_empty() else ("拖拽到按键槽里编排行动" if editable else "行动编码已锁定：只能在休息处调整")
	custom_minimum_size = cell_size
	theme_type_variation = &"ActionCard"
	disabled = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

	_icon_texture = _load_icon(key_id)
	_ensure_icon_rect()
	_ensure_stack_label()
	_update_visuals()

	if permanently_disabled:
		add_theme_stylebox_override("normal", _make_disabled_style(false))
		add_theme_stylebox_override("hover", _make_disabled_style(true))
		add_theme_stylebox_override("pressed", _make_disabled_style(true))
		add_theme_stylebox_override("focus", _make_disabled_style(true))
		add_theme_color_override("font_color", Color(1.0, 0.88, 0.9, 1.0))
	elif adhesive:
		add_theme_stylebox_override("normal", _make_adhesive_style(false))
		add_theme_stylebox_override("hover", _make_adhesive_style(true))
		add_theme_stylebox_override("pressed", _make_adhesive_style(true))
		add_theme_stylebox_override("focus", _make_adhesive_style(true))
		add_theme_color_override("font_color", Color(0.96, 0.9, 1.0, 1.0))
	else:
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("hover")
		remove_theme_stylebox_override("pressed")
		remove_theme_stylebox_override("focus")
		remove_theme_color_override("font_color")
	_ensure_lock_badge()


func _load_icon(token_id: String) -> Texture2D:
	var path: String = ICON_PATHS.get(token_id, "")
	if path.is_empty():
		return null
	var tex := load(path) as Texture2D
	return tex


func _ensure_icon_rect() -> void:
	if _icon_rect == null:
		_icon_rect = TextureRect.new()
		_icon_rect.name = "IconRect"
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_rect.pivot_offset = Vector2.ZERO
		add_child(_icon_rect)
	_icon_rect.texture = _icon_texture
	_icon_rect.visible = _icon_texture != null


func _ensure_stack_label() -> void:
	if _stack_label == null:
		_stack_label = Label.new()
		_stack_label.name = "StackLabel"
		_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stack_label.add_theme_font_size_override("font_size", 11)
		_stack_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		_stack_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		_stack_label.add_theme_constant_override("outline_size", 2)
		add_child(_stack_label)


func _update_visuals() -> void:
	var has_icon := _icon_texture != null
	text = "" if has_icon else _fallback_label()

	var bounds := size
	if bounds.x <= 0.0 or bounds.y <= 0.0:
		bounds = custom_minimum_size

	if _icon_rect != null:
		_icon_rect.visible = has_icon
		if has_icon:
			var scale := _get_resolution_scale()
			var target_height: float = ICON_BASE_HEIGHT * scale
			var max_size: Vector2 = bounds - Vector2(ICON_PADDING * 2.0, ICON_PADDING * 2.0)
			target_height = mini(target_height, max_size.y)
			var aspect: float = _icon_texture.get_size().aspect()
			var target_width: float = mini(target_height * aspect, max_size.x)
			target_height = target_width / aspect
			_icon_rect.size = Vector2(target_width, target_height)
			_icon_rect.position = (bounds - _icon_rect.size) * 0.5

	if _stack_label != null:
		_stack_label.visible = _stack_count > 1
		if _stack_count > 1:
			_stack_label.text = "x%d" % _stack_count
			_stack_label.position = Vector2(bounds.x - 18.0, bounds.y - 16.0)


func _fallback_label() -> String:
	match key_id:
		"F": return "前进"
		"B": return "后退"
		"SL": return "左侧移"
		"SR": return "右侧移"
		"DS": return "冲刺"
		"HK": return "钩拽"
		"SB": return "盾击"
		"HM": return "锤击"
		"RA": return "旋斧"
		"PI": return "穿刺"
		"TH": return "贯刺"
		"SW": return "横扫"
		"BW": return "弓射"
		"CA": return "十字刃"
		"TL": return "左转"
		"TR": return "右转"
		"A": return "攻击"
		"I": return "交互"
		"G": return "防御"
		"W": return "等待"
		"J": return "跳跃"
		"U": return "上"
		"D": return "下"
		"L": return "左"
		"R": return "右"
	return key_id


func _get_resolution_scale() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return 1.0
	return viewport.get_visible_rect().size.y / REFERENCE_VIEWPORT_HEIGHT


func _resized() -> void:
	_update_visuals()


func _ready() -> void:
	resized.connect(_resized)


func _get_drag_data(_at_position: Vector2):
	if not editable:
		interaction_blocked.emit(source_slot_id)
		return null
	if key_id.is_empty():
		return null

	var preview := Control.new()
	preview.custom_minimum_size = Vector2(54, 36)
	preview.size = Vector2(54, 36)

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.18, 0.92)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.grow_horizontal = 2
	bg.grow_vertical = 2
	preview.add_child(bg)

	if _icon_texture != null:
		var icon := TextureRect.new()
		icon.texture = _icon_texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.anchors_preset = Control.PRESET_FULL_RECT
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.grow_horizontal = 2
		icon.grow_vertical = 2
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(icon)
	else:
		var label := Label.new()
		label.text = text if not text.is_empty() else _fallback_label()
		label.theme = theme
		label.theme_type_variation = &"QueueSlot"
		label.anchors_preset = Control.PRESET_FULL_RECT
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.grow_horizontal = 2
		label.grow_vertical = 2
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		preview.add_child(label)

	set_drag_preview(preview)

	return {
		"key_id": key_id,
		"source_slot_id": source_slot_id,
		"source_index": source_index,
	}


func _make_adhesive_style(is_hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.34, 0.16, 0.4, 0.98) if not is_hovered else Color(0.42, 0.2, 0.5, 0.98)
	style.border_color = Color(0.85, 0.46, 0.98, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.22, 0.06, 0.24, 0.62)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _make_disabled_style(is_hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.08, 0.12, 0.99) if not is_hovered else Color(0.34, 0.1, 0.14, 0.99)
	style.border_color = Color(1.0, 0.32, 0.46, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.26, 0.04, 0.08, 0.78)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style


func _ensure_lock_badge() -> void:
	var existing := get_node_or_null("LockBadge") as Label
	if permanently_disabled:
		if existing == null:
			existing = Label.new()
			existing.name = "LockBadge"
			existing.position = Vector2(34, -4)
			existing.custom_minimum_size = Vector2(16, 16)
			existing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			existing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
			existing.add_theme_font_size_override("font_size", 12)
			existing.add_theme_color_override("font_color", Color(1.0, 0.92, 0.96, 1.0))
			existing.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.05, 0.96))
			existing.add_theme_constant_override("outline_size", 2)
			add_child(existing)
		existing.text = "锁"
		existing.visible = true
	elif existing != null:
		existing.visible = false


func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not editable:
		return false
	return typeof(data) == TYPE_DICTIONARY and data.has("key_id") and data.has("source_slot_id") and data.has("source_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	drop_requested.emit(source_slot_id, data)


func _gui_input(event: InputEvent) -> void:
	if editable:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			interaction_blocked.emit(source_slot_id)
