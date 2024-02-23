class_name Ship
extends MountableBody

@export var picker: Area2D
@export var max_inventory: int = 10
@export var inventory: Array[Item]
@export var can_pick_coin: bool = false

var coins: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	picker.connect("body_entered", body_entered)
	super()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func pick(item: Item):
	inventory.append(item)

func pick_coin(item: Item):
	coins += item.value
	item.pick()

func body_entered(body):
	if not body is Item:
		return
	
	var item = body as Item
	
	if item.is_coin:
		pick_coin(item)
