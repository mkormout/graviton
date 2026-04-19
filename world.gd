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
var flanker_model = preload("res://prefabs/enemies/flanker/flanker.tscn")
var swarmer_model = preload("res://prefabs/enemies/swarmer/swarmer.tscn")
var suicider_model = preload("res://prefabs/enemies/suicider/suicider.tscn")
var wave_hud_model = preload("res://prefabs/ui/wave-hud.tscn")
var score_hud_model = preload("res://prefabs/ui/score-hud.tscn")
var enemy_radar_model = preload("res://prefabs/ui/enemy-radar.tscn")
var death_screen_model = preload("res://prefabs/ui/death-screen.tscn")
var controls_hint_model = preload("res://prefabs/ui/controls-hint.tscn")
var weapon_hud_model = preload("res://prefabs/ui/weapon-hud.tscn")

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
var camera_follow: bool = true
var death_screen: DeathScreen = null
var _wave_clear_pending: bool = false
var _wave_hud: WaveHud = null
var _controls_hint: ControlsHint = null
var _weapon_hud: WeaponHud = null

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

	_wave_hud = wave_hud_model.instantiate()
	add_child(_wave_hud)
	_wave_hud.connect_to_wave_manager($WaveManager)

	# Wire ScoreManager to WaveManager for wave multiplier (Phase 11)
	if ScoreManager:
		ScoreManager.connect_to_wave_manager($WaveManager)
	# Wire MusicManager to WaveManager for wave-driven music (Phase 16)
	if MusicManager:
		MusicManager.connect_to_wave_manager($WaveManager)
	$WaveManager.wave_cleared_waiting.connect(func(_n): _wave_clear_pending = true)

	var score_hud: ScoreHud = score_hud_model.instantiate()
	add_child(score_hud)
	score_hud.connect_to_score_manager(ScoreManager)

	add_child(enemy_radar_model.instantiate())

	_weapon_hud = weapon_hud_model.instantiate()
	add_child(_weapon_hud)
	_weapon_hud.connect_to_ship($ShipBFG23)
	_wire_heavy_weapon_shake($ShipBFG23)

	death_screen = death_screen_model.instantiate()
	add_child(death_screen)
	$ShipBFG23.died.connect(_on_player_died)
	death_screen.play_again_requested.connect(_restart_game)

	_controls_hint = controls_hint_model.instantiate()
	add_child(_controls_hint)

	$ShipCamera.make_current()

	spawn_asteroids(10)
	$WaveManager.waves = [
		# Wave 1
		{
			"label": "Suiciders",
			"groups": [{ "enemy_scene": suicider_model, "count": 3 }]
		},
		# Wave 2
		{
			"label": "Beelines",
			"groups": [{ "enemy_scene": beeliner_model, "count": 4 }]
		},
		# Wave 3
		{
			"label": "Flankers",
			"groups": [{ "enemy_scene": flanker_model, "count": 3 }]
		},
		# Wave 4
		{
			"label": "Suiciders + Beelines",
			"groups": [
				{ "enemy_scene": suicider_model, "count": 4 },
				{ "enemy_scene": beeliner_model, "count": 3 },
			]
		},
		# Wave 5
		{
			"label": "Fast Swarm",
			"groups": [{ "enemy_scene": swarmer_model, "count": 6, "speed_tier": 1.5 }]
		},
		# Wave 6
		{
			"label": "Snipers",
			"groups": [{ "enemy_scene": sniper_model, "count": 3 }]
		},
		# Wave 7
		{
			"label": "Flankers + Suiciders",
			"groups": [
				{ "enemy_scene": flanker_model, "count": 4 },
				{ "enemy_scene": suicider_model, "count": 3 },
			]
		},
		# Wave 8
		{
			"label": "Beelines + Swarm",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 6 },
				{ "enemy_scene": swarmer_model, "count": 4 },
			]
		},
		# Wave 9
		{
			"label": "Snipers + Flankers",
			"groups": [
				{ "enemy_scene": sniper_model, "count": 4 },
				{ "enemy_scene": flanker_model, "count": 3 },
			]
		},
		# Wave 10
		{
			"label": "Suiciders + Slow Swarm + Beelines",
			"groups": [
				{ "enemy_scene": suicider_model, "count": 5 },
				{ "enemy_scene": swarmer_model, "count": 6, "speed_tier": 0.6 },
				{ "enemy_scene": beeliner_model, "count": 4 },
			]
		},
		# Wave 11
		{
			"label": "Flankers + Snipers",
			"groups": [
				{ "enemy_scene": flanker_model, "count": 6 },
				{ "enemy_scene": sniper_model, "count": 4 },
			]
		},
		# Wave 12
		{
			"label": "Slow & Fast Swarm + Suiciders",
			"groups": [
				{ "enemy_scene": swarmer_model, "count": 5, "speed_tier": 0.6 },
				{ "enemy_scene": swarmer_model, "count": 5, "speed_tier": 1.5 },
				{ "enemy_scene": suicider_model, "count": 4 },
			]
		},
		# Wave 13
		{
			"label": "Beelines + Flankers + Snipers",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 8 },
				{ "enemy_scene": flanker_model, "count": 5 },
				{ "enemy_scene": sniper_model, "count": 3 },
			]
		},
		# Wave 14
		{
			"label": "Suiciders + Swarm",
			"groups": [
				{ "enemy_scene": suicider_model, "count": 6 },
				{ "enemy_scene": swarmer_model, "count": 8 },
			]
		},
		# Wave 15
		{
			"label": "Snipers + Flankers + Beelines",
			"groups": [
				{ "enemy_scene": sniper_model, "count": 6 },
				{ "enemy_scene": flanker_model, "count": 6 },
				{ "enemy_scene": beeliner_model, "count": 6 },
			]
		},
		# Wave 16
		{
			"label": "Fast Swarm + Suiciders + Snipers",
			"groups": [
				{ "enemy_scene": swarmer_model, "count": 12, "speed_tier": 1.5 },
				{ "enemy_scene": suicider_model, "count": 6 },
				{ "enemy_scene": sniper_model, "count": 4 },
			]
		},
		# Wave 17
		{
			"label": "Flankers + Beelines + Suiciders",
			"groups": [
				{ "enemy_scene": flanker_model, "count": 8 },
				{ "enemy_scene": beeliner_model, "count": 10 },
				{ "enemy_scene": suicider_model, "count": 5 },
			]
		},
		# Wave 18
		{
			"label": "Snipers + Slow Swarm + Flankers",
			"groups": [
				{ "enemy_scene": sniper_model, "count": 8 },
				{ "enemy_scene": swarmer_model, "count": 14, "speed_tier": 0.6 },
				{ "enemy_scene": flanker_model, "count": 6 },
			]
		},
		# Wave 19 — Full Assault
		{
			"label": "Full Assault",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 8 },
				{ "enemy_scene": flanker_model, "count": 8 },
				{ "enemy_scene": swarmer_model, "count": 10 },
				{ "enemy_scene": sniper_model, "count": 6 },
				{ "enemy_scene": suicider_model, "count": 6 },
			]
		},
		# Wave 20 — Final Wave
		{
			"label": "Final Wave",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 12 },
				{ "enemy_scene": flanker_model, "count": 10 },
				{ "enemy_scene": swarmer_model, "count": 16 },
				{ "enemy_scene": sniper_model, "count": 8 },
				{ "enemy_scene": suicider_model, "count": 8 },
			]
		},
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
		
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		if _wave_clear_pending:
			_wave_clear_pending = false
			$WaveManager.trigger_wave()
			_wave_hud.hide_wave_clear_label()
	
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
		if _wave_clear_pending:
			_wave_clear_pending = false
			$WaveManager.trigger_wave()
			_wave_hud.hide_wave_clear_label()
		else:
			$WaveManager.trigger_wave()

	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_controls_hint.toggle()

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

