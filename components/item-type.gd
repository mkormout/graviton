class_name ItemType extends Resource

enum ItemTypes {
	COIN,
	AMMO,
	WEAPON,
	HEALTH,
}

@export var name: String
@export var name_item: String
@export var title: String
@export var type: ItemTypes
@export var price: int
@export var image: Texture2D

var model
var model_item

func same(type: ItemType) -> bool:
	return type.name == name

func is_loaded() -> bool:
	return model != null

func init() -> void:
	if name:
		model = load("res://prefabs/%s/%s.tscn" % [name, name])
	if name_item:
		model_item = load("res://prefabs/%s/%s0item.tscn" % [name, name_item])

func instantiate() -> Node2D:
	if not is_loaded():
		init()
	
	return model.instantiate()

func instantiate_item() -> Node2D:
	if not is_loaded():
		init()
	
	return model_item.instantiate()
