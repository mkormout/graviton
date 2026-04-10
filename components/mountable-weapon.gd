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

var reload_timer: Timer
var shot_timer: Timer
var magazine_current: int
var ammo_current: int

func _ready() -> void:
	shot_timer = Timer.new()
	shot_timer.wait_time = rate
	shot_timer.one_shot = true
	add_child(shot_timer)

	reload_timer = Timer.new()
	reload_timer.wait_time = reload_time
	reload_timer.one_shot = true
	add_child(reload_timer)

	magazine_current = magazine_max
	ammo_current = ammo_max

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
	return not reload_timer.is_stopped()

func is_cooldown() -> bool:
	return not shot_timer.is_stopped()

func can_shoot() -> bool:
	return not is_cooldown() and not is_reloading() and has_ammo()

func reload() -> void:
	if is_reloading():
		return
	reload_timer.start()
	reload_timer.timeout.connect(reloaded, CONNECT_ONE_SHOT)
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
			shot_timer.start(rate)

		if use_ammo:
			magazine_current -= 1

		var mount = get_mount("")
		if mount:
			mount.do(self, Action.RECOIL, recoil)