func _on_player_died() -> void:
	_wave_clear_pending = false
	_wave_hud.hide_wave_clear_label()
	# Wait for the death explosion to finish (Explosion.time = 1s) before pausing
	await get_tree().create_timer(1.2).timeout
	get_tree().paused = true
	death_screen.show_death_screen(ScoreManager.total_score)


func _restart_game() -> void:
	get_tree().paused = false
	death_screen.visible = false

	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()

	for child in get_children():
		if child is Item:
			child.queue_free()

	for child in get_children():
		if child is Asteroid:
			child.queue_free()

	for child in get_children():
		if child is Explosion:
			child.queue_free()

	for child in get_children():
		if child is Bullet:
			child.queue_free()

	await get_tree().process_frame

	# Reset after await so enemy tree_exiting cascade doesn't re-show the label
	_wave_clear_pending = false
	_wave_hud.reset()

	var ship = ship_model.instantiate()
	ship.name = "ShipBFG23"
	add_child(ship)
	ship.global_position = Vector2.ZERO
	ship.add_to_group("player")
	setup_spawn_parent(ship)
	mount_weapon(ship, minigun_model, "")
	mount_weapon(ship, minigun_model, "left")
	mount_weapon(ship, minigun_model, "right")
	ship.died.connect(_on_player_died)
	$ShipCamera.body = ship
	$Hud.ship = ship
	$Hud.initialized = false
	if _weapon_hud:
		_weapon_hud.connect_to_ship(ship)
	_wire_heavy_weapon_shake(ship)
	$Coins.ship = ship

	ScoreManager.reset()
	$WaveManager.reset()
	$WaveManager._player = ship
	MusicManager.reset()

	spawn_asteroids(10)

func _wire_heavy_weapon_shake(ship: MountableBody) -> void:
	# Connect fired_heavy signal from each heavy weapon mount to camera shake (T-18-10-02)
	for slot in ["", "left", "right"]:
		var mount = ship.get_mount(slot)
		if not mount:
			continue
		var weapon = mount.body_opposite
		if weapon and weapon.has_signal("fired_heavy"):
			# Avoid duplicate connections on restart
			if not weapon.fired_heavy.is_connected($ShipCamera.shake):
				weapon.fired_heavy.connect($ShipCamera.shake)
