class_name Inventory extends Node

signal slot_item_adding(sender: Inventory, slot: InventorySlot, item: ItemType)
signal slot_item_removing(sender: Inventory, slot: InventorySlot, item: ItemType)

var slots: Array[InventorySlot] = []

func register_slot(slot: InventorySlot):
	slot.item_adding.connect(_on_slot_item_adding)
	slot.item_removing.connect(_on_slot_item_removing)
	slots.append(slot)

func unregister_slot(slot: InventorySlot):
	var i = slots.find(slot)
	
	if i > -1:
		slots[i].item_adding.disconnect(_on_slot_item_adding)
		slots[i].item_removing.disconnect(_on_slot_item_removing)
		slots.remove_at(i)

func add_item(item: Item) -> InventorySlot:
	var slot = find_free(item.type)
	slot = slot if slot else find_free()
	
	if slot:
		slot.inc(item.type)
	
	return slot


func find_free(type: ItemType = null) -> InventorySlot:
	var values = slots.filter(
		func(slot: InventorySlot): return slot.has_type(type) and slot.has_space() if type else slot.is_empty()
	)
	
	return values[0] if values.size() > 0 else null

func _on_slot_item_adding(sender: InventorySlot, item: Item):
	slot_item_adding.emit(self, sender, item)

func _on_slot_item_removing(sender: InventorySlot, item: Item):
	slot_item_removing.emit(self, sender, item)

func get_by_type(type: ItemType):
	return slots.filter(
		func(slot: InventorySlot): return slot.has_type(type)
	)
