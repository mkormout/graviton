class_name ItemType extends Resource

@export var name: String
@export var title: String
@export var price: int
@export var is_coin: bool

func same(type: ItemType) -> bool:
	return type.name == name
