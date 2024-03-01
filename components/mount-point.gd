class_name MountPoint
extends Node2D

signal plugging(sender: MountPoint, target: MountPoint)
signal unplugging(sender: MountPoint, target: MountPoint)

@export var connection: MountPoint
@export var tag: String
@export var throw_force: int = 1000

var body_opposite: MountableBody:
	get: return get_body_opposite()
var body_self: MountableBody:
	get: return get_body_self()
	
func _ready():
	pass

func plug(other: MountPoint):
	unplug()
	
	connection = other
	other.connection = self
	
	plugging.emit(self, other)
	
	add_child(body_opposite)
	
func unplug():	
	if connection:
		# throw away the body
		body_opposite.apply_central_impulse(
			Vector2.from_angle(body_opposite.rotation) * throw_force
		)
		body_opposite.reparent(get_tree().current_scene)
		
		unplugging.emit(self, connection)
	
	connection = null

func get_body_self() -> MountableBody:
	return get_parent() as MountableBody

func get_body_opposite() -> MountableBody:
	return connection.get_parent() as MountableBody if connection else null

func do(sender: MountableBody, action: String, meta = null):
	if sender == body_self and connection:
		connection.do(sender, action, meta)
		return
	
	if sender == body_opposite:
		body_self.do(sender, action, "", meta)
		return

func _connection_tree_exiting():
	unplug()
