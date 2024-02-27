class_name Inventory extends Node

@export var max_slots: int = 8
@export var max_slot_items: int = 50

signal slot_item_added(sender: Inventory, slot: Slot, item: Item)
signal slot_item_removed(sender: Inventory, slot: Slot, item: Item)

var slots: Array[ItemSlot] = []

func _ready():
	init_slots(max_slots)

func init_slots(count: int):
	for i in range(count):
		var slot = ItemSlot.new()
		slot.item_added.connect("item_added", _on_slot_item_added)
		slots.append(slot)

func add_item(item: Item) -> Slot:
	var slot = find_free(item.type)
	slot = slot if slot else find_free()
	
	if slot:
		slot.add_item(item)
	
	return slot


func find_free(type: ItemType = null) -> Slot:
	var values = slots.filter(
		func(slot: ItemSlot): return slot.has_space() and (not type or slot.has_type(type))
	)
	
	return values[0]

func _on_slot_item_added(sender: ItemSlot, item: Item):
	slot_item_added.emit(self, sender, item)

func _on_slot_item_removed(sender: ItemSlot, item: Item):
	slot_item_removed.emit(self, sender, item)
