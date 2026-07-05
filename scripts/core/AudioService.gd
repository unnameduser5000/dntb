extends Node

## Thin audio facade: use Godot's AudioStreamPlayer/buses, centralize calls here.

signal music_started(stream: AudioStream)
signal music_stopped
signal sfx_played(stream: AudioStream)

@export var music_bus_name := "Music"
@export var sfx_bus_name := "SFX"
@export var crossfade_duration: float = 1.0
@export var menu_duck_volume_db: float = -12.0

const MUSIC_TITLE := "res://music/Pixel Dungeon.mp3"
const MUSIC_DUNGEON := "res://music/The Forgotten Depths.mp3"
const MUSIC_ELITE := "res://music/The Shadowed Chamber.mp3"
const MUSIC_BOSS := "res://music/The Last Stand.mp3"
const MUSIC_REST := "res://music/Restroom Breeze.mp3"

var _music_players: Array[AudioStreamPlayer] = []
var _current_music_key: String = ""
var _target_volume_db: float = 0.0
var _duck_active: bool = false
var _tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(music_bus_name)
	_ensure_bus(sfx_bus_name)

	_music_players.append(_make_music_player("MusicPlayerA"))
	_music_players.append(_make_music_player("MusicPlayerB"))


func _make_music_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = music_bus_name
	add_child(player)
	return player


func _active_player() -> AudioStreamPlayer:
	for player in _music_players:
		if player.playing:
			return player
	return _music_players[0] if not _music_players.is_empty() else null


func _inactive_player() -> AudioStreamPlayer:
	var active := _active_player()
	for player in _music_players:
		if player != active:
			return player
	return _music_players[1] if _music_players.size() > 1 else null


func play_music(stream_or_path, volume_db: float = 0.0) -> void:
	var stream := _resolve_stream(stream_or_path)
	if stream == null:
		return

	_target_volume_db = volume_db
	var active := _active_player()
	if active == null:
		return
	if active.stream == stream and active.playing:
		return

	if stream is AudioStreamMP3:
		stream.loop = true

	if not active.playing:
		_start_player(active, stream, volume_db)
		music_started.emit(stream)
		return

	_crossfade_to(stream, volume_db)


func _start_player(player: AudioStreamPlayer, stream: AudioStream, volume_db: float) -> void:
	player.stream = stream
	player.volume_db = menu_duck_volume_db if _duck_active else volume_db
	player.play()


func play_music_by_key(key: String, volume_db: float = 0.0) -> void:
	var path := _music_path_for_key(key)
	if path.is_empty():
		return
	var active := _active_player()
	if active != null and _current_music_key == key and active.playing:
		return
	_current_music_key = key
	play_music(path, volume_db)


func _music_path_for_key(key: String) -> String:
	match key:
		"title": return MUSIC_TITLE
		"dungeon": return MUSIC_DUNGEON
		"elite": return MUSIC_ELITE
		"boss": return MUSIC_BOSS
		"rest": return MUSIC_REST
		_:
			return ""


func stop_music() -> void:
	if _music_players.is_empty():
		return
	_fade_out_all()
	_current_music_key = ""
	music_stopped.emit()


func _crossfade_to(stream: AudioStream, volume_db: float) -> void:
	var outgoing := _active_player()
	var incoming := _inactive_player()

	if incoming.playing:
		incoming.stop()

	incoming.stream = stream
	incoming.volume_db = menu_duck_volume_db if _duck_active else -80.0
	incoming.play()

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	var target_db := menu_duck_volume_db if _duck_active else volume_db
	_tween.tween_property(outgoing, "volume_db", -80.0, crossfade_duration)
	_tween.tween_property(incoming, "volume_db", target_db, crossfade_duration)
	_tween.chain().tween_callback(func() -> void:
		outgoing.stop()
		music_started.emit(stream)
	)


func _fade_out_all() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	for player in _music_players:
		if player.playing:
			_tween.tween_property(player, "volume_db", -80.0, crossfade_duration)
	_tween.chain().tween_callback(func() -> void:
		for player in _music_players:
			player.stop()
	)


func set_duck_active(active: bool) -> void:
	if _duck_active == active:
		return
	_duck_active = active
	var target_db := menu_duck_volume_db if _duck_active else _target_volume_db
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	for player in _music_players:
		if player.playing:
			_tween.tween_property(player, "volume_db", target_db, crossfade_duration)


func play_sfx(stream_or_path, volume_db: float = 0.0) -> AudioStreamPlayer:
	var stream := _resolve_stream(stream_or_path)
	if stream == null:
		return null

	var player := AudioStreamPlayer.new()
	player.bus = sfx_bus_name
	player.stream = stream
	player.volume_db = volume_db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
	sfx_played.emit(stream)
	return player


func set_bus_volume_linear(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(value, 0.0, 1.0)))


func set_bus_muted(bus_name: String, muted: bool) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	AudioServer.set_bus_mute(bus_index, muted)


func _resolve_stream(stream_or_path) -> AudioStream:
	if stream_or_path is AudioStream:
		return stream_or_path
	if stream_or_path is String:
		return load(stream_or_path) as AudioStream
	return null


func _ensure_bus(bus_name: String) -> void:
	if bus_name.is_empty() or AudioServer.get_bus_index(bus_name) != -1:
		return

	AudioServer.add_bus()
	var bus_index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
