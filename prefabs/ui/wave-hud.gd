class_name WaveHud
extends CanvasLayer

@onready var _panel: Panel = $Panel
@onready var _wave_label: Label = $Panel/VBox/WaveLabel
@onready var _count_label: Label = $Panel/VBox/CountLabel

func _ready() -> void:
	_panel.visible = false

func connect_to_wave_manager(wm: WaveManager) -> void:
	wm.wave_started.connect(_on_wave_started)
	wm.enemy_count_changed.connect(_on_enemy_count_changed)
	wm.all_waves_complete.connect(_on_all_waves_complete)

func _on_wave_started(wave_number: int, enemy_count: int) -> void:
	_panel.visible = true
	_wave_label.text = "WAVE %d" % wave_number
	_count_label.text = "%d / %d" % [enemy_count, enemy_count]

func _on_enemy_count_changed(remaining: int, total: int) -> void:
	_count_label.text = "%d / %d" % [remaining, total]

func _on_all_waves_complete() -> void:
	_wave_label.text = "ALL CLEAR"
	_count_label.text = ""
