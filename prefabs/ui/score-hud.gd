class_name ScoreHud
extends CanvasLayer

@onready var _score_prefix: Label = $VBox/ScoreRow/ScorePrefix
@onready var _score_value: Label = $VBox/ScoreRow/ScoreValue
@onready var _kills_prefix: Label = $VBox/KillsRow/KillsPrefix
@onready var _kills_value: Label = $VBox/KillsRow/KillsValue
@onready var _mult_prefix: Label = $VBox/MultRow/MultPrefix
@onready var _mult_value: Label = $VBox/MultRow/MultValue
@onready var _combo_prefix: Label = $VBox/ComboRow/ComboPrefix
@onready var _combo_value: Label = $VBox/ComboRow/ComboValue

var _score_tween: Tween = null
var _mult_tween: Tween = null


func _ready() -> void:
	_score_value.text = "0"
	_kills_value.text = "0"
	_mult_value.text = "x1"
	_combo_value.text = "--"
	_combo_value.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_mult_value.pivot_offset = Vector2(30, 12)


func connect_to_score_manager(sm: Node) -> void:
	sm.score_changed.connect(_on_score_changed)
	sm.multiplier_changed.connect(_on_multiplier_changed)
	sm.combo_updated.connect(_on_combo_updated)
	sm.combo_expired.connect(_on_combo_expired)


func _on_score_changed(new_score: int, _delta: int) -> void:
	_score_value.text = "%d" % new_score
	_kills_value.text = "%d" % ScoreManager.kill_count
	_animate_score_flash()


func _on_multiplier_changed(new_multiplier: int) -> void:
	_mult_value.text = "x%d" % new_multiplier
	_animate_multiplier_pulse()


func _on_combo_updated(combo_count: int) -> void:
	if combo_count >= 2:
		_combo_value.text = "x%d" % combo_count
		_combo_value.add_theme_color_override("font_color", Color.WHITE)
	else:
		_combo_value.text = "--"
		_combo_value.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


func _on_combo_expired() -> void:
	_combo_value.text = "--"
	_combo_value.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


func _animate_score_flash() -> void:
	if _score_tween and _score_tween.is_running():
		_score_tween.kill()
	_score_value.add_theme_color_override("font_color", Color.WHITE)
	_score_tween = _score_value.create_tween()
	_score_tween.tween_property(_score_value, "theme_override_colors/font_color", Color(1.0, 1.0, 0.7), 0.1)
	_score_tween.chain().tween_property(_score_value, "theme_override_colors/font_color", Color.WHITE, 0.2)


func _animate_multiplier_pulse() -> void:
	if _mult_tween and _mult_tween.is_running():
		_mult_tween.kill()
		_mult_value.scale = Vector2.ONE
		_mult_value.add_theme_color_override("font_color", Color.WHITE)
	_mult_tween = _mult_value.create_tween()
	_mult_tween.set_parallel(true)
	_mult_tween.tween_property(_mult_value, "scale", Vector2(1.4, 1.4), 0.2)
	_mult_tween.tween_property(_mult_value, "theme_override_colors/font_color", Color(1.0, 0.843, 0.0), 0.2)
	_mult_tween.chain().set_parallel(true)
	_mult_tween.tween_property(_mult_value, "scale", Vector2.ONE, 0.2)
	_mult_tween.tween_property(_mult_value, "theme_override_colors/font_color", Color.WHITE, 0.2)
