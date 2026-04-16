extends Node

## Signals for Phase 12 HUD consumption
signal score_changed(new_score: int, delta: int)
signal multiplier_changed(new_multiplier: int)
signal combo_updated(combo_count: int)
signal combo_expired()

## Constants
const MULTIPLIER_CAP: int = 16
const COMBO_CAP: int = 20
const COMBO_TIMEOUT: float = 5.0

## State
var total_score: int = 0
var kill_count: int = 0
var wave_multiplier: int = 1
var combo_count: int = 0

## Internal references
var _player: Node = null
var _combo_timer: Timer = null
var _combo_audio: AudioStreamPlayer = null


func _ready() -> void:
	# Combo timer — one-shot, 5 second timeout
	_combo_timer = Timer.new()
	_combo_timer.wait_time = COMBO_TIMEOUT
	_combo_timer.one_shot = true
	_combo_timer.timeout.connect(_on_combo_expired)
	add_child(_combo_timer)

	# Combo audio — non-positional AudioStreamPlayer
	_combo_audio = AudioStreamPlayer.new()
	_combo_audio.stream = preload("res://sounds/combo.wav")
	add_child(_combo_audio)

	# Deferred player lookup — autoloads run before scene nodes are ready
	call_deferred("_find_player")


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		push_warning("[ScoreManager] No node in group 'player' found")
		return
	if not _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.connect(_on_player_health_changed)
	print("[ScoreManager] Connected to player health_changed signal")


## Called by world.gd to wire WaveManager signals
func connect_to_wave_manager(wm: Node) -> void:
	wm.wave_completed.connect(_on_wave_completed)
	print("[ScoreManager] Connected to WaveManager wave_completed signal")


## Called by WaveManager._spawn_enemy() for each spawned enemy
func register_enemy(enemy: Node) -> void:
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))


# --- Kill Scoring ---

func _on_enemy_died(enemy: Node) -> void:
	var base_score: int = enemy.score_value if "score_value" in enemy else 0
	var enemy_pos: Vector2 = enemy.global_position
	kill_count += 1
	_increment_combo()

	var combo_factor: int = min(combo_count, COMBO_CAP)
	var kill_score: int = base_score * wave_multiplier * combo_factor

	total_score += kill_score
	score_changed.emit(total_score, kill_score)
	_spawn_score_label(enemy_pos, kill_score)

	var enemy_type: String = enemy.get_script().get_global_name() if enemy.get_script() else "Unknown"
	print("[ScoreManager] Kill: %s base:%d wave:x%d combo:x%d = %d | total: %d" % [
		enemy_type, base_score, wave_multiplier, combo_factor, kill_score, total_score
	])


# --- Combo Chain ---

func _increment_combo() -> void:
	if combo_count == 0:
		# First kill — start timer, no audio yet
		combo_count = 1
		_combo_timer.start()
		return

	# Subsequent kills — increment, restart timer, play audio
	combo_count += 1
	_combo_timer.start()
	_play_combo_sound(combo_count)
	combo_updated.emit(combo_count)
	print("[ScoreManager] Combo x%d" % combo_count)


func _on_combo_expired() -> void:
	if combo_count >= 2:
		print("[ScoreManager] Combo x%d ends | total: %d" % [combo_count, total_score])
	combo_count = 0
	combo_expired.emit()
	combo_updated.emit(0)


func _play_combo_sound(current_combo: int) -> void:
	# Each step raises pitch by one semitone: pow(2^(1/12), step)
	# combo 2 = base pitch (step 0), combo 3 = one semitone up, etc.
	_combo_audio.pitch_scale = pow(1.0595, current_combo - 2)
	_combo_audio.play()


# --- Floating score label ---

func _combo_color(combo: int) -> Color:
	# Bronze → silver → gold gradient based on combo depth
	var bronze := Color(0.804, 0.498, 0.196)  # #CD7F32
	var silver := Color(0.753, 0.753, 0.753)  # #C0C0C0
	var gold   := Color(1.0,   0.843, 0.0)    # #FFD700
	if combo <= 1:
		return bronze
	elif combo <= 5:
		return bronze.lerp(silver, (combo - 1) / 4.0)
	elif combo <= 10:
		return silver.lerp(gold, (combo - 5) / 5.0)
	else:
		return gold


func _spawn_score_label(world_pos: Vector2, amount: int) -> void:
	if amount <= 0:
		return

	# Node2D anchors the label to world space so it stays at the kill position
	# as the camera pans. Scale is inverted against camera zoom so the label
	# always renders at a consistent pixel size regardless of zoom level.
	var node := Node2D.new()
	node.global_position = world_pos
	var camera := get_viewport().get_camera_2d()
	if camera:
		node.scale = Vector2.ONE / camera.zoom
	get_tree().current_scene.add_child(node)

	var label := Label.new()
	label.text = "+%d" % amount
	label.size = Vector2(200, 50)
	label.position = Vector2(-100, -80)  # centered above kill point in local space
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", _combo_color(combo_count))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	node.add_child(label)

	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "global_position:y", world_pos.y - 120.0, 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.chain().tween_callback(node.queue_free)


# --- Wave Multiplier ---

func _on_wave_completed(_wave_number: int) -> void:
	if wave_multiplier < MULTIPLIER_CAP:
		wave_multiplier = mini(wave_multiplier * 2, MULTIPLIER_CAP)
	multiplier_changed.emit(wave_multiplier)
	print("[ScoreManager] Wave complete, multiplier x%d" % wave_multiplier)


func _on_player_health_changed(old_health: int, new_health: int) -> void:
	if new_health < old_health and wave_multiplier > 1:
		wave_multiplier = 1
		multiplier_changed.emit(wave_multiplier)
		print("[ScoreManager] Damage taken, multiplier reset to x1")
