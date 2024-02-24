class_name ZoomLevel extends Resource

@export var zoom: float
@export var velocity: int

func _init(zoom: float, velocity: int):
	self.zoom = zoom
	self.velocity = velocity
