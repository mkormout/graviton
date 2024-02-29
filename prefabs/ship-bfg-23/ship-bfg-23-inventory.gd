extends CanvasLayer

@export var ship: Ship

# Called when the node enters the scene tree for the first time.
func _ready():
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-1")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-2")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-3")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-4")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-5")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-6")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-7")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-8")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
