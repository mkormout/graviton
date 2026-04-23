class_name Body extends RigidBody2D

signal died()
signal health_changed(old_health: int, new_health: int)

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

# Pool-aware lifecycle hook. Called by ScenePool when a pooled Body is
# re-acquired. Subclasses override but MUST chain via super(). We intentionally
# do not touch spawn_parent here — pool consumers reassign it after acquire.
func _pool_reset() -> void:
	dying = false
	health = max_health

# Pool-aware release. Bodies spawned via PoolManager.acquire carry the
# _pool_scene meta and return to the pool; anything else (e.g. successors
# from add_successor, or non-pooled bodies) falls back to queue_free.
func _release_to_pool_or_free() -> void:
	var scene = get_meta("_pool_scene", null)
	if scene != null and PoolManager.is_pooled(scene):
		PoolManager.release(self)
	else:
		queue_free()

func damage(attack: Damage):
	if not can_die or not attack:
		return

	var total = attack.calculate(defense)
	var old_health := health
	health += total

	# print("damage: ", total, "; health: ", health)

	if health < old_health:
		health_changed.emit(old_health, health)

	if health <= 0:
		die()

func die(delay: float = 0.0):
	if dying:
		return

	if delay > 0.0:
		# Yield N physics frames instead of creating a SceneTreeTimer per dying body
		# (can be dozens per wave). Preserves the `await` contract so subclasses
		# calling `super(delay)` behave identically.
		var frames := int(ceil(delay * Engine.physics_ticks_per_second))
		for _i in range(frames):
			await get_tree().physics_frame
		# After the await, another die() (e.g. collision vs. life) may have
		# already completed and released us back to the pool. Bail out to
		# avoid a double-release / double-death-scene spawn.
		if dying or not is_inside_tree():
			return

	dying = true

	if death:
		# Death scenes for pooled bullet types (*-bullet-explosion.tscn) go
		# through PoolManager. Ship/coin/asteroid explosions are one-off and
		# intentionally NOT pooled — fall back to instantiate() so we don't
		# build lazy pools for rarely-used scenes.
		var node: Node
		if PoolManager.is_pooled(death):
			node = PoolManager.acquire(death)
		else:
			node = death.instantiate()
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

	died.emit()
	_release_to_pool_or_free()

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
