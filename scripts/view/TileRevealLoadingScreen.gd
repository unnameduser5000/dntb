class_name TileRevealLoadingScreen
extends Control

## Minecraft-style tile reveal loading screen.
## Randomly picks an image from art/imported/ui/loading/common, slices it into
## a grid, and reveals tiles over time while the actual loading happens.

const IMAGE_DIR := "res://art/imported/ui/loading/common"
const GRID_COLUMNS := 80
const GRID_ROWS := 45
const TILE_COUNT := GRID_COLUMNS * GRID_ROWS

const TIPS: Array[String] = [
	"提示：按 Tab 打开背包，拖动符记到键位槽即可编辑指令链。",
	"提示：Q/W/E/R 与 A/S/D/F 两行键位在战斗中分别对应左右手行动。",
	"提示：敌人回合会按照其技能链行动，观察地面标记预判范围。",
	"提示：受到伤害不会立刻失败，先耗尽护甲与生命才会结束本轮。",
	"提示：在世界地图中只能在酒馆安全区修改键位指令。",
	"提示：方向键 F/B/SL/SR 分别代表正前、正后、左斜、右斜。",
	"提示：武器决定普通攻击 A 的实际动作，换武器等于换一套普攻。",
	"提示：击败精英敌人后可能掉落新的武器或符记奖励。",
	"提示：跳跃 J 可以越过一格深的裂隙或陷阱，但需要预留落点。",
	"提示：守卫 G 可以抵挡来自正面的攻击，注意它会消耗耐力。",
	"提示：连击 traces 会记录最近的动作，是后续连段判定的依据。",
	"提示：在设置中可切换自动推进，适合熟悉流程后加快节奏。",
]

@export var reveal_duration: float = 2.0
@export var reveal_stagger: float = 0.0005
@export var progress_label_color: Color = Color(0.9, 0.95, 1.0)

var _tiles: Array[ColorRect] = []
var _tile_indices: Array[int] = []
var _revealed_count: int = 0
var _elapsed: float = 0.0
var _source_image: Texture2D = null
var _is_revealing: bool = false
var _progress_ratio: float = 0.0
var _complete_delay: float = 1.0
var _complete_elapsed: float = 0.0

@onready var _progress_label: Label = %ProgressLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _tile_container: Control = %TileContainer
@onready var _tips_label: Label = %TipsLabel


func _ready() -> void:
	layout_mode = 3
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = 2
	grow_vertical = 2
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func show_loading(_title_text: String = "", _body_text: String = "", progress_ratio: float = 0.0) -> void:
	_progress_ratio = progress_ratio
	if not visible or _tiles.is_empty():
		_reset_and_start()
	_update_progress_display()


func set_progress(progress_ratio: float, _body_text: String = "") -> void:
	_progress_ratio = progress_ratio
	_update_progress_display()


func hide_loading() -> void:
	visible = false
	_is_revealing = false
	for tile in _tiles:
		tile.queue_free()
	_tiles.clear()
	_tile_indices.clear()


func _reset_and_start() -> void:
	for tile in _tiles:
		tile.queue_free()
	_tiles.clear()
	_tile_indices.clear()
	_revealed_count = 0
	_elapsed = 0.0
	_complete_elapsed = 0.0
	_is_revealing = true
	visible = true

	_source_image = null
	_tile_container.visible = true
	if _progress_label != null:
		_progress_label.visible = true
	if _progress_bar != null:
		_progress_bar.visible = true
	if _tips_label != null:
		_tips_label.visible = true

	_source_image = _pick_random_image()
	if _source_image == null:
		return

	_create_tiles()
	_shuffle_tiles()
	_update_tip()


func fade_to_black_and_hide(fade_duration: float = 0.5) -> void:
	var fade_rect := ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.layout_mode = 3
	fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.grow_horizontal = 2
	fade_rect.grow_vertical = 2
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	add_child(fade_rect)

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, fade_duration)
	await tween.finished

	hide_loading()
	fade_rect.queue_free()


func _update_tip() -> void:
	if _tips_label == null:
		return
	var tip: String = TIPS.pick_random()
	if not tip.is_empty():
		_tips_label.text = tip


func _pick_random_image() -> Texture2D:
	var dir := DirAccess.open(IMAGE_DIR)
	if dir == null:
		return null
	var candidates: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and (file_name.ends_with(".jpg") or file_name.ends_with(".png")):
			candidates.append(IMAGE_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	if candidates.is_empty():
		return null
	candidates.shuffle()
	return load(candidates[0]) as Texture2D


func _create_tiles() -> void:
	var tex_size: Vector2 = _source_image.get_size()
	var tile_uv_width := 1.0 / GRID_COLUMNS
	var tile_uv_height := 1.0 / GRID_ROWS

	var viewport_size := get_viewport_rect().size
	var display_size := _cover_size(tex_size, viewport_size)
	var offset := (viewport_size - display_size) * 0.5

	var tile_display_width := display_size.x / GRID_COLUMNS
	var tile_display_height := display_size.y / GRID_ROWS

	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://scenes/ui/shaders/TileRevealImage.gdshader")
	shader_material.set_shader_parameter("image", _source_image)

	for row in range(GRID_ROWS):
		for col in range(GRID_COLUMNS):
			var tile := ColorRect.new()
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.material = shader_material.duplicate()
			tile.material.set_shader_parameter("uv_offset", Vector2(col * tile_uv_width, row * tile_uv_height))
			tile.material.set_shader_parameter("uv_scale", Vector2(tile_uv_width, tile_uv_height))
			tile.position = Vector2(offset.x + col * tile_display_width, offset.y + row * tile_display_height)
			tile.size = Vector2(tile_display_width + 1.0, tile_display_height + 1.0)
			tile.modulate.a = 0.0
			_tile_container.add_child(tile)
			_tiles.append(tile)
			_tile_indices.append(_tiles.size() - 1)


func _cover_size(image_size: Vector2, viewport_size: Vector2) -> Vector2:
	var scale := maxf(viewport_size.x / image_size.x, viewport_size.y / image_size.y)
	return image_size * scale


func _shuffle_tiles() -> void:
	_tile_indices.shuffle()


func _process(delta: float) -> void:
	if not _is_revealing or _tiles.is_empty():
		return

	_elapsed += delta
	var duration := reveal_duration + TILE_COUNT * reveal_stagger
	var target_revealed := int(TILE_COUNT * clampf(_elapsed / duration, 0.0, 1.0))
	if _progress_ratio >= 0.0 and _progress_ratio < 1.0:
		target_revealed = mini(target_revealed, int(TILE_COUNT * _progress_ratio))
	else:
		target_revealed = TILE_COUNT
	target_revealed = mini(target_revealed, TILE_COUNT)

	while _revealed_count < target_revealed:
		var index := _tile_indices[_revealed_count]
		_tiles[index].modulate.a = 1.0
		_revealed_count += 1

	if _revealed_count >= TILE_COUNT:
		_complete_elapsed += delta
		if _complete_elapsed >= _complete_delay:
			_is_revealing = false


func is_complete() -> bool:
	return _revealed_count >= TILE_COUNT and _complete_elapsed >= _complete_delay


func _update_progress_display() -> void:
	if _progress_label != null:
		var percent := int(round(_progress_ratio * 100.0))
		_progress_label.text = "%d%%" % percent
	if _progress_bar != null:
		_progress_bar.value = _progress_ratio * 100.0


func set_progress_label_text(text: String) -> void:
	if _progress_label != null:
		_progress_label.text = text
