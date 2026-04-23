extends Node

# Autoload: PoolManager
#
# Central registry of per-PackedScene ScenePools for high-frequency spawned
# entities (bullets, bullet-impact FX, flash FX, death explosions).
#
# Usage:
#   var node = PoolManager.acquire(scene_packed)
#   # ... configure fields that _pool_reset() cleared ...
#   spawn_parent.call_deferred("add_child", node)
#
#   # On despawn (bullet collision, explosion timer, finished signal, etc.):
#   PoolManager.release(node)
#
# The manager prewarms a fixed pool per registered scene at _ready. Pools
# grow on demand if exhausted — a warning is pushed once per scene when the
# pool doubles past its initial size, so runaway growth is visible in logs.

# Pool configs by resource path — editor-friendly to tune in one place.
# Sizes are worst-case estimates for Wave 20 (260423-wv3 plan).
const _POOL_CONFIGS: Dictionary = {
	# Player-weapon bullets
	"res://prefabs/minigun/minigun-bullet.tscn": 60,
	"res://prefabs/gausscannon/gausscannon-bullet.tscn": 8,
	"res://prefabs/rpg/rpg-bullet.tscn": 6,
	"res://prefabs/laser/laser-bullet.tscn": 40,
	"res://prefabs/gravitygun/gravitygun-bullet.tscn": 4,
	# Enemy bullets
	"res://prefabs/enemies/flanker/flanker-bullet.tscn": 24,
	"res://prefabs/enemies/beeliner/beeliner-bullet.tscn": 24,
	"res://prefabs/enemies/sniper/sniper-bullet.tscn": 24,
	"res://prefabs/enemies/swarmer/swarmer-bullet.tscn": 24,
	# Impact / flash FX (CPUParticles2D)
	"res://prefabs/ui/bullet-impact.tscn": 40,
	"res://prefabs/laser/laser-bounce-flash.tscn": 30,
	# Death explosion scenes
	"res://prefabs/minigun/minigun-bullet-explosion.tscn": 20,
	"res://prefabs/gausscannon/gausscannon-bullet-explosion.tscn": 20,
	"res://prefabs/rpg/rpg-bullet-explosion.tscn": 20,
	"res://prefabs/laser/laser-bullet-explosion.tscn": 20,
}

const _DEFAULT_LAZY_SIZE: int = 8

# PackedScene -> ScenePool
var _pools: Dictionary = {}

func _ready() -> void:
	for path in _POOL_CONFIGS.keys():
		var scene: PackedScene = load(path)
		if scene == null:
			push_error("PoolManager: failed to load pool scene %s" % path)
			continue
		var size: int = _POOL_CONFIGS[path]
		var pool := ScenePool.build(scene, size)
		add_child(pool)
		pool.prewarm()
		_pools[scene] = pool

func acquire(scene: PackedScene) -> Node:
	if scene == null:
		push_error("PoolManager.acquire: scene is null")
		return null
	var pool: ScenePool = _pools.get(scene, null)
	if pool == null:
		push_warning("PoolManager: unregistered pool scene %s — creating lazy pool" % scene.resource_path)
		pool = ScenePool.build(scene, _DEFAULT_LAZY_SIZE)
		add_child(pool)
		# Lazy pools start empty; they grow on-demand. Skip prewarm for cheapness.
		_pools[scene] = pool
	return pool.acquire()

func release(node: Node) -> void:
	if node == null:
		return
	var scene = node.get_meta("_pool_scene", null)
	if scene == null:
		push_warning("PoolManager.release: node %s has no _pool_scene meta, falling back to queue_free" % node.name)
		node.queue_free()
		return
	var pool: ScenePool = _pools.get(scene, null)
	if pool == null:
		push_warning("PoolManager.release: no pool registered for %s, falling back to queue_free" % scene.resource_path)
		node.queue_free()
		return
	pool.release(node)

func is_pooled(scene: PackedScene) -> bool:
	return scene != null and _pools.has(scene)

func prewarm(scene: PackedScene, n: int) -> void:
	if scene == null:
		return
	if not _pools.has(scene):
		var pool := ScenePool.build(scene, n)
		add_child(pool)
		pool.prewarm()
		_pools[scene] = pool

# Informational only — pooled instances currently parented to gameplay trees
# are released by their owning cleanup paths (e.g. _restart_game). Logs stats
# for visibility.
func clear_live() -> void:
	print("[PoolManager] clear_live stats: ", stats())

func stats() -> Dictionary:
	var out: Dictionary = {}
	for scene in _pools.keys():
		var pool: ScenePool = _pools[scene]
		out[(scene as PackedScene).resource_path] = pool.stats()
	return out
