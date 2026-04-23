class_name Bullet
extends Body

@export var life: float = 2.0
@export var attack: Damage
@export var death_ttl: float = 0.1

func _ready():
	# Connect once — pool re-acquire reuses the same instance, so guard
	# against duplicate connections.
	if not body_entered.is_connected(collision):
		body_entered.connect(collision)
	_arm()

# Extracted so both first-spawn (_ready) and pool re-acquire (_pool_reset) can
# share the same arming path: kick off the `life` timeout via Body.die().
func _arm() -> void:
	# When called from _pool_reset's deferred flush, consumer's add_child may
	# not have run yet — die() awaits get_tree().physics_frame and would crash
	# on a detached node. Re-defer until reparented.
	if not is_inside_tree():
		call_deferred("_arm")
		return
	die(life)

func _pool_reset() -> void:
	super()
	# Body._pool_reset resets dying/health; here we re-arm the lifetime timer.
	# Arming runs die(life), which awaits physics_frame — that requires the
	# node to be in the tree. ScenePool calls _pool_reset BEFORE the consumer
	# does add_child, so defer the arm to the next idle flush (by then the
	# caller's call_deferred("add_child", ...) will have completed).
	if not body_entered.is_connected(collision):
		body_entered.connect(collision)
	call_deferred("_arm")

func collision(body):
	if body is Body:
		if attack:
			body.damage(attack)
		else:
			push_warning("Bullet %s has no attack resource assigned" % name)
	die(death_ttl)
