class_name WaveManager
extends Node

signal wave_started(wave_number: int, enemy_count: int, label_text: String)
signal enemy_count_changed(remaining: int, total: int)
signal all_waves_complete()
signal countdown_tick(seconds_remaining: int)
signal wave_completed(wave_number: int)
signal wave_cleared_waiting(wave_number: int)

## Array of wave definitions.
## New format: { "label": String, "groups": [SpawnGroup, ...] }
## Legacy format also accepted: { "enemy_scene": PackedScene, "count": int }
##
## SpawnGroup fields (all optional unless noted):
##   enemy_scene:    PackedScene   REQUIRED
##   count:          int           REQUIRED
##   speed_tier:     float         default 1.0
##
##   spawn_at:       float (sec)   default 0.0   — wall-clock seconds from wave start
##   stagger:        float (sec)   default 0.0   — drip count enemies uniformly over `stagger` seconds
##
##   position_mode:  String        default "exact"     — "exact" | "random"
##   distance:       float                          — used when position_mode == "exact"; if omitted, legacy formula
##   distance_min:   float                          — used when position_mode == "random" (REQUIRED in random mode)
##   distance_max:   float                          — used when position_mode == "random" (REQUIRED in random mode)
##
##   angle_mode:     String        default "full"      — "full" | "arc"
##   angle_center:   float (rad)   default 0.0   — WORLD radians (0 = world +X = right; -PI/2 = up). NOT relative to player heading.
##   angle_width:    float (rad)   default PI/2 (only meaningful when angle_mode == "arc")
##
##   cluster_radius: float (px)    default 0.0   — WORLD UNITS, NOT radians. >0 picks ONE base angle per group spawn pass and offsets each enemy by ±(cluster_radius/radius) rad (small-angle approx).
##
##   initial_state:  String        default "IDLING"    — must match an EnemyShip.State enum key. Naming chosen to mirror `current_state` (NOT `status`, which collides with alive/dead semantics in many codebases).
##     Allowed: IDLING, SEEKING, LURKING, FIGHTING, FLEEING, PATROLLING, EVADING, ESCORTING.
##     NOTE: each concrete enemy type implements its own subset of states. Setting initial_state on the wrong type may do nothing useful — wave author's responsibility.
@export var waves: Array = []
@export var spawn_radius_margin: float = 1000.0
## Spread enemy spawns across multiple frames to avoid the broadphase spike
## from 250 instantiate()+add_child() calls hitting in a single frame.
## Tune in Inspector if you ever raise enemy counts further.
@export var spawn_batch_size: int = 10

var _current_wave_index: int = 0
var _enemies_alive: int = 0
var _wave_total: int = 0
var _player: Node2D = null
# Incremented at the start of trigger_wave AND in reset(); checked after every
# await in trigger_wave so a mid-spawn reset() cleanly abandons the coroutine.
var _wave_token: int = 0

func _ready() -> void:
	call_deferred("_find_player")

func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		push_warning("[WaveManager] No node in group 'player' found")

