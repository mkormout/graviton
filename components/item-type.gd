class_name ItemType extends Resource

enum ItemTypes {
	COIN,
	AMMO,
	WEAPON,
	HEALTH,
}

@export var name: String
@export var title: String
@export var price: int
@export var image: Texture2D
@export var type: ItemTypes

func same(type: ItemType) -> bool:
	return type.name == name
