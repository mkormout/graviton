class_name BulletHit
extends Node2D

@export var time: float = 0.5

func _ready():
	die(time)
	pass

func die(delay: float):
	await get_tree().create_timer(delay).timeout 
	queue_free()
