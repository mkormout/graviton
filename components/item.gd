class_name Item
extends Body

@export var pick_sound: AudioStreamPlayer2D
@export var value: int = 0
@export var is_coin: bool = false

func pick():
	if pick_sound:
		pick_sound.play()
		pick_sound.reparent(
			get_tree().current_scene
		)
		
	die()
