extends CanvasLayer

@export var ship: Ship

# Called when the node enters the scene tree for the first time.
func _ready():
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Slot-storage-1")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Slot-storage-2")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Slot-storage-3")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Slot-storage-4")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Slot-storage-5")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Slot-storage-6")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Slot-storage-7")
	ship.inventory.register_slot($"MarginContainer/TextureRect/GridContainer/Slot-storage-8")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
