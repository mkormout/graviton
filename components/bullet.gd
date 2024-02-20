class_name Bullet
extends Body

@export var life: float = 2.0
@export var attack: Damage

func _ready():
	connect("body_entered", collision)
	die(life)

func collision(body):
	if body is Body:
		body.damage(attack)
	die(0.1)
