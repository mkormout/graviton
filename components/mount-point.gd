class_name MountPoint
extends Node2D

@export var connection: MountPoint
@export var tag: String

var joint1: Joint2D
var joint2: Joint2D

func _ready():
	joint1 = PinJoint2D.new()
	joint1.position = position
	joint2 = PinJoint2D.new()
	joint2.position = position + Vector2(500, 100)
	add_child(joint1)
	add_child(joint2)

func plug(other: MountPoint):
	unplug()

	var body1 = get_parent() as Node2D
	var body2 = other.get_parent() as Node2D

	get_tree().current_scene.add_child(body2)

	body2.transform = body1.transform

	body2.position = body1.position - other.position + position
	body2.rotation = body1.rotation
	
	connection = other
	other.connection = self
	
	connection.connect("tree_exiting", _connection_tree_exiting)
	
	joint1.node_a = body1.get_path()
	joint1.node_b = body2.get_path()
	joint2.node_a = body1.get_path()
	joint2.node_b = body2.get_path()
	
func unplug():
	joint1.node_a = ""
	joint1.node_b = ""
	joint2.node_a = ""
	joint2.node_b = ""
	
	if connection:
		connection.disconnect("tree_exiting", _connection_tree_exiting)
	
	connection = null

func get_body_self() -> MountableBody:
	return get_parent() as MountableBody

func get_body_opposite() -> MountableBody:
	return connection.get_parent() as MountableBody if connection else null

func do(sender: MountableBody, action: String, meta = null):
	if sender == get_body_self() and connection:
		connection.do(sender, action, meta)
		return
	
	if sender == get_body_opposite():
		get_body_self().do(sender, action, "", meta)
		return

func _connection_tree_exiting():
	unplug()
