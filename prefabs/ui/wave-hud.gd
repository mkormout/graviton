class_name WaveHud
extends CanvasLayer

@onready var _panel: Panel = $Panel
@onready var _wave_label: Label = $Panel/VBox/WaveLabel
@onready var _count_label: Label = $Panel/VBox/CountLabel
@onready var _countdown_label: Label = $Panel/VBox/CountdownLabel
@onready var _announcement_label: Label = $AnnouncementLabel

func _ready() -> void:
	_panel.visible = false
	_countdown_label.visible = false
	_announcement_label.modulate.a = 0.0

func connect_to_wave_manager(wm: WaveManager) -> void:
	wm.wave_started.connect(_on_wave_started)
	wm.enemy_count_changed.connect(_on_enemy_count_changed)
	wm.all_waves_complete.connect(_on_all_waves_complete)
	wm.countdown_tick.connect(_on_countdown_tick)

func _on_wave_started(wave_number: int, enemy_count: int, label_text: String) -> void:
	_panel.visible = true
	_wave_label.text = "WAVE %d" % wave_number
	_count_label.text = "%d / %d" % [enemy_count, enemy_count]
	_countdown_label.visible = false

	# Show announcement and fade out over 3 seconds
	_announcement_label.text = "Wave %d\n%s" % [wave_number, label_text]
	_announcement_label.modulate.a = 1.0
	var tween := _announcement_label.create_tween()
	tween.tween_property(_announcement_label, "modulate:a", 0.0, 3.0)

func _on_enemy_count_changed(remaining: int, total: int) -> void:
	_count_label.text = "%d / %d" % [remaining, total]

func _on_countdown_tick(seconds_remaining: int) -> void:
	if seconds_remaining > 0:
		_countdown_label.visible = true
		_countdown_label.text = "Next wave in %d..." % seconds_remaining
	else:
		_countdown_label.visible = false

func _on_all_waves_complete() -> void:
	_wave_label.text = "ALL CLEAR"
	_count_label.text = ""
	_countdown_label.visible = false
