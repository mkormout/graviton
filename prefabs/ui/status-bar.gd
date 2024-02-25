extends CanvasLayer

@export var ship: Ship

@onready var coins = $MarginContainer/VBoxContainer/HBoxContainer2/MarginContainer/LabelCoinsValue
@onready var health = $MarginContainer/VBoxContainer/HBoxContainer/MarginContainer/LabelHealthValue

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if not ship:
		health.text = "N/A"
		return
			
	coins.text = str(ship.coins)
	health.text = "%0.0f%%" % [100 * float(ship.health) / float(ship.max_health)]
