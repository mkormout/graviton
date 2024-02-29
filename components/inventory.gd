class_name Inventory extends Node

signal slot_item_added(sender: Inventory, slot: InventorySlot, item: Item)
signal slot_item_removed(sender: Inventory, slot: InventorySlot, item: Item)

var slots: Array[InventorySlot] = []

func register_slot(slot: InventorySlot):
	slot.item_added.connect(_on_slot_item_added)
	slot.item_removed.connect(_on_slot_item_removed)
	slots.append(slot)

func unregister_slot(slot: InventorySlot):
	var i = slots.find(slot)
	
	if i > -1:
		slots[i].item_added.disconnect(_on_slot_item_added)
		slots[i].item_removed.disconnect(_on_slot_item_removed)
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

func _on_slot_item_added(sender: InventorySlot, item: Item):
	slot_item_added.emit(self, sender, item)
	print(item)

func _on_slot_item_removed(sender: InventorySlot, item: Item):
	slot_item_removed.emit(self, sender, item)
