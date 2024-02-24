class_name WeaponDebugPanel
extends Panel

@export var weapon: MountableWeapon

@onready var weapon_name = $MarginPanel/VBoxContainer/LabelWeaponName
@onready var cooldown_timer = $MarginPanel/VBoxContainer/GridContainer/LabelCooldownTimerValue
@onready var health = $MarginPanel/VBoxContainer/GridContainer/LabelHealthValue
@onready var magazine_ammo = $MarginPanel/VBoxContainer/GridContainer/LabelMagazineAmmoValue
@onready var recoil = $MarginPanel/VBoxContainer/GridContainer/LabelRecoilValue
@onready var reload_timer = $MarginPanel/VBoxContainer/GridContainer/LabelReloadTimerValue
@onready var total_ammo = $MarginPanel/VBoxContainer/GridContainer/LabelTotalAmmoValue
@onready var use_ammo = $MarginPanel/VBoxContainer/GridContainer/LabelUseAmmoValue
@onready var use_rate = $MarginPanel/VBoxContainer/GridContainer/LabelUseRateValue
@onready var velocity = $MarginPanel/VBoxContainer/GridContainer/LabelVelocityValue

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if not weapon:
		return
		
	weapon_name.text = weapon.name
	cooldown_timer.text = str(weapon.shot_timer.time_left).pad_decimals(1)
	health.text = str(weapon.health)
	magazine_ammo.text = str(weapon.magazine_current)
	velocity.text = str(weapon.velocity)
	recoil.text = str(weapon.recoil)
	reload_timer.text = str(weapon.reload_timer.time_left).pad_decimals(1)
	total_ammo.text = str(weapon.ammo_current)
	use_ammo.button_pressed = weapon.use_ammo
	use_rate.button_pressed = weapon.use_rate
