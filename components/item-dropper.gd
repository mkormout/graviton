class_name ItemDropper extends Node2D

@export var models: Array[ItemDrop] = []
@export var drop_count: int = 0

func drop(radius: int = 200, speed: int = 1000) -> void:
	for i in range(drop_count):
		var model = roll()
		
		if model:
			var node = model.instantiate()
			node.global_position = global_position + Vector2(randi_range(-radius, radius), randi_range(-radius, radius))
			node.global_rotation_degrees = global_rotation_degrees + randi_range(0, 360)
			node.linear_velocity = Vector2(randi_range(-speed, speed), randi_range(-speed, speed))
			node.angular_velocity = randi_range(-5, 5)
			node.angular_damp = 0.2
			node.linear_damp = 0.2
			get_tree().current_scene.call_deferred("add_child", node)

func roll() -> PackedScene:
	var totalWeight = 0

	for item in models:
		totalWeight += item.chance

	var randomValue = randf_range(0, totalWeight)
	var cumulativeWeight = 0

	for item in models:
		cumulativeWeight += item.chance

		if randomValue <= cumulativeWeight:
			return item.model

	return null
