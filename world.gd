extends Node2D

var ship_model = preload("res://prefabs/ship-bfg-23/ship-bfg-23.tscn")
var minigun_model = preload("res://prefabs/minigun/minigun.tscn")
var gausscannon_model = preload("res://prefabs/gausscannon/gausscannon.tscn")
var rpg_model = preload("res://prefabs/rpg/rpg.tscn")
var laser_model = preload("res://prefabs/laser/laser.tscn")

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
var godmode: bool = false

# PHYSICAL LAYERS DESCRIPTION:
# 1. Ship
# 2. Weapons
# 3. Bullets
# 4. Asteroids
# 5. Explosions

# Called when the node enters the scene tree for the first time.
func _ready():
	$Camera2D.zoom = Vector2(0.1, 0.1)
	
	ship = ship_model.instantiate() 
	ship.position = Vector2(0, 0)
	add_child(ship)
	$Hud.ship = ship
	
	mount_weapon(ship, minigun_model, "")
	mount_weapon(ship, minigun_model, "left")
	mount_weapon(ship, minigun_model, "right")
	
	spawn_asteroids(100)

func notify_weapons(action: String):
	ship.do(null, action, "")
	ship.do(null, action, "left")
	ship.do(null, action, "right")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_key_pressed(KEY_SPACE):
		notify_weapons("fire")

func _input(_ev):
	if Input.is_key_pressed(KEY_Q):
		ship.do(null, "fire", "left")
	if Input.is_key_pressed(KEY_W):
		ship.do(null, "fire", "")
	if Input.is_key_pressed(KEY_E):
		ship.do(null, "fire", "right")
		
	if Input.is_key_pressed(KEY_1):
		mount_ship_weapons(minigun_model)
	
	if Input.is_key_pressed(KEY_2):
		mount_ship_weapons(laser_model)
	
	if Input.is_key_pressed(KEY_3):
		mount_ship_weapons(gausscannon_model)
	
	if Input.is_key_pressed(KEY_4):
		mount_ship_weapons(rpg_model)
	
	if Input.is_key_pressed(KEY_ENTER):
		spawn_asteroids(10)
	
	if Input.is_key_pressed(KEY_G):
		notify_weapons("godmode")
		godmode = true
	
	if Input.is_key_pressed(KEY_H):
		notify_weapons("use_ammo")

	if Input.is_key_pressed(KEY_J):
		notify_weapons("use_rate")
			
	if Input.is_key_pressed(KEY_R):
		notify_weapons("reload")

func spawn_asteroids(count: int):
	for x in range(count * 0.5):
		add_asteroid(asteroids_small_model.pick_random())

	for x in range(count * 0.4):
		add_asteroid(asteroids_medium_model.pick_random())

	for x in range(count * 0.1):
		add_asteroid(asteroids_large_model.pick_random())

func mount_weapon(body: MountableBody, what: PackedScene, where: String):
	var weapon = what.instantiate()
	body.mount_weapon(weapon, where)

func mount_ship_weapons(what: PackedScene):
	mount_weapon(ship, what, "")
	mount_weapon(ship, what, "left")
	mount_weapon(ship, what, "right")

func add_asteroid(model: PackedScene):
	const MIN_RANGE = 4000
	const MAX_RANGE = 10000
	const MAX_LINEAR_VELOCITY = 1000
	const MAX_ANGULAR_VELOCITY = PI / 2
	
	var asteroid = model.instantiate() as RigidBody2D
	asteroid.position = Vector2.from_angle(randf() * 2*PI) * randf_range(MIN_RANGE, MAX_RANGE)
	asteroid.rotation = randf_range(0, 2*PI)
	asteroid.linear_velocity = Vector2.from_angle(randf() * 2*PI) * randi_range(-MAX_LINEAR_VELOCITY, MAX_LINEAR_VELOCITY)
	asteroid.angular_velocity = MAX_ANGULAR_VELOCITY * randi_range(-1, 1)
	asteroid.angular_damp = -1
	asteroid.linear_damp = 0
	add_child(asteroid)
