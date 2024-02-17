class_name MountableBody
extends RigidBody2D

func mount_weapon(what: MountableWeapon, where: String):
	var mount1 = get_mount(where)
	var mount2 = what.get_mount("")
	
	link(mount1, mount2)
	
	what.z_index = -127
	
func link(point1: MountPoint, point2: MountPoint):
	point1.unplug()
	point2.unplug()
	
	var joint = point1.plug(point2)
	
	## set all necessary params to joint
	joint.node_a = point1.get_parent().get_path()
	joint.node_b = point2.get_parent().get_path()
	add_child(joint)
	
	# just a fixing joint
	var joint2 = PinJoint2D.new()
	joint2.position = joint.position + Vector2(100, 100)
	joint2.node_a = point1.get_parent().get_path()
	joint2.node_b = point2.get_parent().get_path()
	add_child(joint2)

func do(action: String, where: String):
	var mount = get_mount(where)
	if mount:
		mount.do(action)

func get_mounts():
	return find_children("*", "MountPoint")	
	
func get_mount(tag: String = "") -> MountPoint:
	for mount in get_mounts():
		if mount.tag == tag:
			return mount
	
	return null
