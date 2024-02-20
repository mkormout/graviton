class_name Damage
extends Resource

@export var energy: float
@export var kinetic: float

func calculate(damage: Damage, bonus = false):
	var result = - (energy + kinetic)
	
	if damage:
		result += damage.energy + damage.kinetic
	
	if not bonus:
		result = min(result, 0)
		
	return result
