class_name InventorySlot extends Control

enum ItemSlotType {
	STORAGE,
	WEAPON,
	UTIL,
	ENGINE,
	DROP,
	AMMO
}
@export var slot_type: ItemSlotType
@export var max_items: int = 50

var occupant: ItemType
var quantity: int = 0

signal item_adding(sender: InventorySlot, type: ItemType, quantity: int)
signal item_removing(sender: InventorySlot, type: ItemType)

func inc(type: ItemType) -> int:
	quantity += 1
	occupant = type
	
	if quantity >= max_items:
		quantity = max_items
	
	item_adding.emit(self, type, 1)
	
	return quantity

func dec(type: ItemType) -> int:
	quantity -= 1
	
	item_removing.emit(self, type, 1)
	
	if quantity <= 0:
		quantity = 0
		occupant = null
	
	return quantity

func clear():
	if occupant:
		item_removing.emit(self, occupant, quantity)
	quantity = 0
	occupant = null

func has_space(how_much: int = 0) -> bool:
	return (quantity + how_much) < max_items

func has_type(type: ItemType) -> bool:
	return occupant and (type.name == occupant.name)

func is_empty():
	return occupant == null
	
func _get_drag_data(_at_position: Vector2) -> Variant:
	var data = null
	
	if occupant:
		data = {
			"source": self,
			"item_type": occupant,
			"quantity": quantity
		}
		
		set_drag_preview(
			make_drag_preview()
		)

	return data

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return is_empty() or (has_type(data.item_type) and has_space(data.quantity))
	
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	data.source.clear()
	occupant = data.item_type
	quantity = quantity + data.quantity
	item_adding.emit(self, data.item_type, data.quantity)

func make_drag_preview() -> TextureRect:
	if occupant and occupant.image:
		var t := TextureRect.new()
		t.texture = occupant.image
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = get_rect().size
		return t
	else:
		return null
