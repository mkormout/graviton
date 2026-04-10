class_name Item
extends Body

@export var pick_sound: AudioStreamPlayer2D
@export var count: int = 1
@export var type: ItemType

func pick():
	if pick_sound:
		pick_sound.play()
		if spawn_parent:
			pick_sound.reparent(spawn_parent)
		else:
			push_warning("spawn_parent not set on " + name)

	die()
