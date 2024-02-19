class_name Body
extends RigidBody2D

@export var max_health: int
@export var can_die = true
@export var defense: Damage
@export var death: PackedScene
@export var successors: Array[PackedScene]
@export var successors_count: int = 3

var health: int
var dying = false

func _ready():
	health = max_health

func damage(attack: Damage):
	if not can_die or not attack:
		return
	
	health += attack.calculate(defense)
	
	if health <= 0:
		die()

func die():
	if dying:
		return
	
	dying = true
	
	if death:
		var node = death.instantiate()
		node.global_position = global_position
		get_tree().current_scene.add_child(node)
	
	if not successors.is_empty():
		for i in range(successors_count):
			add_successor(successors.pick_random(), 200, 2000)
		
	queue_free()
	pass

func add_successor(model: PackedScene, radius: int = 200, speed: int = 1000):
	if not model:
		return
	var successor = model.instantiate() as RigidBody2D
	successor.position = position + Vector2(randi_range(-radius, radius), randi_range(-radius, radius))
	successor.rotation = randi_range(0, 360)
	successor.linear_velocity = Vector2(randi_range(-speed, speed), randi_range(-speed, speed))
	successor.angular_velocity = randi_range(-5, 5)
	successor.angular_damp = -1
	successor.linear_damp = 0
	
	get_tree().current_scene.call_deferred("add_child", successor)
