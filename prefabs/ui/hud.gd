class_name HudDebugPanel
extends CanvasLayer

@export var ship: MountableBody

@onready var health = $Panel/MarginContainer/VBoxContainer/Panel/HealthValue
@onready var coins = $Panel/MarginContainer/VBoxContainer/Panel2/CoinsValue

@onready var weapon_front = $Panel/MarginContainer/GridContainer/WeaponFrontDebug
@onready var weapon_left = $Panel/MarginContainer/GridContainer/WeaponLeftDebug
@onready var weapon_right = $Panel/MarginContainer/GridContainer/WeaponRightDebug

var initialized: bool = false
var mount_front: MountPoint
var mount_left: MountPoint
var mount_right: MountPoint

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if not ship:
		return 
	
	if not initialized:
		if ship:
			mount_front = ship.get_mount("")
			mount_left = ship.get_mount("left")
			mount_right = ship.get_mount("right")
		initialized = true
		return
	
	if not weapon_front:
		return	
		
	weapon_front.weapon = mount_front.body_opposite
	weapon_left.weapon = mount_left.body_opposite
	weapon_right.weapon = mount_right.body_opposite
	
	health.value = ship.health
	health.max_value = ship.max_health
	coins.text = str(ship.coins)
	
