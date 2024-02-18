class_name ExplosionLight
extends PointLight2D

@export var time: float

func _physics_process(delta):
	energy -= energy / (25 * time)
