class_name RpgWeapon
extends MountableWeapon

const LOCK_TIME: float = 1.5
const CONE_ANGLE: float = PI / 6.0   # 30° half-angle = 60° total cone
const LOCK_RANGE: float = 3000.0

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
	var enemies = get_tree().get_nodes_in_group("enemy")
	var best: Node2D = null
	var best_dist: float = LOCK_RANGE

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dir_to_enemy: Vector2 = (enemy.global_position - global_position).normalized()
		var forward: Vector2 = Vector2.from_angle(global_rotation)
		var angle: float = forward.angle_to(dir_to_enemy)
		var dist: float = global_position.distance_to(enemy.global_position)

		if abs(angle) <= CONE_ANGLE and dist <= best_dist:
			best = enemy
			best_dist = dist

	return best

func _clear_lock() -> void:
	_lock_target = null
	_lock_progress = 0.0
	locked = false

func fire() -> void:
	if not can_shoot():
		return
	super()   # spawns bullet via MountableWeapon.fire()

	if muzzle_flash:
		muzzle_flash.restart()

	# If locked, pass target to the just-spawned bullet
	if locked and is_instance_valid(_lock_target):
		# Bullet was add_child'd deferred — access via spawn_parent children
		# Use call_deferred to ensure it's in the tree first
		call_deferred("_assign_bullet_target")

	# Camera shake for heavy weapon (D-27)
	fired_heavy.emit()

func _assign_bullet_target() -> void:
	if not spawn_parent or not is_instance_valid(_lock_target):
		return
	var children = spawn_parent.get_children()
	if children.is_empty():
		return
	var bullet = children.back()
	if bullet.has_method("set_target"):
		bullet.set_target(_lock_target)
