class_name MountPoint
extends Node2D

@export var connection: MountPoint
@export var joint: Joint2D
@export var tag: String

func plug(other: MountPoint) -> Joint2D:
	unplug()
	
	joint = PinJoint2D.new()
	joint.position = position

	var body1 = get_parent()
	var body2 = other.get_parent()

	body2.position = body1.position - other.position + position
	body2.rotation = body1.rotation
	
	connection = other
	
	return joint

func unplug():
	if connection:
		connection.unplug()
	
	connection = null
	
	if joint:
		joint.free()

func body() -> MountableBody:
	return get_parent() as MountableBody

func do(action: String):
	if connection:
		connection.do(action)
	else:
		body().do(action, "")
		
