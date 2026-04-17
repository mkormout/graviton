extends Node

## Cross-fade music system with wave-based category selection (Phase 16)

@export var crossfade_duration: float = 2.0
@export var music_volume_db: float = -10.5
@export var combat_wave: int = 6
@export var high_intensity_wave: int = 11

## Preload catalog — var (not const) required for preload() at class scope (Pitfall 5)
var _catalog: Dictionary = {
	"ambient": [
		preload("res://music/Gravity-Drum Choir.mp3"),
		preload("res://music/Sulfur Orbit.mp3"),
	],
	"combat": [
		preload("res://music/Static Lullaby.mp3"),
		preload("res://music/Gravimetric Dawn.mp3"),
	],
	"high_intensity": [
		preload("res://music/Static Lullaby.mp3"),
		preload("res://music/Gravimetric Dawn.mp3"),
	],
}

## State
var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null
var _active_tween: Tween = null
var _current_category: String = "ambient"
var _last_track: AudioStream = null


func _ready() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.volume_db = music_volume_db
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.volume_db = -80.0
	add_child(_player_b)

	call_deferred("_start_playback")


func _start_playback() -> void:
	var track := _pick_track("ambient")
	if track:
		_player_a.stream = track
		_player_a.play()
		print("[MusicManager] Started playback: ambient")


## Called by world.gd to wire WaveManager signals
func connect_to_wave_manager(wm: Node) -> void:
	wm.wave_started.connect(_on_wave_started)
	print("[MusicManager] Connected to WaveManager wave_started signal")


func _on_wave_started(wave_number: int, _enemy_count: int, _label_text: String) -> void:
	var new_category := _get_category(wave_number)
	if new_category != _current_category:
		_current_category = new_category
		var track := _pick_track(new_category)
		if track:
			_crossfade_to(track)
		print("[MusicManager] Category changed to: %s (wave %d)" % [new_category, wave_number])


func _get_category(wave_number: int) -> String:
	if wave_number >= high_intensity_wave:
		return "high_intensity"
	elif wave_number >= combat_wave:
		return "combat"
	return "ambient"


func _pick_track(category: String) -> AudioStream:
	var pool: Array = _catalog.get(category, [])
	if pool.is_empty():
		for key in _catalog:
			if not _catalog[key].is_empty():
				pool = _catalog[key]
				break
	if pool.is_empty():
		push_warning("[MusicManager] No tracks available in any category")
		return null
	var candidates: Array = pool.filter(func(t): return t != _last_track)
	if candidates.is_empty():
		candidates = pool
	var chosen: AudioStream = candidates.pick_random()
	_last_track = chosen
	return chosen


func _crossfade_to(stream: AudioStream) -> void:
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
		_finish_swap()

	_player_b.stream = stream
	_player_b.volume_db = -80.0
	_player_b.play()

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_player_a, "volume_db", -80.0, crossfade_duration)
	_active_tween.tween_property(_player_b, "volume_db", music_volume_db, crossfade_duration)
	_active_tween.chain().tween_callback(_finish_swap)


func _finish_swap() -> void:
	_player_a.stop()
	var tmp := _player_a
	_player_a = _player_b
	_player_b = tmp
	_active_tween = null


## Restore ambient category and restart playback — called by Phase 17 game restart
func reset() -> void:
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
		_active_tween = null
	_current_category = "ambient"
	_last_track = null
	_player_a.stop()
	_player_b.stop()
	_player_b.volume_db = -80.0
	_player_a.volume_db = music_volume_db
	var track := _pick_track("ambient")
	if track:
		_player_a.stream = track
		_player_a.play()
	print("[MusicManager] Reset to ambient")
