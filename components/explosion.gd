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
@export var debris_damp: float = 0
@export var hit_ships: bool = false
@export var spawn_parent: Node

var area: Area2D

# Float-counter replacement for SceneTreeTimer in die() (perf: avoid one timer per explosion).
# -1.0 = inactive; 0.0 = free next tick; >0.0 = counting down.
var _die_left: float = -1.0

func _ready():
	# First-spawn path: Area2D not yet built. On pool re-acquire the Area2D
	# already exists — _pool_reset() runs initialize() only when needed.
	if area == null:
		initialize()
	_arm()
	die(time)

# Extracted arming: re-enable particles/audio/area on both first-spawn and
# pool re-acquire so the explosion fires each time it's consumed.
func _arm() -> void:
	if particles:
		particles.emitting = true
		particles.restart()
	if audio:
		audio.play()
	if area:
		area.monitoring = true

func _pool_reset() -> void:
	# Reset the death counter and visual/audio state for reuse. The Area2D
	# is kept across reuses (created once in initialize via call_deferred);
	# monitoring is re-enabled inside _arm().
	_die_left = -1.0
	if area:
		area.monitoring = false
	if particles:
		particles.emitting = false
	# _ready will NOT re-run on pool reuse; emulate its remaining behaviour
	# by re-arming and scheduling the next die().
	call_deferred("_on_reacquired")

func _on_reacquired() -> void:
	# Deferred post-acquire. _pool_reset queues this via call_deferred *before*
	# the consumer's own call_deferred("add_child", ...), so the consumer's
	# add_child may not have flushed yet — explode() awaits get_tree()
	# .physics_frame and would crash on a detached node. Re-defer until the
	# node has been reparented.
	if not is_inside_tree():
		call_deferred("_on_reacquired")
		return
	_arm()
	explode()
	die(time)

func _physics_process(delta):
	update_light(delta)
	if _die_left >= 0.0:
		_die_left -= delta
		if _die_left <= 0.0:
			_release()

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
	if hit_ships:
		area.set_collision_mask_value(1, true)

	call_deferred("add_child", area)

	if particles:
		particles.emitting = true

	if audio:
		audio.play()

func update_light(_delta):
	if light:
		light.energy -= light.energy / (25 * time)

func explode():
	# Yield ~2 physics frames so the Area2D (added via call_deferred in initialize())
	# is in the scene tree and has detected overlapping bodies for apply_shockwave().
	# (Was: await get_tree().create_timer(0.1).timeout — created a SceneTreeTimer per explosion.)
	await get_tree().physics_frame
	await get_tree().physics_frame

	generate_debris()
	apply_shockwave()

func generate_debris():
	var MIN_RANGE = 0
	var MAX_RANGE = radius
	var MAX_ANGULAR_VELOCITY = PI / 2

	for i in range(debris_count):
		var model = debris.pick_random()
		# Debris scenes are pooled only if explicitly registered in PoolManager;
		# otherwise fall back to instantiate() (current scenes register no debris).
		var node: RigidBody2D
		if PoolManager.is_pooled(model):
			node = PoolManager.acquire(model) as RigidBody2D
		else:
			node = model.instantiate() as RigidBody2D
		node.global_position = position + Vector2.from_angle(randf() * 2*PI) * randf_range(MIN_RANGE, MAX_RANGE)
		node.rotation = randf_range(0, 2*PI)
		node.angular_velocity = MAX_ANGULAR_VELOCITY * randi_range(-1, 1)
		node.angular_damp = debris_damp
		node.linear_damp = debris_damp
		if spawn_parent:
			spawn_parent.call_deferred("add_child", node)
		else:
			push_warning("spawn_parent not set on " + name)

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
		damage.energy = attack.energy if attack else 0.0
		damage.kinetic = attack.kinetic if attack else 0.0

		var distance = (body.global_position - global_position).length()
		var strength = 1 - min(distance / radius, 1)

		damage.energy = damage.energy * strength
		damage.kinetic = damage.kinetic * strength

		body.damage(damage)

func die(delay: float):
	# Schedule queue_free after `delay` seconds via the _die_left counter ticked
	# in _physics_process. (Was: await get_tree().create_timer(delay).timeout —
	# created a SceneTreeTimer per explosion.)
	_die_left = delay

# Pool-aware self-release. If this scene is registered with PoolManager,
# return to the pool (disabling monitoring so the Area2D doesn't keep
# firing while asleep). Otherwise fall back to queue_free.
func _release() -> void:
	_die_left = -1.0
	if area:
		area.monitoring = false
	var scene = get_meta("_pool_scene", null)
	if scene != null and PoolManager.is_pooled(scene):
		PoolManager.release(self)
	else:
		queue_free()
