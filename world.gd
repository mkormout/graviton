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
var music_hud_model = preload("res://prefabs/ui/music-hud.tscn")

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
var show_enemy_debug: bool = true  # SHIFT+D toggle (quick task 260425-dnx) — debug visuals default ON
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

	add_child(music_hud_model.instantiate())

	$ShipCamera.make_current()

	spawn_asteroids(10)
	$WaveManager.waves = [
		{
			"label": "Pulsar",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 7 },
			]
		},
		{
			"label": "Solar Wind",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 5, "spawn_at": 0.0 },
				{ "enemy_scene": suicider_model, "count": 3, "spawn_at": 6.0 },
			]
		},
		{
			"label": "Comet Trail",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 6, "spawn_at": 0.0, "stagger": 4.0 },
				{ "enemy_scene": flanker_model,  "count": 4, "spawn_at": 6.0 },
			]
		},
		{
			"label": "Asteroid Belt",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 8,
				  "position_mode": "exact", "distance": 6500.0,
				  "angle_mode": "arc", "angle_center": 0.0, "angle_width": PI/2 },
			]
		},
		{
			"label": "Nebula",
			"groups": [
				{ "enemy_scene": swarmer_model,  "count": 10, "spawn_at": 0.0, "stagger": 3.0,
				  "position_mode": "random", "distance_min": 5500.0, "distance_max": 8500.0 },
				{ "enemy_scene": flanker_model,  "count": 4,  "spawn_at": 8.0 },
			]
		},
		{
			"label": "Aurora Borealis",
			"groups": [
				{ "enemy_scene": flanker_model,  "count": 5, "spawn_at": 0.0,
				  "angle_mode": "arc", "angle_center": -PI/2, "angle_width": PI/3 },
				{ "enemy_scene": beeliner_model, "count": 8, "spawn_at": 5.0 },
				{ "enemy_scene": sniper_model,   "count": 5, "spawn_at": 10.0,
				  "position_mode": "exact", "distance": 8000.0 },
			]
		},
		{
			"label": "Magnetar",
			"groups": [
				{ "enemy_scene": flanker_model,  "count": 6, "spawn_at": 0.0,
				  "angle_mode": "arc", "angle_center": PI/2, "angle_width": PI/3 },
				{ "enemy_scene": suicider_model, "count": 6, "spawn_at": 6.0,
				  "position_mode": "exact", "distance": 5200.0,
				  "cluster_radius": 700.0 },
				{ "enemy_scene": sniper_model,   "count": 4, "spawn_at": 12.0,
				  "position_mode": "exact", "distance": 8200.0 },
				{ "enemy_scene": beeliner_model, "count": 6, "spawn_at": 14.0 },
			]
		},
		{
			"label": "Solar Flare",
			"groups": [
				{ "enemy_scene": swarmer_model,  "count": 12, "spawn_at": 0.0, "speed_tier": 1.3 },
				{ "enemy_scene": flanker_model,  "count": 6,  "spawn_at": 8.0 },
			]
		},
		{
			"label": "Twin Suns",
			"groups": [
				{ "enemy_scene": suicider_model, "count": 4, "spawn_at": 0.0,
				  "position_mode": "exact", "distance": 5500.0,
				  "cluster_radius": 600.0 },
				{ "enemy_scene": suicider_model, "count": 4, "spawn_at": 5.0,
				  "position_mode": "exact", "distance": 5500.0,
				  "angle_mode": "arc", "angle_center": PI, "angle_width": PI/6,
				  "cluster_radius": 600.0 },
				{ "enemy_scene": beeliner_model, "count": 6, "spawn_at": 10.0 },
			]
		},
		{
			"label": "Neutron Star",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 8, "spawn_at": 0.0 },
				{ "enemy_scene": flanker_model,  "count": 6, "spawn_at": 5.0,
				  "position_mode": "exact", "distance": 6000.0 },
				{ "enemy_scene": sniper_model,   "count": 4, "spawn_at": 11.0,
				  "position_mode": "exact", "distance": 8500.0 },
				{ "enemy_scene": suicider_model, "count": 4, "spawn_at": 15.0 },
			]
		},
		{
			"label": "Wormhole",
			"groups": [
				{ "enemy_scene": swarmer_model,  "count": 12, "spawn_at": 0.0, "stagger": 5.0,
				  "position_mode": "random", "distance_min": 5000.0, "distance_max": 8000.0 },
				{ "enemy_scene": flanker_model,  "count": 6,  "spawn_at": 6.0,
				  "angle_mode": "arc", "angle_center": -PI/2, "angle_width": PI/3 },
				{ "enemy_scene": sniper_model,   "count": 4,  "spawn_at": 12.0,
				  "angle_mode": "arc", "angle_center": PI/2, "angle_width": PI/3 },
				{ "enemy_scene": beeliner_model, "count": 4,  "spawn_at": 16.0 },
			]
		},
		{
			"label": "Quasar",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 10, "spawn_at": 0.0 },
				{ "enemy_scene": flanker_model,  "count": 6,  "spawn_at": 5.0 },
				{ "enemy_scene": sniper_model,   "count": 6,  "spawn_at": 10.0,
				  "position_mode": "exact", "distance": 8500.0,
				  "initial_state": "SEEKING" },
				{ "enemy_scene": suicider_model, "count": 6,  "spawn_at": 15.0,
				  "position_mode": "exact", "distance": 5000.0 },
				{ "enemy_scene": swarmer_model,  "count": 4,  "spawn_at": 18.0, "speed_tier": 1.4 },
			]
		},
		{
			"label": "Dark Matter",
			"groups": [
				{ "enemy_scene": swarmer_model,  "count": 14, "spawn_at": 0.0,
				  "position_mode": "random", "distance_min": 5000.0, "distance_max": 9000.0 },
				{ "enemy_scene": flanker_model,  "count": 6,  "spawn_at": 8.0,
				  "angle_mode": "arc", "angle_center": 0.0, "angle_width": PI/3 },
				{ "enemy_scene": beeliner_model, "count": 6,  "spawn_at": 12.0 },
			]
		},
		{
			"label": "Cosmic Microwave",
			# Breather: a single dripped swarm, no peaks, no exotic angles — gives the player room to breathe.
			"groups": [
				{ "enemy_scene": swarmer_model,  "count": 14, "spawn_at": 0.0, "stagger": 8.0,
				  "position_mode": "random", "distance_min": 5500.0, "distance_max": 8500.0,
				  "speed_tier": 0.7 },
				{ "enemy_scene": beeliner_model, "count": 4,  "spawn_at": 10.0 },
			]
		},
		{
			"label": "Red Giant",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 8, "spawn_at": 0.0 },
				{ "enemy_scene": flanker_model,  "count": 8, "spawn_at": 5.0 },
				{ "enemy_scene": swarmer_model,  "count": 8, "spawn_at": 10.0, "speed_tier": 1.2 },
				{ "enemy_scene": sniper_model,   "count": 4, "spawn_at": 14.0,
				  "position_mode": "exact", "distance": 8500.0 },
			]
		},
		{
			"label": "Black Hole",
			"groups": [
				{ "enemy_scene": flanker_model,  "count": 8,  "spawn_at": 0.0,
				  "angle_mode": "arc", "angle_center": -PI/2, "angle_width": PI/4 },
				{ "enemy_scene": suicider_model, "count": 8,  "spawn_at": 6.0,
				  "position_mode": "exact", "distance": 5000.0,
				  "cluster_radius": 800.0 },
				{ "enemy_scene": beeliner_model, "count": 10, "spawn_at": 11.0 },
				{ "enemy_scene": sniper_model,   "count": 6,  "spawn_at": 16.0,
				  "position_mode": "exact", "distance": 8500.0 },
				{ "enemy_scene": swarmer_model,  "count": 4,  "spawn_at": 20.0, "speed_tier": 1.4 },
			]
		},
		{
			"label": "Singularity",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 12, "spawn_at": 0.0 },
				{ "enemy_scene": flanker_model,  "count": 10, "spawn_at": 5.0,
				  "position_mode": "random", "distance_min": 5500.0, "distance_max": 8000.0 },
				{ "enemy_scene": swarmer_model,  "count": 12, "spawn_at": 10.0, "stagger": 4.0,
				  "speed_tier": 1.3 },
				{ "enemy_scene": sniper_model,   "count": 6,  "spawn_at": 15.0,
				  "initial_state": "FIGHTING" },
				{ "enemy_scene": suicider_model, "count": 8,  "spawn_at": 20.0 },
			]
		},
		{
			"label": "Event Horizon",
			# Mini-breather at a high baseline: fewer groups, but the snipers spawn already SEEKING so it doesn't feel regressive.
			"groups": [
				{ "enemy_scene": flanker_model,  "count": 10, "spawn_at": 0.0,
				  "angle_mode": "arc", "angle_center": PI, "angle_width": PI/3 },
				{ "enemy_scene": swarmer_model,  "count": 16, "spawn_at": 6.0, "speed_tier": 0.8 },
				{ "enemy_scene": sniper_model,   "count": 6,  "spawn_at": 14.0,
				  "position_mode": "exact", "distance": 9000.0,
				  "initial_state": "SEEKING" },
				{ "enemy_scene": beeliner_model, "count": 6,  "spawn_at": 18.0 },
			]
		},
		{
			"label": "Supernova",
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 14, "spawn_at": 0.0 },
				{ "enemy_scene": flanker_model,  "count": 12, "spawn_at": 4.0,
				  "angle_mode": "arc", "angle_center": -PI/2, "angle_width": PI/3 },
				{ "enemy_scene": swarmer_model,  "count": 16, "spawn_at": 8.0, "stagger": 4.0,
				  "position_mode": "random", "distance_min": 4800.0, "distance_max": 8500.0,
				  "speed_tier": 1.3 },
				{ "enemy_scene": suicider_model, "count": 10, "spawn_at": 14.0,
				  "position_mode": "exact", "distance": 5200.0,
				  "cluster_radius": 900.0 },
				{ "enemy_scene": sniper_model,   "count": 8,  "spawn_at": 18.0,
				  "position_mode": "exact", "distance": 9000.0,
				  "angle_mode": "arc", "angle_center": PI/2, "angle_width": PI/4,
				  "initial_state": "FIGHTING" },
				{ "enemy_scene": flanker_model,  "count": 10, "spawn_at": 22.0 },
			]
		},
		{
			"label": "Heat Death",
			# Finale: every option exercised — staged, dripped, random, exact, arc, cluster, FIGHTING. Suicider cluster lands BEHIND the player heading at 18s.
			"groups": [
				{ "enemy_scene": beeliner_model, "count": 16, "spawn_at": 0.0, "stagger": 4.0 },
				{ "enemy_scene": flanker_model,  "count": 14, "spawn_at": 5.0,
				  "angle_mode": "arc", "angle_center": -PI/2, "angle_width": PI/3 },
				{ "enemy_scene": swarmer_model,  "count": 20, "spawn_at": 9.0, "stagger": 5.0,
				  "position_mode": "random", "distance_min": 4500.0, "distance_max": 9000.0,
				  "speed_tier": 1.4 },
				{ "enemy_scene": sniper_model,   "count": 10, "spawn_at": 14.0,
				  "position_mode": "exact", "distance": 9000.0,
				  "angle_mode": "arc", "angle_center": 0.0, "angle_width": PI/4,
				  "initial_state": "FIGHTING" },
				{ "enemy_scene": suicider_model, "count": 14, "spawn_at": 18.0,
				  "position_mode": "exact", "distance": 5000.0,
				  "angle_mode": "arc", "angle_center": PI/2, "angle_width": PI/6,
				  "cluster_radius": 1000.0,
				  "initial_state": "FIGHTING" },
				{ "enemy_scene": flanker_model,  "count": 12, "spawn_at": 24.0 },
				{ "enemy_scene": swarmer_model,  "count": 9,  "spawn_at": 28.0, "speed_tier": 1.5 },
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
	if Input.is_key_pressed(KEY_D) and not Input.is_key_pressed(KEY_SHIFT):
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

	# SHIFT+D: toggle enemy debug visuals (Polygon2D Shape vs Sprite2D). Quick task 260425-dnx.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D and event.shift_pressed:
		show_enemy_debug = not show_enemy_debug
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.has_method("set_debug_visible"):
				enemy.set_debug_visible(show_enemy_debug)
		print("[world] enemy debug visuals: %s" % ("ON" if show_enemy_debug else "OFF"))

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
	# Wait ~1.2s for the death explosion to finish (Explosion.time = 1s) before pausing.
	# Uses a physics_frame yield loop instead of a SceneTreeTimer (no allocation).
	var frames := int(round(1.2 * Engine.physics_ticks_per_second))
	for _i in range(frames):
		await get_tree().physics_frame
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

	# Pool-aware cleanup: pooled Explosion/Bullet instances return to their
	# pool so PoolManager retains reusable capacity across restarts. Non-pool
	# instances (none expected in these two branches today, but the helper is
	# defensive) fall back to queue_free.
	for child in get_children():
		if child is Explosion:
			_free_or_release(child)

	for child in get_children():
		if child is Bullet:
			_free_or_release(child)

	await get_tree().process_frame
	# print("[PoolManager stats after restart] ", PoolManager.stats())

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

func _free_or_release(node: Node) -> void:
	# Prefer returning to the pool so capacity is retained across restarts;
	# fall back to queue_free for non-pooled nodes.
	var scene = node.get_meta("_pool_scene", null)
	if scene != null and PoolManager.is_pooled(scene):
		PoolManager.release(node)
	else:
		node.queue_free()
