class_name Bullet
extends RigidBody2D

@export var effect: PackedScene
@export var life: float = 2.0
@export var attack: Damage

func _ready():
	connect("body_entered", collision)
	die(life)
	pass

func collision(body):
	if body is Body:
		body.damage(attack)
	
	var instance = effect.instantiate() as Node2D
	instance.global_position = global_position
	get_tree().get_root().add_child(instance)
	die(0.1)

func die(delay: float):
	await get_tree().create_timer(delay).timeout 
	queue_free()
