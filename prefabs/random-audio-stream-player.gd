class_name RandomAudioStreamPlayer2D
extends Node2D

@export var autoplay: bool = true
@export var audio: AudioStreamPlayer2D
@export var resources: Array[AudioStream]

func _ready():
	if autoplay:
		play()

func play():
	if not audio or resources.is_empty():
		return
		
	audio.stream = resources.pick_random()
	audio.play()
