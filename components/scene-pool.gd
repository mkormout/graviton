class_name ScenePool
extends Node

# Generic per-scene object pool.
#
# Holds a PackedScene and maintains:
#   _free: nodes currently not in use (children of this ScenePool, sleeping).
#   _live: counter of in-flight instances parented to the gameplay tree.
#
# Instances are reparented in and out of this ScenePool as they are acquired
# and released. When released they are put into a sleeping state (physics
# disabled, invisible, process_mode=DISABLED). When acquired the default
# reset is applied and `_pool_reset()` is invoked if present.
#
# First-ever acquire stores `_pool_scene` meta on the instance so any caller
# can find the owning pool via PoolManager.release(node).

var packed_scene: PackedScene
var initial_size: int
var _free: Array[Node] = []
var _live: int = 0
var _growth_warned: bool = false

static func build(scene: PackedScene, initial: int) -> ScenePool:
	var pool := ScenePool.new()
	pool.packed_scene = scene
	pool.initial_size = initial
	pool.name = "Pool_" + scene.resource_path.get_file().get_basename()
	return pool

func prewarm() -> void:
	if not packed_scene:
		push_error("ScenePool.prewarm: packed_scene is null")
		return
	for _i in range(initial_size):
		var node := packed_scene.instantiate()
		node.set_meta("_pool_scene", packed_scene)
		_prepare_for_sleep(node)
		add_child(node)
		_free.push_back(node)

func acquire() -> Node:
	var node: Node
	if _free.is_empty():
		node = packed_scene.instantiate()
		node.set_meta("_pool_scene", packed_scene)
		if not _growth_warned and (_live + 1) >= initial_size * 2:
			_growth_warned = true
			push_warning(
				"ScenePool grew past 2x initial for %s (initial=%d, live=%d)" %
				[packed_scene.resource_path, initial_size, _live + 1]
			)
	else:
		node = _free.pop_back()
		if node.get_parent() == self:
			remove_child(node)

	_apply_default_reset(node)
	if node.has_method("_pool_reset"):
		node.call("_pool_reset")
	_live += 1
	return node

func release(node: Node) -> void:
	if node == null:
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	_prepare_for_sleep(node)
	add_child(node)
	_free.push_back(node)
	_live = max(0, _live - 1)

func _prepare_for_sleep(node: Node) -> void:
	# process_mode=DISABLED pauses _process/_physics_process; collision_layer=0
	# and mask=0 prevent any collision detection. Together these keep parked
	# pool instances inert without touching RigidBody2D.freeze / .sleeping —
	# which desync between the Node and PhysicsServer2D state across pool
	# release/acquire and silently discard linear_velocity on re-entry.
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	if node is CollisionObject2D:
		# Parked bodies remain at their death position in world coords (reparent
		# preserves local transform). Zero layer+mask so they don't keep firing
		# body_entered against live ships/bullets. Originals stored on first
		# sleep so _apply_default_reset can restore them on acquire.
		var co := node as CollisionObject2D
		if not co.has_meta("_pool_orig_layer"):
			co.set_meta("_pool_orig_layer", co.collision_layer)
			co.set_meta("_pool_orig_mask", co.collision_mask)
		co.collision_layer = 0
		co.collision_mask = 0
	if node is RigidBody2D:
		var rb := node as RigidBody2D
		rb.linear_velocity = Vector2.ZERO
		rb.angular_velocity = 0.0
	elif node is CharacterBody2D:
		(node as CharacterBody2D).velocity = Vector2.ZERO

func _apply_default_reset(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	if node is Node2D:
		var n2 := node as Node2D
		n2.rotation = 0.0
		n2.scale = Vector2.ONE
	if node is CollisionObject2D:
		var co := node as CollisionObject2D
		if co.has_meta("_pool_orig_layer"):
			co.collision_layer = co.get_meta("_pool_orig_layer")
			co.collision_mask = co.get_meta("_pool_orig_mask")
	if node is RigidBody2D:
		var rb := node as RigidBody2D
		rb.linear_velocity = Vector2.ZERO
		rb.angular_velocity = 0.0
	elif node is CharacterBody2D:
		(node as CharacterBody2D).velocity = Vector2.ZERO

func stats() -> Dictionary:
	return {
		"free": _free.size(),
		"live": _live,
		"total": _free.size() + _live,
		"initial": initial_size,
	}
