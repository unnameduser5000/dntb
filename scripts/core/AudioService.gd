extends Node

## Thin audio facade: use Godot's AudioStreamPlayer/buses, centralize calls here.

signal music_started(stream: AudioStream)
signal music_stopped
signal sfx_played(stream: AudioStream)

@export var music_bus_name := "Music"
@export var sfx_bus_name := "SFX"

var _music_player: AudioStreamPlayer


func _ready() -> void:
	_ensure_bus(music_bus_name)
	_ensure_bus(sfx_bus_name)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = music_bus_name
	add_child(_music_player)


func play_music(stream_or_path, volume_db: float = 0.0) -> void:
	var stream := _resolve_stream(stream_or_path)
	if stream == null:
		return

	if _music_player.stream == stream and _music_player.playing:
		return

	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()
	music_started.emit(stream)


func stop_music() -> void:
	if _music_player == null:
		return
	_music_player.stop()
	music_stopped.emit()


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
