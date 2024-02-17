class_name PropellerMovement
extends Node

@export var body: RigidBody2D
@export var particles: CPUParticles2D
@export var light: PointLight2D
@export var profile: PropellerMovementProfile
@export var action: StringName
@export var position: Vector2

func _physics_process(delta):
	var active = Input.is_action_pressed(action)
	
	if particles:
		particles.emitting = active
		
	if light:
		light.enabled = active
		
	if active:
		body.apply_force(
			profile.vector.rotated(body.rotation) * profile.thrust * delta * 100,
			position.rotated(body.rotation)
		)
	pass