func trigger_wave() -> void:
	# `await` inside this function makes it return a Signal, but callers
	# don't need to await it — spawning continues in the background.
	if waves.is_empty():
		push_warning("[WaveManager] No waves configured")
		return
	if _current_wave_index >= waves.size():
		print("[WaveManager] All %d waves complete" % waves.size())
		return
	if _enemies_alive > 0:
		print("[WaveManager] Wave still in progress (%d enemies alive)" % _enemies_alive)
		return

	_wave_token += 1
	var my_token: int = _wave_token

	var wave: Dictionary = waves[_current_wave_index]

	# Backwards-compat: single enemy_scene format
	var groups: Array = []
	if wave.has("enemy_scene"):
		groups = [{ "enemy_scene": wave.get("enemy_scene"), "count": wave.get("count", 1) }]
	else:
		groups = wave.get("groups", [])

	if groups.is_empty():
		push_warning("[WaveManager] Wave %d has no groups or enemy_scene" % _current_wave_index)
		return

	var total_count: int = 0
	for group in groups:
		total_count += group.get("count", 0)

	if total_count == 0:
		push_warning("[WaveManager] Wave %d has zero enemies" % _current_wave_index)
		return

	# Build label text
	var label_text: String = wave.get("label", "")
	if label_text.is_empty():
		label_text = "Wave %d" % (_current_wave_index + 1)

	print("[WaveManager] Starting wave %d: %d enemies — %s" % [_current_wave_index, total_count, label_text])
	_enemies_alive = total_count
	_wave_total = total_count
	_current_wave_index += 1
	wave_started.emit(_current_wave_index, total_count, label_text)

	# Stable sort by spawn_at ascending; legacy groups (no spawn_at) treated as 0.0
	# and remain in declaration order due to stable sort.
	var sorted_groups: Array = groups.duplicate()
	sorted_groups.sort_custom(func(a, b): return a.get("spawn_at", 0.0) < b.get("spawn_at", 0.0))

	var elapsed: float = 0.0
	var spawned_in_frame: int = 0
	for group in sorted_groups:
		var enemy_scene: PackedScene = group.get("enemy_scene")
		var count: int = group.get("count", 0)
		if not enemy_scene:
			push_warning("[WaveManager] Group in wave %d has no enemy_scene" % (_current_wave_index - 1))
			continue

		var group_spawn_at: float = group.get("spawn_at", 0.0)
		var wait: float = group_spawn_at - elapsed
		if wait > 0.001:
			await get_tree().create_timer(wait).timeout
			if my_token != _wave_token:
				return
			elapsed += wait

		var base_angle: float = _resolve_base_angle(group)

		var stagger_total: float = group.get("stagger", 0.0)
		var per_enemy_delay: float = 0.0
		if stagger_total > 0.0 and count > 1:
			per_enemy_delay = stagger_total / float(count - 1)

		for i in range(count):
			_spawn_enemy(group, base_angle)
			spawned_in_frame += 1
			if spawned_in_frame >= spawn_batch_size:
				spawned_in_frame = 0
				await get_tree().process_frame
				if my_token != _wave_token:
					return
			if per_enemy_delay > 0.0 and i < count - 1:
				await get_tree().create_timer(per_enemy_delay).timeout
				if my_token != _wave_token:
					return
				spawned_in_frame = 0

func _spawn_enemy(group: Dictionary, base_angle: float) -> void:
	var enemy_scene: PackedScene = group.get("enemy_scene")
	var speed_tier: float = group.get("speed_tier", 1.0)
	var enemy := enemy_scene.instantiate()

	# Set speed_tier BEFORE add_child so _ready() receives it
	if speed_tier != 1.0 and enemy.get("speed_tier") != null:
		enemy.speed_tier = speed_tier

	# Connect tree_exiting BEFORE add_child to avoid race condition
	# (if enemy dies in _ready, signal still fires)
	enemy.tree_exiting.connect(_on_enemy_tree_exiting)

	enemy.add_to_group("enemy")

	# Register with ScoreManager for kill scoring (Phase 11)
	if ScoreManager:
		ScoreManager.register_enemy(enemy)

	# Add to world (WaveManager's parent)
	get_parent().add_child(enemy)

	# Set position AFTER add_child (global_position only valid in tree)
	enemy.global_position = _get_spawn_position(group, base_angle)

	# Propagate spawn_parent so bullets and loot drop into the world
	get_parent().setup_spawn_parent(enemy)

	var state_name: String = group.get("initial_state", "IDLING")
	if state_name != "IDLING":
		if state_name in EnemyShip.State.keys():
			# _change_state is private-by-convention but it IS the canonical
			# transition function (handles _exit_state / current_state /
			# _enter_state and the DetectionArea teardown when leaving IDLING).
			enemy._change_state(EnemyShip.State[state_name])
		else:
			push_warning("[WaveManager] unknown initial_state '%s' — leaving in IDLING" % state_name)

