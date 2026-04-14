class_name WaveManager
extends Node

signal wave_started(wave_number: int, enemy_count: int)
signal enemy_count_changed(remaining: int, total: int)
signal all_waves_complete()

## Array of wave definitions. Each Dictionary: { "enemy_scene": PackedScene, "count": int }
@export var waves: Array = []
@export var spawn_radius_margin: float = 1000.0

var _current_wave_index: int = 0
var _enemies_alive: int = 0
var _wave_total: int = 0
var _player: Node2D = null

func _ready() -> void:
	call_deferred("_find_player")

func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		push_warning("[WaveManager] No node in group 'player' found")

func trigger_wave() -> void:
	if waves.is_empty():
		push_warning("[WaveManager] No waves configured")
		return
	if _current_wave_index >= waves.size():
		print("[WaveManager] All %d waves complete" % waves.size())
		return
	if _enemies_alive > 0:
		print("[WaveManager] Wave still in progress (%d enemies alive)" % _enemies_alive)
		return

	var wave: Dictionary = waves[_current_wave_index]
	var enemy_scene: PackedScene = wave.get("enemy_scene")
	var count: int = wave.get("count", 1)

	if not enemy_scene:
		push_warning("[WaveManager] Wave %d has no enemy_scene" % _current_wave_index)
		return

	print("[WaveManager] Starting wave %d: %d enemies" % [_current_wave_index, count])
	_enemies_alive = count
	_wave_total = count
	_current_wave_index += 1
	wave_started.emit(_current_wave_index, count)

	for i in range(count):
		_spawn_enemy(enemy_scene)

func _spawn_enemy(enemy_scene: PackedScene) -> void:
	var enemy := enemy_scene.instantiate()

	# Connect tree_exiting BEFORE add_child to avoid race condition
	# (if enemy dies in _ready, signal still fires)
	enemy.tree_exiting.connect(_on_enemy_tree_exiting)

	enemy.add_to_group("enemy")

	# Add to world (WaveManager's parent)
	get_parent().add_child(enemy)

	# Set position AFTER add_child (global_position only valid in tree)
	enemy.global_position = _get_spawn_position()

	# Propagate spawn_parent so bullets and loot drop into the world
	get_parent().setup_spawn_parent(enemy)

func _get_spawn_position() -> Vector2:
	if not _player:
		return Vector2.ZERO
	# Viewport 1920x1080 at default zoom 0.2 -> visible ~9600x5400 units
	# Half-diagonal ~5510 units. base_radius = 5510 + margin (default 1000) = 6510
	var base_radius: float = 5510.0 + spawn_radius_margin
	# Per-spawn jitter (0-500 units) prevents enemies stacking at same radius
	var radius := base_radius + randf_range(0.0, 500.0)
	var angle := randf() * TAU
	return _player.global_position + Vector2.from_angle(angle) * radius

func _on_enemy_tree_exiting() -> void:
	_enemies_alive = max(0, _enemies_alive - 1)
	print("[WaveManager] Enemy died, remaining: %d" % _enemies_alive)
	enemy_count_changed.emit(_enemies_alive, _wave_total)
	if _enemies_alive == 0:
		_on_wave_complete()

func _on_wave_complete() -> void:
	print("[WaveManager] Wave %d complete!" % (_current_wave_index))
	if _current_wave_index >= waves.size():
		all_waves_complete.emit()
