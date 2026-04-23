class_name MountableWeapon
extends MountableBody

@export_group("Resources")
@export var ammo: PackedScene
@export var barrel: Node2D
@export var sound: AudioStreamPlayer2D
@export var empty_sound: AudioStreamPlayer2D
@export var reload_sound: AudioStreamPlayer2D
@export var ammo_type: ItemType
@export_group("Firing")
@export var rate: float
@export var velocity: float
@export var spread: float
@export var recoil: float
@export_group("Ammo")
@export var magazine_max: int
@export var ammo_max: int
@export var reload_time: float
@export_group("God Mode")
@export var use_ammo: bool = true
@export var use_rate: bool = true

# Float-counter replacements for Timer nodes (perf: avoid SceneTree Timer overhead
# on every spawned weapon). Ticked in _physics_process(delta).
var shot_time_left: float = 0.0   # cooldown between shots; > 0 == on cooldown
var shot_wait_time: float = 0.0   # current cooldown duration (Minigun mutates this)
var reload_time_left: float = 0.0 # > 0 == reloading; reaches 0 -> reloaded() called
var magazine_current: int
var ammo_current: int

func _ready() -> void:
	shot_wait_time = rate
	magazine_current = magazine_max
	ammo_current = ammo_max

func _physics_process(delta: float) -> void:
	if shot_time_left > 0.0:
		shot_time_left -= delta
		if shot_time_left < 0.0:
			shot_time_left = 0.0
	if reload_time_left > 0.0:
		reload_time_left -= delta
		if reload_time_left <= 0.0:
			reload_time_left = 0.0
			reloaded()

func get_ship():
	var mount = get_mount()
	var body = null

	if mount:
		body = mount.body_opposite

	if body and body is Ship:
		return body as Ship
	else:
		return null

func has_ammo() -> bool:
	return magazine_current > 0

func is_reloading() -> bool:
	return reload_time_left > 0.0

func is_cooldown() -> bool:
	return shot_time_left > 0.0

func can_shoot() -> bool:
	return not is_cooldown() and not is_reloading() and has_ammo()

func reload() -> void:
	if is_reloading():
		return
	reload_time_left = reload_time
	if reload_sound:
		reload_sound.play()

func reloaded():
	magazine_current = min(magazine_max, ammo_current)
	ammo_current -= magazine_current

func do(_sender: Node2D, action: MountableBody.Action, _where: String, _meta = null):
	if action == MountableBody.Action.FIRE:
		fire()

	if action == MountableBody.Action.RELOAD:
		reload()

	if action == MountableBody.Action.GODMODE:
		use_ammo = false
		use_rate = false

	if action == MountableBody.Action.USE_AMMO:
		use_ammo = false

	if action == MountableBody.Action.USE_RATE:
		use_rate = false

func fire():
	if not ammo or not barrel:
		push_warning("MountableWeapon %s: ammo or barrel not configured" % name)
		return

	if not has_ammo() and not is_reloading():
		if empty_sound and not empty_sound.playing:
			empty_sound.play()
		return

	if can_shoot():
		var instance = ammo.instantiate() as RigidBody2D
		instance.position = barrel.global_position
		instance.rotation = global_rotation
		instance.apply_central_impulse(
			Vector2.from_angle(
				global_rotation + randf_range(-spread, spread)
			) * velocity,
		)
		if "spawn_parent" in instance:
			instance.spawn_parent = spawn_parent
		if spawn_parent:
			spawn_parent.call_deferred("add_child", instance)
		else:
			push_warning("spawn_parent not set on " + name)

		if sound:
			sound.play()

		if use_rate:
			shot_time_left = shot_wait_time

		if use_ammo:
			magazine_current -= 1

		var mount = get_mount("")
		if mount:
			mount.do(self, Action.RECOIL, recoil)
