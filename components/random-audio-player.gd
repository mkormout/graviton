class_name RandomAudioPlayer
extends Node2D

@export var autoplay: bool = true
@export var resources: Array[AudioStream]

var audio: AudioStreamPlayer2D

func _ready():
	audio = AudioStreamPlayer2D.new()
	audio.max_distance = 30000
	audio.max_polyphony = 3
	audio.volume_db = -20
	add_child(audio)
	
	if autoplay:
		play()

func play():
	if not audio or resources.is_empty():
		return
		
	audio.stream = resources.pick_random()
	audio.play()
