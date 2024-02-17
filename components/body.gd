class_name Body
extends RigidBody2D

@export var max_health: int
@export var defense: Damage
@export var death: PackedScene
var health: int

# Called when the node enters the scene tree for the first time.
func _ready():
	health = max_health
	print(health)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func damage(attack: Damage):
	if not attack:
		return
	
	health += attack.calculate(defense)
	
	print(health)
	
	if health <= 0:
		die()

func die():
	if death:
		var node = death.instantiate()
		node.global_position = global_position
		get_tree().get_root().add_child(node)
	queue_free()
	pass
