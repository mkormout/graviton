class_name Ship
extends MountableBody

@export var picker: Area2D
@export var max_inventory: int = 10
@export var inventory: Inventory
@export var can_pick_coin: bool = false

signal inventory_updated(inventory: Array[Item])

var coins: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("body_entered", body_entered)
	picker.connect("body_entered", picker_body_entered)
	super()

func pick(item: Item):
	inventory.append(item)

func pick_coin(item: Item):
	coins += item.count * item.type.price
	item.pick()

func pick_item(item: Item):
	
	inventory_updated.emit(inventory)
	item.pick()

func body_entered(body):
	var ray = RayCast2D.new()
	ray.position = global_position
	ray.target_position = body.global_position
	var collision = ray.get_collision_point()
	
	var attack = Damage.new()
	attack.kinetic = 1000
	damage(attack)

func picker_body_entered(body):
	if not body is Item:
		return
	
	var item = body as Item
	
	if not item.type:
		return
	
	if item.type.is_coin:
		pick_coin(item)
	else:
		pick_item(item)
