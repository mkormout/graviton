class_name WeaponHud
extends CanvasLayer

@onready var _panel: Panel = $Panel
@onready var _weapon_name: Label = $Panel/VBox/WeaponName
@onready var _ammo_label: Label = $Panel/VBox/AmmoLabel
@onready var _reload_bar: ProgressBar = $Panel/VBox/ReloadBar
@onready var _charge_bar: ProgressBar = $Panel/VBox/ChargeBar
@onready var _lock_bracket: Control = $LockBracket

var _ship: MountableBody = null
var _mount_front: MountPoint = null
var _initialized: bool = false

func _ready() -> void:
	_reload_bar.visible = false
	_charge_bar.visible = false
	if _lock_bracket:
		_lock_bracket.visible = false

func connect_to_ship(ship: MountableBody) -> void:
	_ship = ship
	_mount_front = null
	_initialized = false

func _process(_delta: float) -> void:
	if not _ship:
		return

	if not _initialized:
		_mount_front = _ship.get_mount("")
		_initialized = true
		return

	if not _mount_front:
		return

	var weapon = _mount_front.body_opposite
	if not weapon or not is_instance_valid(weapon):
		_panel.visible = false
		return

	_panel.visible = true
	_weapon_name.text = weapon.name
	_ammo_label.text = "%d / %d" % [weapon.magazine_current, weapon.ammo_current]

	# Reload bar
	if weapon.is_reloading():
		_reload_bar.visible = true
		var elapsed: float = weapon.reload_time - weapon.reload_timer.time_left
		_reload_bar.value = clampf(elapsed / weapon.reload_time, 0.0, 1.0)
	else:
		_reload_bar.visible = false

	# Charge / spool bar
	if weapon.has_method("get_charge_fraction"):
		_charge_bar.visible = true
		_charge_bar.value = weapon.get_charge_fraction()
	elif weapon.has_method("get_spool"):
		_charge_bar.visible = true
		_charge_bar.value = weapon.get_spool()
	else:
		_charge_bar.visible = false

	# RPG lock bracket — duck-type check before cast (T-18-10-04)
	if _lock_bracket:
		if weapon.has_method("_scan_cone"):
			var rpg = weapon as RpgWeapon
			if rpg and is_instance_valid(rpg) and rpg.lock_target and is_instance_valid(rpg.lock_target):
				var world_pos: Vector2 = rpg.lock_target.global_position
				var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
				_lock_bracket.position = screen_pos - _lock_bracket.size / 2.0
				_lock_bracket.visible = true
				# Bracket shrinks as lock builds: 120px at 0.0 → 30px at 1.0
				var bracket_size: float = lerp(120.0, 30.0, rpg.lock_progress)
				_lock_bracket.custom_minimum_size = Vector2(bracket_size, bracket_size)
			else:
				_lock_bracket.visible = false
		else:
			_lock_bracket.visible = false