func _resolve_base_angle(group: Dictionary) -> float:
	var angle_mode: String = group.get("angle_mode", "full")
	if angle_mode == "arc":
		var angle_center: float = group.get("angle_center", 0.0)
		var angle_width: float = group.get("angle_width", PI / 2.0)
		return randf_range(angle_center - angle_width / 2.0, angle_center + angle_width / 2.0)
	if angle_mode != "full":
		push_warning("[WaveManager] unknown angle_mode '%s' — falling back to 'full'" % angle_mode)
	return randf() * TAU

func _get_spawn_position(group: Dictionary, base_angle: float) -> Vector2:
	if not _player:
		return Vector2.ZERO

	var radius: float = _resolve_distance(group)
	var angle: float = _resolve_angle(group, base_angle, radius)
	return _player.global_position + Vector2.from_angle(angle) * radius

func _resolve_distance(group: Dictionary) -> float:
	# Viewport 1920x1080 at default zoom 0.2 -> visible ~9600x5400 units
	# Half-diagonal ~5510 units. base_radius = 5510 + margin (default 1000) = 6510
	# Legacy formula (used as fallback): base_radius + randf_range(0, 500) jitter prevents stacking.
	# When `distance` is provided explicitly under position_mode "exact", we honor it WITHOUT jitter
	# — the user wants `exact` to mean exact.
	var position_mode: String = group.get("position_mode", "exact")
	if position_mode == "random":
		if group.has("distance_min") and group.has("distance_max"):
			var dmin: float = group.get("distance_min")
			var dmax: float = group.get("distance_max")
			if dmin <= dmax:
				return randf_range(dmin, dmax)
			push_warning("[WaveManager] position_mode 'random' has distance_min > distance_max — falling back to legacy formula")
		else:
			push_warning("[WaveManager] position_mode 'random' missing distance_min/distance_max — falling back to legacy formula")
		return 5510.0 + spawn_radius_margin + randf_range(0.0, 500.0)
	if position_mode != "exact":
		push_warning("[WaveManager] unknown position_mode '%s' — treating as 'exact'" % position_mode)
	if group.has("distance"):
		return group.get("distance")
	return 5510.0 + spawn_radius_margin + randf_range(0.0, 500.0)

func _resolve_angle(group: Dictionary, base_angle: float, radius: float) -> float:
	var cluster_radius: float = group.get("cluster_radius", 0.0)
	if cluster_radius > 0.0:
		var spread: float = cluster_radius / radius
		return base_angle + randf_range(-spread, spread)
	var angle_mode: String = group.get("angle_mode", "full")
	if angle_mode == "arc":
		var angle_center: float = group.get("angle_center", 0.0)
		var angle_width: float = group.get("angle_width", PI / 2.0)
		return randf_range(angle_center - angle_width / 2.0, angle_center + angle_width / 2.0)
	if angle_mode != "full":
		push_warning("[WaveManager] unknown angle_mode '%s' — treating as 'full'" % angle_mode)
	return randf() * TAU

func _on_enemy_tree_exiting() -> void:
	_enemies_alive = max(0, _enemies_alive - 1)
	print("[WaveManager] Enemy died, remaining: %d" % _enemies_alive)
	enemy_count_changed.emit(_enemies_alive, _wave_total)
	if _enemies_alive == 0:
		_on_wave_complete()

func _on_wave_complete() -> void:
	print("[WaveManager] Wave %d complete!" % (_current_wave_index))
	wave_completed.emit(_current_wave_index)
	if _current_wave_index >= waves.size():
		all_waves_complete.emit()
	else:
		wave_cleared_waiting.emit(_current_wave_index)

func reset() -> void:
	_wave_token += 1
	_current_wave_index = 0
	_enemies_alive = 0
	_wave_total = 0
	print("[WaveManager] Reset to Wave 1")
