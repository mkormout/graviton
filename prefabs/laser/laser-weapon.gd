class_name LaserWeapon
extends MountableWeapon

@export var muzzle_flash: CPUParticles2D

func fire() -> void:
	if not can_shoot():
		return
	if muzzle_flash:
		muzzle_flash.restart()
	super()
