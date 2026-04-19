class_name LaserWeapon
extends MountableWeapon

@export var muzzle_flash: CPUParticles2D

func fire() -> void:
	if not ammo or not barrel:
		push_warning("LaserWeapon %s: ammo or barrel not configured" % name)
		return
	if not has_ammo() and not is_reloading():
		if empty_sound and not empty_sound.playing:
			empty_sound.play()
		return
	if not can_shoot():
		return

	if muzzle_flash:
		muzzle_flash.restart()

	# LaserBullet is CharacterBody2D — cannot cast to RigidBody2D; set velocity directly
	var instance := ammo.instantiate() as Node2D
	instance.global_position = barrel.global_position
	instance.rotation = global_rotation
	var dir := Vector2.from_angle(global_rotation + randf_range(-spread, spread))
	if "velocity" in instance:
		instance.velocity = dir * velocity
	if "bullet_scene" in instance:
		instance.bullet_scene = ammo
	if "spawn_parent" in instance:
		instance.spawn_parent = spawn_parent
	if "shooter" in instance:
		instance.shooter = get_ship()
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
