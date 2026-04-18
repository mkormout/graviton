class_name WaveHud
extends CanvasLayer

@onready var _panel: Panel = $Panel
@onready var _wave_label: Label = $Panel/VBox/WaveLabel
@onready var _count_label: Label = $Panel/VBox/CountLabel
@onready var _countdown_label: Label = $Panel/VBox/CountdownLabel
@onready var _announcement_label: Label = $AnnouncementLabel
@onready var _wave_clear_label: Label = $WaveClearLabel

var _announce_tween: Tween = null

func _ready() -> void:
	_panel.visible = false
	_countdown_label.visible = false
	_announcement_label.modulate.a = 0.0
	_wave_clear_label.visible = false

func connect_to_wave_manager(wm: WaveManager) -> void:
	wm.wave_started.connect(_on_wave_started)
	wm.enemy_count_changed.connect(_on_enemy_count_changed)
	wm.all_waves_complete.connect(_on_all_waves_complete)
	wm.countdown_tick.connect(_on_countdown_tick)
	wm.wave_completed.connect(_on_wave_completed)
	wm.wave_cleared_waiting.connect(_on_wave_cleared_waiting)

func _on_wave_started(wave_number: int, enemy_count: int, label_text: String) -> void:
	_wave_clear_label.visible = false
	_panel.visible = true
	_wave_label.text = "WAVE %d" % wave_number
	_count_label.text = "%d / %d" % [enemy_count, enemy_count]
	_countdown_label.visible = false

	# Show announcement with fade-in/hold/fade-out tween (D-19)
	_announcement_label.text = "Wave %d\n%s" % [wave_number, label_text]
	# Kill existing tween (D-19 + score-hud.gd pattern)
	if _announce_tween and _announce_tween.is_running():
		_announce_tween.kill()
	_announcement_label.modulate.a = 0.0
	_announce_tween = _announcement_label.create_tween()
	_announce_tween.tween_property(_announcement_label, "modulate:a", 1.0, 0.3)
	_announce_tween.tween_interval(2.0)
	_announce_tween.tween_property(_announcement_label, "modulate:a", 0.0, 1.0)

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

func _on_wave_completed(_wave_number: int) -> void:
	# Hide the wave-clear label when a new wave starts (cleanup from previous)
	_wave_clear_label.visible = false

func _on_wave_cleared_waiting(wave_number: int) -> void:
	_wave_clear_label.text = "WAVE %d CLEARED\nPress Enter or F to continue" % wave_number
	_wave_clear_label.visible = true

func hide_wave_clear_label() -> void:
	_wave_clear_label.visible = false

func reset() -> void:
	if _announce_tween and _announce_tween.is_running():
		_announce_tween.kill()
	_announcement_label.modulate.a = 0.0
	_panel.visible = false
	_wave_clear_label.visible = false
	_countdown_label.visible = false
