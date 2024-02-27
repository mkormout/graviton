class_name InventorySlot extends Node

enum ItemSlotType {
	STORAGE,
	WEAPON,
	UTIL,
	ENGINE,
	DROP
}

@export var slot_type: ItemSlotType = ItemSlotType.STORAGE
@export var max_items: int = 50

var items: Array[Item]

signal item_added(sender: InventorySlot, item: Item)
signal item_removed(sender: InventorySlot, item: Item)

func add_item(item: Item) -> int:
	items.append(item)
	item_added.emit(self, item)
	return items.size()

func remove_item(item: Item) -> int:
	items.erase(item)
	item_removed.emit(self, item)
	return items.size()

func has_space() -> bool:
	return items.size() < max_items

func has_type(type: ItemType) -> bool:
	return items.any(
		func(item): return item.same(type)
	)
