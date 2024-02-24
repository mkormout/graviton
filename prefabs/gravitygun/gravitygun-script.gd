class_name GravityGun
extends MountableWeapon

@export var area: Area2D
@export var strength: int = 20000
@export var torque: int = 2000000
@export var attack: Damage

func fire():
	if not can_shoot():
		return
		
	super()
		
	apply_damage()
	
	await get_tree().create_timer(0.1).timeout 
	
	apply_kickback()

func apply_kickback():
	var bodies = area.get_overlapping_bodies()
	for item in bodies:
		if not item is RigidBody2D:
			continue
		
		var body = item as RigidBody2D	
			
		var direction = (body.global_position - global_position).normalized()
		var distance = (body.global_position - global_position).length()
		var impulse = direction * distance * strength
		
		body.apply_central_impulse(impulse)
		body.apply_torque_impulse(randf_range(-1, 1) * distance * torque)

func apply_damage():
	var bodies = area.get_overlapping_bodies()
	for item in bodies:
		if not item is Body:
			continue
		
		var body = item as RigidBody2D
		
		var damage = Damage.new()
		damage.energy = attack.energy if attack else 0.0
		damage.kinetic = attack.kinetic if attack else 0.0
		
		var distance = (body.global_position - global_position).length()
		var strength = 1 - min(distance / strength, 1)
		
		damage.energy = damage.energy * strength
		damage.kinetic = damage.kinetic * strength
		
		body.damage(damage)
