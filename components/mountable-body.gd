class_name MountableBody
extends Body

var mounts = []

func _physics_process(_delta):
	for item in mounts:
		var mount = item as MountPoint
		var opposite = mount.body_opposite
		if opposite:
			opposite.scale = scale
			opposite.global_position = mount.global_position
			opposite.rotation = mount.rotation

func mount_weapon(what: MountableWeapon, where: String):
	var mount1 = get_mount(where)
	var mount2 = what.get_mount("")
	
	mount1.plug(mount2)
	
	mounts = get_mounts()

func do(sender: MountableBody, action: String, where: String, meta = null):
	if not sender:
		sender = self
	
	if action == "recoil":
		var vector = -Vector2.from_angle(sender.global_rotation) * meta
		var place = sender.global_position / 100
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
