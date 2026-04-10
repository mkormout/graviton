class_name MountPoint
extends Node2D

signal plugging(sender: MountPoint, target: MountPoint)
signal unplugging(sender: MountPoint, target: MountPoint)

@export var connection: MountPoint
@export var tag: String
@export var throw_force: int = 1000
@export var spawn_parent: Node

var slots: Array[InventorySlot] = []
var is_notifying: bool = false

var body_opposite: MountableBody:
	get: return get_body_opposite()
var body_self: MountableBody:
	get: return get_body_self()

func _ready():
	pass

func plug(other: MountPoint):
	unplug()

	plugging.emit(self, other)

	connection = other
	other.connection = self

	add_child(body_opposite)

	call_slots(
		func(slot: InventorySlot):
			slot.inc(body_opposite.item_type)
	)

func unplug(free: bool = false):
	if connection:
		var departing_body = body_opposite  # cache before any signal

		# throw away the body
		departing_body.apply_central_impulse(
			Vector2.from_angle(departing_body.rotation) * throw_force
		)
		if spawn_parent:
			departing_body.reparent(spawn_parent)
		else:
			push_warning("spawn_parent not set on " + name)

		unplugging.emit(self, connection)

		if free and is_instance_valid(departing_body):
			departing_body.queue_free()

		call_slots(
			func(slot: InventorySlot):
				slot.dec(departing_body.item_type)
		)

	connection = null

func get_body_self() -> MountableBody:
	return get_parent() as MountableBody

func get_body_opposite() -> MountableBody:
	return connection.get_parent() as MountableBody if connection else null

func do(sender: MountableBody, action: MountableBody.Action, meta = null):
	if sender == body_self and connection:
		connection.do(sender, action, meta)
		return

	if sender == body_opposite:
		body_self.do(sender, action, "", meta)
		return

func _connection_tree_exiting():
	unplug()

func link_slot(slot: InventorySlot) -> void:
	slot.item_adding.connect(_slot_item_adding)
	slot.item_removing.connect(_slot_item_removing)
	slots.append(slot)

func unlink_slot(slot: InventorySlot) -> void:
	slot.item_adding.disconnect(_slot_item_adding)
	slot.item_removing.disconnect(_slot_item_removing)
	slots.erase(slot)

func call_slots(slot_func: Callable):
	if is_notifying:
		return

	is_notifying = true

	for slot in slots:
		slot_func.call(slot)

	is_notifying = false

func _slot_item_adding(sender: InventorySlot, type: ItemType, quantity: int):
	if is_notifying:
		return

	var body = type.instantiate()
	if body_self:
		body_self._propagate_spawn_parent(body)
	plug(body.get_mount())

func _slot_item_removing(sender: InventorySlot, type: ItemType, quantity: int):
	if is_notifying:
		return

	unplug(true)
