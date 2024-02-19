class_name MountableBody
extends Body

func mount_weapon(what: MountableWeapon, where: String):
	var mount1 = get_mount(where)
	var mount2 = what.get_mount("")
	
	mount1.plug(mount2)

func do(sender: MountableBody, action: String, where: String, meta = null):
	if not sender:
		sender = self
	
	if action == "recoil":
		var vector = -Vector2.from_angle(sender.rotation) * meta
		var place = sender.position / 100
		apply_impulse(vector, place)
	
	if sender == self:
		var mount = get_mount(where)
		if mount:
			mount.do(sender, action, meta)

func get_mounts():
	return find_children("*", "MountPoint")	
	
func get_mount(tag: String = "") -> MountPoint:
	for mount in get_mounts():
		if mount.tag == tag:
			return mount
	
	return null
