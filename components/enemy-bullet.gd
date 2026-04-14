class_name EnemyBullet
extends Bullet

func collision(body: Node) -> void:
	if body is EnemyShip:
		return
	super(body)

func _draw() -> void:
	# Debug visual — override in concrete enemy bullet types to replace with a sprite
	var r := 20.0
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.3, 0.0, 0.85))
	draw_line(Vector2(-r, 0), Vector2(r, 0), Color(1.0, 1.0, 0.0, 1.0), 3.0)
	draw_line(Vector2(0, -r), Vector2(0, r), Color(1.0, 1.0, 0.0, 1.0), 3.0)
