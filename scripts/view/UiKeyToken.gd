class_name UiKeyToken
extends Button

signal drop_requested(target_slot_id: String, drag_data: Dictionary)
signal interaction_blocked(source_slot_id: String)

const ICON_PATHS: Dictionary = {
	"U": "res://art/imported/ui/icons/keys/up.PNG",
	"D": "res://art/imported/ui/icons/keys/down.PNG",
	"L": "res://art/imported/ui/icons/keys/left.PNG",
	"R": "res://art/imported/ui/icons/keys/right.PNG",
	"F": "res://art/imported/ui/icons/skills/forward.PNG",
	"B": "res://art/imported/ui/icons/skills/backward.PNG",
	"SL": "res://art/imported/ui/icons/skills/shift_left.PNG",
	"SR": "res://art/imported/ui/icons/skills/shift_right.PNG",
	"DS": "res://art/imported/ui/icons/skills/dash.PNG",
	"HK": "res://art/imported/ui/icons/skills/hook.PNG",
	"SB": "res://art/imported/ui/icons/skills/shield_bash.PNG",
	"HM": "res://art/imported/ui/icons/skills/hammer.PNG",
	"RA": "res://art/imported/ui/icons/skills/axe_spin.PNG",
	"PI": "res://art/imported/ui/icons/skills/pierce.PNG",
	"TH": "res://art/imported/ui/icons/skills/thrust.PNG",
	"SW": "res://art/imported/ui/icons/skills/sweep.PNG",
	"BW": "res://art/imported/ui/icons/skills/bow_shot.PNG",
	"CA": "res://art/imported/ui/icons/skills/cross_blade.PNG",
	"TL": "res://art/imported/ui/icons/skills/turn_left.PNG",
	"TR": "res://art/imported/ui/icons/skills/turn_right.PNG",
	"A": "res://art/imported/ui/icons/skills/attack.PNG",
	"I": "res://art/imported/ui/icons/skills/interact.PNG",
	"G": "res://art/imported/ui/icons/skills/guard.PNG",
	"W": "res://art/imported/ui/icons/skills/wait.PNG",
	"J": "res://art/imported/ui/icons/skills/jump.PNG",
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

	_text = label
	queue_redraw()


func _load_icon(token: String) -> Texture2D:
	var path: String = ICON_PATHS.get(token, "")
	if path.is_empty():
		return null
	var tex := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	return tex


var _text: String = ""


func _ensure_icon_rect() -> void:
	if _icon_rect == null:
		_icon_rect = TextureRect.new()
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon_rect)
	_icon_rect.texture = _icon_texture
	_icon_rect.visible = _icon_texture != null
	_layout_icon()


func _ensure_stack_label() -> void:
	if _stack_label == null:
		_stack_label = Label.new()
		_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_stack_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		_stack_label.add_theme_font_size_override("font_size", 12)
		_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_stack_label)
	_stack_label.text = "x%d" % _stack_count if _stack_count > 1 else ""
	_stack_label.visible = _stack_count > 1


func _layout_icon() -> void:
	if _icon_rect == null:
		return
	var viewport_height: float = float(get_viewport_rect().size.y) if is_inside_tree() else REFERENCE_VIEWPORT_HEIGHT
	var scale_factor: float = viewport_height / REFERENCE_VIEWPORT_HEIGHT
	var icon_height: float = ICON_BASE_HEIGHT * scale_factor
	var padded_height: float = icon_height + ICON_PADDING * 2.0 * scale_factor
	var icon_width: float = icon_height
	if _icon_texture != null and _icon_texture.get_height() > 0:
		icon_width = icon_height * (_icon_texture.get_width() / float(_icon_texture.get_height()))
	var padded_width: float = icon_width + ICON_PADDING * 2.0 * scale_factor
	var available: Vector2 = size
	_icon_rect.position = Vector2((available.x - padded_width) * 0.5 + ICON_PADDING * scale_factor, (available.y - padded_height) * 0.5 + ICON_PADDING * scale_factor)
	_icon_rect.size = Vector2(icon_width, icon_height)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_icon()


func _draw() -> void:
	if _text.is_empty():
		return
	var font := get_theme_font("font")
	var font_size := int(get_theme_font_size("font_size") * 0.85)
	var text_size := font.get_string_size(_text, font_size)
	var pos := Vector2((size.x - text_size.x) * 0.5, size.y - 4.0)
	draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not editable or permanently_disabled:
		return null
	var data := {
		"source_slot_id": source_slot_id,
		"source_index": source_index,
		"key_id": key_id,
	}
	set_drag_preview(_create_drag_preview())
	return data


func _create_drag_preview() -> Control:
	var preview := UiKeyToken.new()
	preview.setup(key_id, "", -1, _text, false, "", custom_minimum_size, false, false, _stack_count)
	preview.modulate.a = 0.85
	return preview


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not editable or permanently_disabled:
		return false
	if data is Dictionary and data.has("source_slot_id") and data["source_slot_id"] != source_slot_id:
		return true
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		drop_requested.emit(source_slot_id, data)


func update_stack_count(count: int) -> void:
	_stack_count = maxi(1, count)
	_ensure_stack_label()
