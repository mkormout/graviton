class_name MusicHud
extends CanvasLayer

@onready var _track_label: Label = $Panel/HBox/TrackLabel
@onready var _skip_button: Button = $Panel/HBox/SkipButton


func _ready() -> void:
	_skip_button.pressed.connect(_on_skip_pressed)
	if MusicManager:
		MusicManager.track_changed.connect(_on_track_changed)
		_set_label(MusicManager.get_current_track())
	else:
		_track_label.text = "—"


func _on_track_changed(stream: AudioStream) -> void:
	_set_label(stream)


func _on_skip_pressed() -> void:
	if MusicManager:
		MusicManager.skip_to_next()


func _set_label(stream: AudioStream) -> void:
	if stream == null or stream.resource_path.is_empty():
		_track_label.text = "—"
		return
	_track_label.text = "♪ " + stream.resource_path.get_file().get_basename()
