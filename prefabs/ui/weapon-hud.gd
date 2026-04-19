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
# Maps weapon instance ID → bracket Control; one entry per locked RPG mount.
var _lock_brackets: Dictionary = {}

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

	# RPG lock brackets — one per mounted RPG that has an active lock target.
	if _lock_bracket and _ship:
		var active: Dictionary = {}
		for mount in _ship.get_mounts():
			var w = mount.body_opposite
			if not w or not is_instance_valid(w) or not w is RpgWeapon:
				continue
			var rpg := w as RpgWeapon
			if not rpg.lock_target or not is_instance_valid(rpg.lock_target):
				continue
			active[rpg.get_instance_id()] = rpg

		# Remove brackets for RPGs no longer targeting.
		for wid in _lock_brackets.keys():
			if wid not in active:
				_lock_brackets[wid].queue_free()
				_lock_brackets.erase(wid)

		# Create or update a bracket for each active RPG.
		for wid in active:
			var rpg: RpgWeapon = active[wid]
			if wid not in _lock_brackets:
				var b: Control = _lock_bracket.duplicate()
				b.visible = false
				_lock_bracket.get_parent().add_child(b)
				_lock_brackets[wid] = b
			var bracket: Control = _lock_brackets[wid]
			var screen_pos: Vector2 = get_viewport().get_canvas_transform() * rpg.lock_target.global_position
			# ease(t, 0.3): ease-out curve — fast shrink at start, slows near lock.
			var t: float = ease(rpg.lock_progress, 0.3)
			var bracket_size: float = lerp(360.0, 90.0, t)
			bracket.custom_minimum_size = Vector2(bracket_size, bracket_size)
			bracket.size = Vector2(bracket_size, bracket_size)
			bracket.pivot_offset = Vector2(bracket_size, bracket_size) / 2.0
			bracket.position = screen_pos - bracket.pivot_offset
			bracket.rotation = t * (PI / 2.0)
			bracket.modulate.a = lerp(0.3, 1.0, t)
			bracket.visible = true
