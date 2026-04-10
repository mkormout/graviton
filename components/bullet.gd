class_name Bullet
extends Body

@export var life: float = 2.0
@export var attack: Damage
@export var death_ttl: float = 0.1

func _ready():
	body_entered.connect(collision)
	die(life)

func collision(body):
	if body is Body:
		if attack:
			body.damage(attack)
		else:
			push_warning("Bullet %s has no attack resource assigned" % name)
	die(death_ttl)
