class_name Explosion
extends Node2D

@export var radius: float
@export var particles: CPUParticles2D
@export var light: Light2D
@export var audio: RandomAudioPlayer
@export var time: float = 1
@export var power: int = 0
@export var attack: Damage
@export var debris: Array[PackedScene] = []
@export var debris_count: int = 0

var area: Area2D

func _ready():
	initialize()
	explode()
	die(time)

func _physics_process(delta):
	update_light(delta)

func initialize():
	var circle = CircleShape2D.new()
	circle.radius = radius
	
	var collider = CollisionShape2D.new()
	collider.shape = circle

	area = Area2D.new()
	area.add_child(collider)
	area.set_collision_layer_value(5, true)
	area.set_collision_mask_value(1, false)
	area.set_collision_mask_value(2, false)
	area.set_collision_mask_value(3, false)
	area.set_collision_mask_value(4, true)
	
	add_child(area)
	
	if particles:
		particles.emitting = true
	
	if audio:
		audio.play()
	

func update_light(delta):
	if light:
		light.energy -= light.energy / (25 * time)

func explode():
	# correct behavior correction
	await get_tree().create_timer(0.1).timeout 
	
	generate_debris()
	apply_shockwave()

func generate_debris():
	var MIN_RANGE = 0
	var MAX_RANGE = radius
	var MAX_ANGULAR_VELOCITY = PI / 2
	
	for i in range(debris_count):
		var model = debris.pick_random()
		var node = model.instantiate() as RigidBody2D
		node.global_position = position + Vector2.from_angle(randf() * 2*PI) * randf_range(MIN_RANGE, MAX_RANGE)
		node.rotation = randf_range(0, 2*PI)
		node.angular_velocity = MAX_ANGULAR_VELOCITY * randi_range(-1, 1)
		node.angular_damp = -1
		node.linear_damp = 0
		get_tree().current_scene.call_deferred("add_child", node)
		
func apply_shockwave():
	var bodies = area.get_overlapping_bodies()
	
	for item in bodies:
		if item is RigidBody2D:
			apply_kickback(item as RigidBody2D)
		if item is Body:
			apply_damage(item as Body)


func apply_kickback(body: RigidBody2D):
		var direction = (body.global_position - global_position).normalized()
		var distance = (body.global_position - global_position).length()
		var impulse = direction * distance * power
		
		# print("kickback: ", impulse)
		
		body.apply_central_impulse(impulse)

func apply_damage(body: Body):
		var damage = Damage.new()
		damage.energy = attack.energy if attack else 0
		damage.kinetic = attack.kinetic if attack else 0
		
		var distance = (body.global_position - global_position).length()
		var strength = 1 - min(distance / radius, 1)
		
		damage.energy = damage.energy * strength
		damage.kinetic = damage.kinetic * strength
		
		body.damage(damage)

func die(delay: float):
	await get_tree().create_timer(delay).timeout 
	queue_free()
