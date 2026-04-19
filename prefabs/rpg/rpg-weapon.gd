class_name RpgWeapon
extends MountableWeapon

const LOCK_TIME: float = 1.0
const CONE_ANGLE: float = PI / 4.0   # 45° half-angle = 90° total cone (50% wider)
const LOCK_RANGE: float = 30000.0

@export var muzzle_flash: CPUParticles2D

signal fired_heavy  # Connected to BodyCamera.shake() in world.gd (plan 18-10)

var _lock_target: Node2D = null
var _lock_progress: float = 0.0   # 0.0 → 1.0
var locked: bool = false

# Exposed for HUD (plan 18-10)
var lock_target: Node2D:
	get: return _lock_target
var lock_progress: float:
	get: return _lock_progress

func _process(delta: float) -> void:
	_update_lock(delta)

func _update_lock(delta: float) -> void:
	# Validate existing target
	if _lock_target and not is_instance_valid(_lock_target):
		_clear_lock()
		return

	var candidate: Node2D = _scan_cone()

	if candidate == null:
		# Fade lock progress when no target in cone
		_lock_progress = max(0.0, _lock_progress - delta * 2.0)
		if _lock_progress <= 0.0:
			_clear_lock()
		return

	if candidate != _lock_target:
		_lock_target = candidate
		_lock_progress = 0.0
		locked = false

	_lock_progress = min(_lock_progress + delta / LOCK_TIME, 1.0)
	locked = _lock_progress >= 1.0

func _scan_cone() -> Node2D:
	# Collect targets already claimed by other RpgWeapon instances
	var claimed: Array = []
	for node in get_tree().get_nodes_in_group("player"):
		for child in node.get_children():
			_collect_claimed_targets(child, claimed)

	var best: Node2D = _scan_group("enemy", claimed)
	if best:
		return best
	# No enemy in cone — fall back to asteroids (lower priority)
	return _scan_group("asteroid", claimed)

func _scan_group(group: String, claimed: Array) -> Node2D:
	var best: Node2D = null
	var best_dist: float = LOCK_RANGE
	var forward: Vector2 = Vector2.from_angle(global_rotation)

	for node in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(node):
			continue
		if node in claimed and node != _lock_target:
			continue
		var dir: Vector2 = (node.global_position - global_position).normalized()
		var dist: float = global_position.distance_to(node.global_position)
		if abs(forward.angle_to(dir)) <= CONE_ANGLE and dist <= best_dist:
			best = node
			best_dist = dist

	return best

func _collect_claimed_targets(node: Node, claimed: Array) -> void:
	if node is RpgWeapon and node != self and node._lock_target:
		claimed.append(node._lock_target)
	for child in node.get_children():
		_collect_claimed_targets(child, claimed)

func _clear_lock() -> void:
	_lock_target = null
	_lock_progress = 0.0
	locked = false

func fire() -> void:
	if not can_shoot():
		return

	# Spawn bullet directly (bypassing super) so we can capture the instance
	# reference and assign the homing target before it enters the scene tree.
	if not ammo or not barrel:
		push_warning("RpgWeapon %s: ammo or barrel not configured" % name)
		return

	var instance = ammo.instantiate() as RigidBody2D
	instance.global_position = barrel.global_position
	# When locked, aim directly at the target so the rocket starts on course.
	var fire_dir: Vector2 = Vector2.from_angle(global_rotation)
	if locked and is_instance_valid(_lock_target):
		fire_dir = (_lock_target.global_position - barrel.global_position).normalized()
	instance.rotation = fire_dir.angle()
	instance.linear_velocity = (
		Vector2.from_angle(fire_dir.angle() + randf_range(-spread, spread)) * velocity
	)
	if "spawn_parent" in instance:
		instance.spawn_parent = spawn_parent

	# Assign homing target synchronously before deferred add_child —
	# this avoids the deferred-queue race where _assign_bullet_target ran
	# before spawn_parent.add_child completed (different deferred queues).
	if locked and is_instance_valid(_lock_target) and instance.has_method("set_target"):
		instance.set_target(_lock_target)

	if spawn_parent:
		spawn_parent.call_deferred("add_child", instance)
	else:
		push_warning("spawn_parent not set on " + name)

	if sound:
		sound.play()

	if use_rate:
		shot_timer.start(rate)

	if use_ammo:
		magazine_current -= 1

	var mount = get_mount("")
	if mount:
		mount.do(self, Action.RECOIL, recoil)

	if muzzle_flash:
		muzzle_flash.restart()

	# Camera shake for heavy weapon (D-27)
	fired_heavy.emit()
