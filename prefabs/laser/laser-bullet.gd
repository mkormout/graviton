class_name LaserBullet
extends CharacterBody2D

@export var attack: Damage
@export var life: float = 2.0
@export var max_bounces: int = 3
@export var spread_angle: float = 0.15  # radians (~8.6°)
@export var bounce_flash_scene: PackedScene

# Set by LaserWeapon.fire() so children can instantiate from the full scene (with CollisionShape2D)
var bullet_scene: PackedScene
var spawn_parent: Node
var bounce_count: int = 0
# Initial bullets skip the shooter; bounced children leave this null to allow self-hits.
var shooter: Node2D = null

func _ready() -> void:
	# Layer 3 (bullets) = value 4. Mask: layer 1 (ships=1) + layer 4 (asteroids=8).
	# Exclude layer 2 (weapons=2) — avoids immediate self-collision with barrel on spawn.
	collision_layer = 4
	collision_mask = 1 | 8
	if shooter:
		add_collision_exception_with(shooter)
	get_tree().create_timer(life).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision:
		_on_impact(collision)

func _on_impact(collision: KinematicCollision2D) -> void:
	var hit_body = collision.get_collider()

	# Deal full damage on every hit (D-18)
	if hit_body is Body and attack:
		hit_body.damage(attack)

	# Green flash at contact point (D-19)
	_spawn_flash(collision.get_position())

	if bounce_count >= max_bounces:
		queue_free()
		return

	# Reflect and spread (D-17)
	var normal: Vector2 = collision.get_normal()
	var reflected: Vector2 = velocity.bounce(normal)

	for i in range(2):
		var spread: float = randf_range(-spread_angle, spread_angle)
		_spawn_child(reflected.rotated(spread))

	queue_free()

func _spawn_child(new_velocity: Vector2) -> void:
	if not bullet_scene:
		push_warning("LaserBullet: bullet_scene not set, cannot spawn bounce child")
		return
	var child: LaserBullet = bullet_scene.instantiate() as LaserBullet
	child.bullet_scene = bullet_scene
	child.spawn_parent = spawn_parent
	child.bounce_count = bounce_count + 1
	child.velocity = new_velocity
	child.global_position = global_position
	child.rotation = new_velocity.angle()
	if spawn_parent:
		spawn_parent.call_deferred("add_child", child)
	else:
		push_warning("LaserBullet: spawn_parent not set, cannot spawn bounce child")

func _spawn_flash(pos: Vector2) -> void:
	if not bounce_flash_scene:
		return
	var fx = bounce_flash_scene.instantiate()
	fx.global_position = pos
	if spawn_parent:
		spawn_parent.call_deferred("add_child", fx)
