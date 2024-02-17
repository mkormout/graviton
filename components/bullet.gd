class_name Bullet
extends RigidBody2D

@export var effect: PackedScene

func _ready():
	connect("body_entered", collision)
	die(2.0)

func collision(body):
	if body is Asteroid:
		var instance = effect.instantiate() as Node2D
		instance.position = position
		get_parent().add_child(instance)
		die(0.2)

func die(delay: float):
	await get_tree().create_timer(delay).timeout 
	queue_free()
