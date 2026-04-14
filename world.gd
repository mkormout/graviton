extends Node2D

var ship_model = preload("res://prefabs/ship-bfg-23/ship-bfg-23.tscn")
var minigun_model = preload("res://prefabs/minigun/minigun.tscn")
var gausscannon_model = preload("res://prefabs/gausscannon/gausscannon.tscn")
var rpg_model = preload("res://prefabs/rpg/rpg.tscn")
var gravitygun_model = preload("res://prefabs/gravitygun/gravitygun.tscn")
var laser_model = preload("res://prefabs/laser/laser.tscn")
var enemy_model = preload("res://prefabs/enemies/base-enemy-ship.tscn")
var beeliner_model = preload("res://prefabs/enemies/beeliner/beeliner.tscn")
var sniper_model = preload("res://prefabs/enemies/sniper/sniper.tscn")

var asteroids_small_model = [
	preload("res://prefabs/asteroid/asteroid-small-1.tscn"),
	preload("res://prefabs/asteroid/asteroid-small-2.tscn"),
]

var asteroids_medium_model = [
	preload("res://prefabs/asteroid/asteroid-medium-1.tscn"),
	preload("res://prefabs/asteroid/asteroid-medium-2.tscn"),
]

var asteroids_large_model = [
	preload("res://prefabs/asteroid/asteroid-large-1.tscn"),
	preload("res://prefabs/asteroid/asteroid-large-2.tscn"),
]

var godmode: bool = false
var camera_follow: bool = false

# PHYSICAL LAYERS DESCRIPTION:
# 1. Ship
# 2. Weapons
# 3. Bullets
# 4. Asteroids
# 5. Explosions
# 6. Coins
# 7. Ammo
# 8. Weapon Item

# Called when the node enters the scene tree for the first time.
func _ready():
	$ShipBFG23.add_to_group("player")
	setup_spawn_parent($ShipBFG23)
	mount_weapon($ShipBFG23, minigun_model, "")
	mount_weapon($ShipBFG23, minigun_model, "left")
	mount_weapon($ShipBFG23, minigun_model, "right")

	spawn_asteroids(10)
	$WaveManager.waves = [
		{ "enemy_scene": beeliner_model, "count": 3 },
		{ "enemy_scene": sniper_model, "count": 2 },
		{ "enemy_scene": beeliner_model, "count": 5 },
		{ "enemy_scene": beeliner_model, "count": 8 },
		{ "enemy_scene": beeliner_model, "count": 13 },
		{ "enemy_scene": beeliner_model, "count": 21 },
		{ "enemy_scene": beeliner_model, "count": 34 },
	]

func setup_spawn_parent(node: Node):
	if "spawn_parent" in node:
		node.spawn_parent = self
	for child in node.get_children():
		setup_spawn_parent(child)

func notify_weapons(action: MountableBody.Action):
	if not $ShipBFG23:
		return

	$ShipBFG23.do(null, action, "")
	$ShipBFG23.do(null, action, "left")
	$ShipBFG23.do(null, action, "right")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_key_pressed(KEY_SPACE):
		notify_weapons(MountableBody.Action.FIRE)

func _input(event):
	if not $ShipBFG23:
		return
		
	if Input.is_key_pressed(KEY_Q):
		$ShipBFG23.do(null, MountableBody.Action.FIRE, "left")
	if Input.is_key_pressed(KEY_W):
		$ShipBFG23.do(null, MountableBody.Action.FIRE, "")
	if Input.is_key_pressed(KEY_E):
		$ShipBFG23.do(null, MountableBody.Action.FIRE, "right")
		
	if Input.is_key_pressed(KEY_1):
		mount_ship_weapons(minigun_model)
	
	if Input.is_key_pressed(KEY_2):
		mount_ship_weapons(laser_model)
	
	if Input.is_key_pressed(KEY_3):
		mount_ship_weapons(gausscannon_model)
	
	if Input.is_key_pressed(KEY_4):
		mount_ship_weapons(rpg_model)
	
	if Input.is_key_pressed(KEY_5):
		mount_ship_weapons(gravitygun_model)
	
	if Input.is_key_pressed(KEY_6):
		mount_weapon($ShipBFG23, laser_model, "")
		mount_weapon($ShipBFG23, minigun_model, "left")
		mount_weapon($ShipBFG23, minigun_model, "right")
		
	if Input.is_key_pressed(KEY_ENTER):
		spawn_asteroids(10)
	
	if Input.is_key_pressed(KEY_G):
		notify_weapons(MountableBody.Action.GODMODE)
		godmode = true

	if Input.is_key_pressed(KEY_H):
		notify_weapons(MountableBody.Action.USE_AMMO)

	if Input.is_key_pressed(KEY_J):
		notify_weapons(MountableBody.Action.USE_RATE)

	if Input.is_key_pressed(KEY_R):
		notify_weapons(MountableBody.Action.RELOAD)
	
	if Input.is_key_pressed(KEY_C):
		camera_follow = not camera_follow
		
		if camera_follow:
			$ShipCamera.make_current()
		else:
			$Camera2D.make_current()
			
	if Input.is_key_pressed(KEY_A):
		$ShipBFG23.unmount_weapon("left")
	if Input.is_key_pressed(KEY_S):
		$ShipBFG23.unmount_weapon("")
	if Input.is_key_pressed(KEY_D):
		$ShipBFG23.unmount_weapon("right")
	
	if Input.is_key_pressed(KEY_I):
		$ShipBFG23.toggle_inventory()

	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		spawn_test_enemy()

	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		$WaveManager.trigger_wave()

func spawn_asteroids(count: int):
	for x in range(count * 0.5):
		add_asteroid(asteroids_small_model.pick_random())

	for x in range(count * 0.4):
		add_asteroid(asteroids_medium_model.pick_random())

	for x in range(count * 0.1):
		add_asteroid(asteroids_large_model.pick_random())

func spawn_test_enemy() -> void:
	var enemy = enemy_model.instantiate()
	enemy.global_position = $ShipBFG23.global_position + Vector2(600, 0)
	add_child(enemy)
	setup_spawn_parent(enemy)
	print("[World] Test enemy spawned at %s" % enemy.global_position)

func mount_weapon(body: MountableBody, what: PackedScene, where: String):
	var weapon = what.instantiate() if what else null
	if weapon:
		setup_spawn_parent(weapon)
	body.mount_weapon(weapon, where)

func mount_ship_weapons(what: PackedScene):
	mount_weapon($ShipBFG23, what, "")
	mount_weapon($ShipBFG23, what, "left")
	mount_weapon($ShipBFG23, what, "right")

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
	setup_spawn_parent(asteroid)
