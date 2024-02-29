class_name Item
extends Body

@export var pick_sound: AudioStreamPlayer2D
@export var count: int = 1
@export var type: ItemType

func pick():
	if pick_sound:
		pick_sound.play()
		pick_sound.reparent(
			get_tree().current_scene
		)
		
	die()
