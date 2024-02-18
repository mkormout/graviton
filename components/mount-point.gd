class_name MountPoint
extends Node2D

@export var connection: MountPoint
@export var tag: String

var joint1: Joint2D
var joint2: Joint2D

func plug(other: MountPoint):
	unplug()

	var body1 = get_parent()
	var body2 = other.get_parent()

	body2.position = body1.position - other.position + position
	body2.rotation = body1.rotation
	
	connection = other
	
	joint1 = PinJoint2D.new()
	joint1.position = position
	joint1.node_a = body1.get_path()
	joint1.node_b = body2.get_path()
	body1.add_child(joint1)
	
	joint2 = PinJoint2D.new()
	joint2.position = position + Vector2(100, 100)
	joint2.node_a = body1.get_path()
	joint2.node_b = body2.get_path()
	body1.add_child(joint2)

func unplug():	
	if joint1:
		joint1.queue_free()
	if joint2:
		joint2.queue_free()
	connection = null

func do_body(action: String):
	var body = get_parent() as MountableBody
	body.do(action, "")

func do(action: String):
	if connection:
		connection.do(action)
	else:
		do_body(action)
