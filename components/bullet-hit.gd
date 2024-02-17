class_name BulletHit
extends Node2D

func _ready():
	die(0.5)

func die(delay: float):
	await get_tree().create_timer(delay).timeout 
	queue_free()
