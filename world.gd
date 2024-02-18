extends Node2D

var ship_model = preload("res://prefabs/ship-bfg-23/ship-bfg-23.tscn")
var minigun_model = preload("res://prefabs/minigun/minigun.tscn")
var laser_model = preload("res://prefabs/minigun/minigun.tscn")

var asteroids_small_model = [
	preload("res://prefabs/asteroid-small-1.tscn"),
	preload("res://prefabs/asteroid-small-2.tscn"),
]

var asteroids_medium_model = [
	preload("res://prefabs/asteroid-medium-1.tscn"),
	preload("res://prefabs/asteroid-medium-2.tscn"),
]

var asteroids_large_model = [
	preload("res://prefabs/asteroid-large-1.tscn"),
	preload("res://prefabs/asteroid-large-2.tscn"),
]

var ship: MountableBody

# Called when the node enters the scene tree for the first time.
func _ready():
	$Camera2D.zoom = Vector2(0.1, 0.1)
	
	ship = ship_model.instantiate()
	ship.position = Vector2(0, 0)
	add_child(ship)
	
	mount_weapon(ship, minigun_model, "")
	mount_weapon(ship, minigun_model, "left")
	mount_weapon(ship, minigun_model, "right")
	
	for x in range(40):
		add_asteroid(asteroids_small_model.pick_random())

	for x in range(10):
		add_asteroid(asteroids_medium_model.pick_random())

	for x in range(5):
		add_asteroid(asteroids_large_model.pick_random())

	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_key_pressed(KEY_SPACE):
		ship.do("fire", "")
		ship.do("fire", "left")
		ship.do("fire", "right")
		
	pass

func mount_weapon(body: MountableBody, what: PackedScene, where: String):
	var weapon = what.instantiate()
	add_child(weapon)
	body.mount_weapon(weapon, where)

func add_asteroid(model: PackedScene, radius: int = 8000):
	var asteroid = model.instantiate() as RigidBody2D
	asteroid.position = Vector2(randi_range(-radius, radius), randi_range(-radius, radius))
	asteroid.rotation = randi_range(0, 360)
	asteroid.linear_velocity = Vector2(randi_range(-100, 100), randi_range(-100, 100))
	asteroid.angular_velocity = randi_range(-1, 1)
	asteroid.angular_damp = -1
	asteroid.linear_damp = 0
	add_child(asteroid)
