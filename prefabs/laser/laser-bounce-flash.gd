extends CPUParticles2D

func _ready() -> void:
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)

func _pool_reset() -> void:
	# Spawner is expected to call restart() after acquire to trigger the burst.
	emitting = false
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)

func _on_finished() -> void:
	var scene = get_meta("_pool_scene", null)
	if scene != null and PoolManager.is_pooled(scene):
		PoolManager.release(self)
	else:
		queue_free()
