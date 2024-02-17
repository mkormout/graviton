class_name Damage
extends Resource

@export var energy: int
@export var kinetic: int

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func calculate(damage: Damage, bonus = false):
	var result = - (energy + kinetic)
	
	if damage:
		result += damage.energy + damage.kinetic
	
	if not bonus:
		result = min(result, 0)
		
	return result
