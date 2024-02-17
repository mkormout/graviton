class_name MountableWeapon
extends MountableBody

@export var ammo: PackedScene
@export var barrel: Node2D
@export var rate: float
@export var velocity: float
@export var spread: float
@export var sound: AudioStreamPlayer2D

var shot_timer: Timer

func _ready() -> void:
	shot_timer = Timer.new()
	shot_timer.one_shot = true
	add_child(shot_timer)
	pass
	
func can_shoot() -> bool:
	return shot_timer.is_stopped()

func do(action: String, where: String):
	if action == "fire":
		fire()
	pass

func fire():
	if can_shoot():
		var instance = ammo.instantiate() as RigidBody2D
		instance.position = barrel.position
		instance.apply_central_impulse(
			Vector2.from_angle(
				rotation + randf_range(-spread, spread)
			) * velocity,
		)
		add_child(instance)
		if sound:
			sound.play()
		shot_timer.start(rate)
	pass
