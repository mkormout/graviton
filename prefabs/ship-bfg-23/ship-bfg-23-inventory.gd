extends CanvasLayer

@export var ship: Ship

# Called when the node enters the scene tree for the first time.
func _ready():
	ship.storage.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-1")
	ship.storage.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-2")
	ship.storage.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-3")
	ship.storage.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-4")
	ship.storage.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-5")
	ship.storage.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-6")
	ship.storage.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-7")
	ship.storage.register_slot($"MarginContainer/TextureRect/GridContainer/Storage-slot-8")
	
	ship.ammo.register_slot($"MarginContainer/TextureRect/GridContainer3/Ammo-slot-1")
	ship.ammo.register_slot($"MarginContainer/TextureRect/GridContainer3/Ammo-slot-2")
	ship.ammo.register_slot($"MarginContainer/TextureRect/GridContainer3/Ammo-slot-3")
	ship.ammo.register_slot($"MarginContainer/TextureRect/GridContainer3/Ammo-slot-4")
	ship.ammo.register_slot($"MarginContainer/TextureRect/GridContainer3/Ammo-slot-5")

	ship.drop.register_slot($"MarginContainer/TextureRect/GridContainer2/Drop-slot-1")
	ship.drop.register_slot($"MarginContainer/TextureRect/GridContainer2/Drop-slot-2")
	ship.drop.register_slot($"MarginContainer/TextureRect/GridContainer2/Drop-slot-3")
	ship.drop.register_slot($"MarginContainer/TextureRect/GridContainer2/Drop-slot-4")
	ship.drop.register_slot($"MarginContainer/TextureRect/GridContainer2/Drop-slot-5")
	ship.drop.register_slot($"MarginContainer/TextureRect/GridContainer2/Drop-slot-6")
	ship.drop.register_slot($"MarginContainer/TextureRect/GridContainer2/Drop-slot-7")
	ship.drop.register_slot($"MarginContainer/TextureRect/GridContainer2/Drop-slot-8")
	
	var mount_front = ship.get_mount("")
	var mount_left = ship.get_mount("left")
	var mount_right = ship.get_mount("right")
	
	mount_front.link_slot($"MarginContainer/TextureRect/Slot-weapon-front")
	mount_left.link_slot($"MarginContainer/TextureRect/Slot-weapon-left")
	mount_right.link_slot($"MarginContainer/TextureRect/Slot-weapon-right")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
