class_name MountPoint
extends Node2D

@export var connection: MountPoint
@export var joint: Joint2D
@export var tag: String
var doing = false

func _connection_tree_exiting():
	unplug()

func plug(other: MountPoint) -> Joint2D:
	unplug()
	
	joint = PinJoint2D.new()
	joint.position = position

	var body1 = get_parent()
	var body2 = other.get_parent()

	body2.position = body1.position - other.position + position
	body2.rotation = body1.rotation
	
	connection = other
	
	if connection:
		connection.connect("tree_exiting", _connection_tree_exiting)
	
	return joint 

func unplug():
	if connection:
		connection.disconnect("tree_exiting", _connection_tree_exiting)
		connection.unplug()
	
	connection = null
	
	if joint:
		joint.queue_free() 

func do_body(action: String):
	var body = get_parent() as MountableBody
	body.do(action, "")

func do(action: String):
	if doing:
		return
	
	doing = true
	
	if connection:
		connection.do(action)
	else:
		do_body(action)
	
	doing = false
