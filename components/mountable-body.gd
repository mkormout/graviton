class_name MountableBody
extends Body

func mount_weapon(what: MountableWeapon, where: String):
	var mount1 = get_mount(where)
	var mount2 = what.get_mount("")
	
	mount1.plug(mount2)

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
