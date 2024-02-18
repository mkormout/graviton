class_name Body
extends RigidBody2D

@export var max_health: int
@export var can_die = true
@export var defense: Damage
@export var death: PackedScene
@export var successors: Array[PackedScene]
var health: int
var dying = false

# Called when the node enters the scene tree for the first time.
func _ready():
	health = max_health

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

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
		
	for i in range(3):
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
	get_tree().current_scene.add_child(successor)
