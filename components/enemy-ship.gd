class_name EnemyShip
extends Ship

enum State {
	IDLING,
	SEEKING,
	LURKING,
	FIGHTING,
	FLEEING,
	PATROLLING,
	EVADING,
	ESCORTING
}

@export var max_speed: float = 500.0
@export var thrust: float = 200.0
@export var detection_radius: float = 800.0

var current_state: State = State.IDLING

@onready var detection_area: Area2D = $DetectionArea
@onready var hitbox: Area2D = $HitBox

func _ready() -> void:
	super()
	# Physics layers (world.gd):
	# 1=Ship  2=Weapons  3=Bullets  4=Asteroids  5=Explosions  6=Coins  7=Ammo  8=WeaponItem
	detection_area.set_collision_layer_value(1, false)  # area itself is not on Ship layer
	detection_area.set_collision_mask_value(1, true)     # area detects Ship layer (1)
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	super(delta)
	queue_redraw()
	if dying:
		return
	_tick_state(delta)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.linear_velocity = state.linear_velocity.limit_length(max_speed)

func _tick_state(_delta: float) -> void:
	pass

func _enter_state(_new_state: State) -> void:
	pass

func _exit_state(_old_state: State) -> void:
	pass

func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return
	var old_state := current_state
	_exit_state(old_state)
	current_state = new_state
	_enter_state(new_state)
	print("[EnemyShip] state: %s -> %s" % [State.keys()[old_state], State.keys()[new_state]])
	queue_redraw()

func steer_toward(target_position: Vector2) -> void:
	var direction := (target_position - global_position).normalized()
	apply_central_force(direction * thrust)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Physical collision boundary
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, Color(1.0, 0.2, 0.2, 1.0), 5.0)
	# Debug body fill + outline — boosted opacity to survive CanvasModulate dimming
	draw_circle(Vector2.ZERO, 300.0, Color(1.0, 0.2, 0.2, 0.75))
	draw_arc(Vector2.ZERO, 300.0, 0.0, TAU, 64, Color(1.0, 0.2, 0.2, 1.0), 8.0)
	# HitBox boundary — green arc showing actual bullet hit area
	var hb_shape_node := get_node_or_null("HitBox/HitBoxShape")
	if hb_shape_node and hb_shape_node.shape is CircleShape2D:
		draw_arc(Vector2.ZERO, hb_shape_node.shape.radius, 0.0, TAU, 64, Color(0.1, 1.0, 0.1, 1.0), 5.0)
	# Direction indicator — bright yellow arrow
	draw_line(Vector2.ZERO, Vector2(500, 0), Color(1.0, 1.0, 0.0, 1.0), 6.0)
	draw_line(Vector2(500, 0), Vector2(360, -100), Color(1.0, 1.0, 0.0, 1.0), 6.0)
	draw_line(Vector2(500, 0), Vector2(360, 100), Color(1.0, 1.0, 0.0, 1.0), 6.0)
	var font := ThemeDB.fallback_font
	# Enemy type label — large cyan text above state
	var type_name: String = get_script().get_global_name() if get_script() else "ENEMY"
	draw_string(font, Vector2(-240, -760), type_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 128, Color(0.0, 1.0, 1.0, 1.0))
	# State label — bright white text
	var state_label := "STATE: %s" % State.keys()[current_state]
	draw_string(font, Vector2(-240, -600), state_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color(1.0, 1.0, 1.0, 1.0))

func _on_hitbox_body_entered(body: Node2D) -> void:
	if dying:
		return
	if body is Bullet:
		body.collision(self)

func _on_detection_area_body_entered(body: Node2D) -> void:
	if dying:
		return
	if body is PlayerShip and current_state == State.IDLING:
		_change_state(State.SEEKING)

# --- Fire Pattern Convention (ENM-05, ENM-06) ---
# Concrete enemy types implement fire logic independently (no base class fire loop per D-06).
# Pattern: Use spawn_parent.add_child(bullet) at $Barrel.global_position.
# Each type defines its own Damage resource with fixed energy value (ENM-06).
# See 04-RESEARCH.md Pattern 5 for the full code example.
