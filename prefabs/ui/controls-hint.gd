class_name ControlsHint
extends CanvasLayer

@onready var _panel_container: MarginContainer = $MarginContainer
@onready var _toggle_button: Button = $ToggleButton

var _visible_state: bool = false

func _ready() -> void:
	_panel_container.visible = false
	_toggle_button.pressed.connect(toggle)

func toggle() -> void:
	_visible_state = not _visible_state
	_panel_container.visible = _visible_state
	_toggle_button.text = char(0x25C4) if _visible_state else char(0x25BA)
