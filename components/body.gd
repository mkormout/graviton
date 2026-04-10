class_name Body extends RigidBody2D

@export var max_health: int = 1
@export var can_die = true
@export var defense: Damage
@export var death: PackedScene
@export var successors: Array[PackedScene]
@export var successors_count: int = 3
@export var successors_damp: float = 0
@export var item_dropper: ItemDropper
@export var spawn_parent: Node

var health: int
var dying = false

func _ready():
	health = max_health

func damage(attack: Damage):
	if not can_die or not attack:
		return

	var total = attack.calculate(defense)

	health += total

	# print("damage: ", total, "; health: ", health)

	if health <= 0:
		die()

func die(delay: float = 0.0):
	if dying:
		return

	if delay:
		await get_tree().create_timer(delay).timeout

	dying = true

	if death:
		var node = death.instantiate()
		node.global_position = global_position
		node.spawn_parent = spawn_parent
		if spawn_parent:
			spawn_parent.add_child(node)
		else:
			push_warning("spawn_parent not set on " + name)

	if not successors.is_empty():
		for i in range(successors_count):
			add_successor(successors.pick_random(), 200, 2000)

	if item_dropper:
		item_dropper.drop()

	queue_free()

func _propagate_spawn_parent(node: Node) -> void:
	if "spawn_parent" in node:
		node.spawn_parent = spawn_parent
	for child in node.get_children():
		_propagate_spawn_parent(child)

func add_successor(model: PackedScene, radius: int = 200, speed: int = 1000):
	if not model:
		return
	var successor = model.instantiate() as RigidBody2D
	successor.position = position + Vector2(randi_range(-radius, radius), randi_range(-radius, radius))
	successor.rotation = randi_range(0, 360)
	successor.linear_velocity = Vector2(randi_range(-speed, speed), randi_range(-speed, speed))
	successor.angular_velocity = randi_range(-5, 5)
	successor.angular_damp = successors_damp
	successor.linear_damp = successors_damp

	_propagate_spawn_parent(successor)
	if spawn_parent:
		spawn_parent.call_deferred("add_child", successor)
	else:
		push_warning("spawn_parent not set on " + name)
