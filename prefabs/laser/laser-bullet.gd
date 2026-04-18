class_name LaserBullet
extends CharacterBody2D

@export var attack: Damage
@export var life: float = 2.0
@export var max_bounces: int = 3
@export var spread_angle: float = 0.15  # radians (~8.6°)
@export var bounce_flash_scene: PackedScene

var spawn_parent: Node
var bounce_count: int = 0

func _ready() -> void:
	# Explicit collision layers: layer 3 (bullets), mask 1+2+8 (ships, weapons, asteroids)
	collision_layer = 4      # bit 3 = layer 3
	collision_mask = 1 | 2 | 8  # bit 1 (ships), bit 2 (weapons), bit 4 (asteroids)
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
	var child: LaserBullet = LaserBullet.new()
	child.attack = attack
	child.life = life
	child.max_bounces = max_bounces
	child.spread_angle = spread_angle
	child.bounce_flash_scene = bounce_flash_scene
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
