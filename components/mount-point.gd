class_name MountPoint
extends Node2D

@export var connection: MountPoint
@export var tag: String
@export var throw_force: int = 1000

var joint1: Joint2D
var joint2: Joint2D

var body_opposite: MountableBody:
	get: return get_body_opposite()
var body_self: MountableBody:
	get: return get_body_self()
	
func _ready():
	joint1 = PinJoint2D.new()
	joint1.position = position
	
	joint2 = PinJoint2D.new()
	joint2.position = position + Vector2(200, 200)
	
	add_child(joint1)
	add_child(joint2)

func plug(other: MountPoint):
	unplug()
	
	connection = other
	other.connection = self

	var body1 = body_self
	var body2 = body_opposite

	body2.rotation = body1.rotation
	body2.global_position = body1.global_position + body1.transform.basis_xform(position - other.position)
	
	get_tree().current_scene.add_child(body2)
	
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
		# throw away the body
		body_opposite.apply_central_impulse(
			Vector2.from_angle(body_opposite.rotation) * throw_force
		)
		# free
		connection.disconnect("tree_exiting", _connection_tree_exiting)
	
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
