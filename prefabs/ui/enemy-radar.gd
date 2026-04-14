class_name EnemyRadar
extends Control

const ARROW_SIZE := 14.0
const MARGIN := 50.0
const ARROW_COLOR := Color(1.0, 0.3, 0.3, 0.85)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return

	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return

	var vp_size := get_viewport_rect().size
	var half := vp_size * 0.5
	var zoom := cam.zoom.x

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var world_offset: Vector2 = (enemy as Node2D).global_position - cam.global_position
		var screen_pos := world_offset * zoom + half

		# Skip enemies already visible on screen (with inset margin)
		if screen_pos.x > MARGIN and screen_pos.x < vp_size.x - MARGIN \
				and screen_pos.y > MARGIN and screen_pos.y < vp_size.y - MARGIN:
			continue

		var dir := (screen_pos - half).normalized()
		var border := _border_point(dir, half)
		_draw_arrow(border, dir)

func _border_point(dir: Vector2, half: Vector2) -> Vector2:
	# Extent from screen center to the inset border
	var extent := half - Vector2(MARGIN, MARGIN)
	var tx: float = INF if abs(dir.x) < 0.0001 else extent.x / abs(dir.x)
	var ty: float = INF if abs(dir.y) < 0.0001 else extent.y / abs(dir.y)
	return half + dir * min(tx, ty)

func _draw_arrow(center: Vector2, dir: Vector2) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var tip := center + dir * ARROW_SIZE
	var base_left := center - perp * ARROW_SIZE * 0.55 - dir * ARROW_SIZE * 0.35
	var base_right := center + perp * ARROW_SIZE * 0.55 - dir * ARROW_SIZE * 0.35
	draw_colored_polygon(PackedVector2Array([tip, base_left, base_right]), ARROW_COLOR)
