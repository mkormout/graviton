class_name DeathScreen
extends CanvasLayer

signal play_again_requested

# --- Constants ---
const SAVE_PATH := "user://leaderboard.cfg"
const MAX_ENTRIES := 10
const GOLD := Color(1.0, 0.843, 0.0)

# --- State ---
var _submitted: bool = false
var _current_score: int = 0
var _current_entry_index: int = -1
var _play_again_btn: Button = null

# --- Node references ---
@onready var _name_section: Control = $NameSection
@onready var _leaderboard_section: Control = $LeaderboardSection
@onready var _name_input: LineEdit = $NameSection/VBox/NameInput
@onready var _submit_button: Button = $NameSection/VBox/SubmitButton
@onready var _rows_container: VBoxContainer = $LeaderboardSection/VBox/RowsContainer


func _ready() -> void:
	_name_input.text_submitted.connect(_on_submit)
	_submit_button.pressed.connect(_on_submit.bind(""))
	visible = false


# --- Public API ---

func show_death_screen(score: int) -> void:
	_current_score = score
	_submitted = false
	if _play_again_btn:
		_play_again_btn.queue_free()
		_play_again_btn = null
	visible = true
	_name_section.visible = true
	_leaderboard_section.visible = false
	_name_input.text = _load_last_name()
	_name_input.select_all()
	_name_input.call_deferred("grab_focus")


# --- Submit handler ---

func _on_submit(_text: String = "") -> void:
	if _submitted:
		return
	_submitted = true

	var player_name := _name_input.text.strip_edges()
	if player_name == "":
		player_name = "---"

	var entries := _load_entries()
	entries = _insert_entry(entries, player_name, _current_score)

	# Find index of current run (first match of name+score)
	_current_entry_index = -1
	for i in range(entries.size()):
		if entries[i]["name"] == player_name and entries[i]["score"] == _current_score:
			_current_entry_index = i
			break

	_save_entries(entries, player_name)

	_name_section.visible = false
	_leaderboard_section.visible = true
	_populate_table(entries)

	_play_again_btn = Button.new()
	_play_again_btn.text = "Play Again"
	_play_again_btn.add_theme_font_size_override("font_size", 22)
	_play_again_btn.pressed.connect(func(): play_again_requested.emit())
	_leaderboard_section.get_node("VBox").add_child(_play_again_btn)


# --- ConfigFile persistence ---

func _load_entries() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return []
	var entries: Array = []
	for i in range(MAX_ENTRIES):
		if cfg.has_section_key("scores", "entry_%d" % i):
			entries.append(cfg.get_value("scores", "entry_%d" % i))
	return entries


func _load_last_name() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return ""
	return cfg.get_value("prefs", "last_name", "")


func _save_entries(entries: Array, last_name: String) -> void:
	var cfg := ConfigFile.new()
	for i in range(entries.size()):
		cfg.set_value("scores", "entry_%d" % i, entries[i])
	cfg.set_value("prefs", "last_name", last_name)
	cfg.save(SAVE_PATH)


func _insert_entry(entries: Array, player_name: String, score: int) -> Array:
	entries.append({ "name": player_name, "score": score })
	entries.sort_custom(func(a, b): return a["score"] > b["score"])
	return entries.slice(0, MAX_ENTRIES)


# --- Leaderboard table display ---

func _populate_table(entries: Array) -> void:
	for child in _rows_container.get_children():
		child.queue_free()

	for i in range(entries.size()):
		var entry = entries[i]
		var is_current := (i == _current_entry_index)
		var color := GOLD if is_current else Color.WHITE
		var rank_text := "%s%d" % ["\u00BB" if is_current else " ", i + 1]
		_add_row(rank_text, entry["name"], str(entry["score"]), color)

	# If current run did not place in top 10, show unranked 11th row
	if _current_entry_index == -1:
		var sep := HSeparator.new()
		_rows_container.add_child(sep)
		var name_text := _name_input.text.strip_edges()
		if name_text == "":
			name_text = "---"
		_add_row("\u00BB\u2013", name_text, str(_current_score), GOLD)


func _add_row(rank: String, player_name: String, score: String, color: Color) -> void:
	var row := HBoxContainer.new()

	var rank_label := Label.new()
	rank_label.custom_minimum_size = Vector2(48, 0)
	rank_label.text = rank
	rank_label.add_theme_font_size_override("font_size", 18)
	rank_label.add_theme_color_override("font_color", color)
	rank_label.add_theme_color_override("font_outline_color", Color.BLACK)
	rank_label.add_theme_constant_override("outline_size", 3)
	row.add_child(rank_label)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(224, 0)
	name_label.text = player_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", color)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 3)
	row.add_child(name_label)

	var score_label := Label.new()
	score_label.custom_minimum_size = Vector2(128, 0)
	score_label.text = score
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", color)
	score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label.add_theme_constant_override("outline_size", 3)
	row.add_child(score_label)

	_rows_container.add_child(row)
