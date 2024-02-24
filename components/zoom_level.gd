class_name ZoomLevel extends Resource

@export var zoom: float
@export var velocity: int

func _init(z: float, v: int):
	self.zoom = z
	self.velocity = v
