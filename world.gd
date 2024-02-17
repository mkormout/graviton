extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	$Camera2D.zoom = Vector2(0.2, 0.2)
	mount_minigun()
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_key_pressed(KEY_SPACE):
		$"Ship-bfg-23".do("fire", "")
		$"Ship-bfg-23".do("fire", "left")
		$"Ship-bfg-23".do("fire", "right")
		
	pass

func mount_minigun():
	$"Ship-bfg-23".mount_weapon($Laser, "")
	$"Ship-bfg-23".mount_weapon($Laser2, "left")
	$"Ship-bfg-23".mount_weapon($Laser3, "right")

