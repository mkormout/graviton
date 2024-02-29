class_name Ship
extends MountableBody

var IT = preload("res://components/item-type.gd")

@export var picker: Area2D
@export var storage: Inventory
@export var ammo: Inventory
@export var drop: Inventory
@export var can_pick_coin: bool = false
@export var inventory_ui: Node

var coins: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("body_entered", body_entered)
	picker.connect("body_entered", picker_body_entered)
	super()

func pick_coin(item: Item):
	coins += item.count * item.type.price
	item.pick()

func pick_weapon(item: Item):
	storage.add_item(item)
	item.pick()

func pick_ammo(item: Item):
	ammo.add_item(item)
	item.pick()

func pick_health(item: Item):
	storage.add_item(item)
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
	
	match item.type.type:
		IT.ItemTypes.COIN: pick_coin(item)
		IT.ItemTypes.AMMO: pick_ammo(item)
		IT.ItemTypes.WEAPON: pick_weapon(item)
		IT.ItemTypes.HEALTH: pick_health(item)
	
func toggle_inventory():
	if inventory_ui:
		inventory_ui.visible = not inventory_ui.visible
