class_name BodyCamera extends Camera2D

@export var body: Body

# Zoom bounds — lower value = more zoomed out in Godot 2D
const ZOOM_DEFAULT  := 0.25   # zoom when stopped / slow
const ZOOM_MIN      := 0.07   # maximum zoom-out at high sustained speed

# Speed at which zoom-out begins (px/s). Below this = treated as stopped.
const SPEED_THRESHOLD := 600.0

# How long (s) the ship must exceed SPEED_THRESHOLD before zoom-out starts.
const ZOOM_OUT_ONSET := 0.5

# How long (s) after slowing down before zoom-in begins.
const ZOOM_IN_DELAY := 5.0

# Lerp weights per second (applied as lerp(current, target, weight * delta)).
const ZOOM_OUT_RATE := 1.5
const ZOOM_IN_RATE  := 0.8

# Max speed reference used to derive target zoom (must be > SPEED_THRESHOLD).
const SPEED_MAX := 4000.0

# Internal state
var _prev_speed    := 0.0
var _time_fast     := 0.0   # seconds above SPEED_THRESHOLD
var _time_slow     := 0.0   # seconds below SPEED_THRESHOLD after being fast
var _zooming_out   := false  # true once onset delay satisfied
var _zoom_current  := ZOOM_DEFAULT


func _ready() -> void:
	_zoom_current = ZOOM_DEFAULT
	zoom = Vector2(_zoom_current, _zoom_current)


func _physics_process(delta: float) -> void:
	if not body:
		return

	# --- Position: follow body directly (no smoothing needed, body has physics) ---
	global_position = body.global_position

	# --- Speed and acceleration ---
	var speed := body.linear_velocity.length()
	var accel: float = abs(speed - _prev_speed) / delta  # px/s²
	_prev_speed = speed

	# --- State machine: fast / slow timers ---
	if speed > SPEED_THRESHOLD:
		_time_fast += delta
		_time_slow  = 0.0
	else:
		_time_slow += delta
		_time_fast  = 0.0

	# Onset: start zooming out once ship has been fast long enough
	if not _zooming_out and _time_fast >= ZOOM_OUT_ONSET:
		_zooming_out = true

	# Reset: flip to zoom-in once ship has been slow long enough
	if _zooming_out and _time_slow >= ZOOM_IN_DELAY:
		_zooming_out = false
		_time_slow = 0.0

	# --- Target zoom ---
	var zoom_target: float
	if _zooming_out:
		# Map current speed to a zoom level, but only ever allow moving further OUT.
		# This prevents the camera from zooming in during deceleration — it holds
		# the most-zoomed-out level reached until the delay expires.
		var ratio := clampf((speed - SPEED_THRESHOLD) / (SPEED_MAX - SPEED_THRESHOLD), 0.0, 1.0)
		var speed_target := lerpf(ZOOM_DEFAULT, ZOOM_MIN, ratio)
		zoom_target = minf(speed_target, _zoom_current)
	else:
		zoom_target = ZOOM_DEFAULT

	# --- Lerp zoom toward target ---
	var lerp_rate: float
	if zoom_target < _zoom_current:
		# Zooming out — acceleration bonus makes it feel more responsive
		var accel_bonus := clampf(accel / 2000.0, 0.0, 2.0)  # 0..2 bonus multiplier
		lerp_rate = ZOOM_OUT_RATE * (1.0 + accel_bonus)
	else:
		lerp_rate = ZOOM_IN_RATE

	_zoom_current = lerpf(_zoom_current, zoom_target, clampf(lerp_rate * delta, 0.0, 1.0))
	zoom = Vector2(_zoom_current, _zoom_current)
