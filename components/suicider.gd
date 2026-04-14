class_name Suicider
extends EnemyShip

const FAR_THRESHOLD := 4000.0  # distance from current target that counts as "far miss" → brake

var _target: Node2D = null
var _locked_target_pos: Vector2 = Vector2.ZERO

@onready var _contact_area: Area2D = $ContactArea

func _ready() -> void:
	super()
	thrust *= randf_range(0.8, 1.2)
	max_speed *= randf_range(0.8, 1.2)
	# ContactArea detects Ship layer (1) but is not on Ship layer itself
	_contact_area.set_collision_layer_value(1, false)
	_contact_area.set_collision_mask_value(1, true)
	# detection_area.body_entered already connected by EnemyShip._ready() via virtual dispatch
	# — do NOT re-connect here or the handler fires twice and the IDLING guard fails on second call
	_contact_area.body_entered.connect(_on_contact_area_body_entered)

func _on_detection_area_body_entered(body: Node2D) -> void:
	if dying:
		return
	if body is PlayerShip and current_state == State.IDLING:
		_target = body
		_change_state(State.SEEKING)

func _on_contact_area_body_entered(body: Node2D) -> void:
	if dying:
		return
	if body is PlayerShip:
		die()

func _enter_state(new_state: State) -> void:
	if new_state == State.SEEKING and is_instance_valid(_target):
		_locked_target_pos = _target.global_position

func _reacquire_target() -> void:
	if is_instance_valid(_target):
		_locked_target_pos = _target.global_position

func _tick_state(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = null
		_change_state(State.IDLING)
		return

	match current_state:
		State.SEEKING:
			var to_locked := _locked_target_pos - global_position
			var dist := to_locked.length()
			if dist < 1.0:
				return
			# D-03: overshoot check — if moving away from locked target, re-acquire
			if linear_velocity.length_squared() > 100.0 and linear_velocity.dot(to_locked) < 0.0:
				_reacquire_target()
				# Far miss — brake so the Suicider stops and re-engages cleanly
				if global_position.distance_to(_target.global_position) > FAR_THRESHOLD:
					apply_central_force(-linear_velocity.normalized() * thrust * 2.0)
				return
			# D-02: thrust ramp — increases as Suicider closes on locked position
			var thrust_mult := clampf(1.0 + (1.0 - dist / detection_radius), 1.0, 2.0)
			apply_central_force((to_locked / dist) * thrust * thrust_mult)
			# Smooth rotation to follow velocity direction (same pattern as swarmer.gd)
			if linear_velocity.length_squared() > 100.0:
				rotation = lerp_angle(rotation, linear_velocity.angle(), 12.0 * delta)

func die(delay: float = 0.0) -> void:
	if dying:
		return
	super(delay)
