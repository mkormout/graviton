class_name BodyCamera extends Camera2D

@export var body: Body
@export var zoom_levels: Array[ZoomLevel] = [
	ZoomLevel.new(0.2, 0),
	ZoomLevel.new(0.15, 1000),
	ZoomLevel.new(0.1, 2000),
]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if not body:
		return
		
	var max_zoom_diff = 0.1
	var default_c_zoom = 0.2
	var max_speed = 4000
	
	var c_zoom = default_c_zoom
	var c_position = Vector2(0, 0)
	var max_speed_ratio = body.linear_velocity.length()/ max_speed
	c_zoom = c_zoom - min(max_speed_ratio * max_zoom_diff, max_zoom_diff)
	c_position = body.global_position
	
	zoom = Vector2(c_zoom, c_zoom)
	position = c_position

