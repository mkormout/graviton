@tool
extends InventorySlot

@onready var texture_blue = preload("res://images/inventory-slot-blue.png")
@onready var texture_green = preload("res://images/inventory-slot-green.png")
@onready var texture_red = preload("res://images/inventory-slot-red.png")
@onready var texture_white = preload("res://images/inventory-slot-white.png")
@onready var texture_yellow = preload("res://images/inventory-slot-yellow.png")

@onready var background = $Background
@onready var item_image = $Background/Margin/ItemImage
@onready var quanity_panel = $Background/Margin/ItemImage/QuantityPanel
@onready var quanity = $Background/Margin/ItemImage/QuantityPanel/MarginContainer/Quantity

func _ready():
	var texture = null
	
	match slot_type:
		ItemSlotType.UTIL: texture = texture_blue
		ItemSlotType.ENGINE: texture = texture_green
		ItemSlotType.WEAPON: texture = texture_red
		ItemSlotType.STORAGE: texture = texture_yellow
		ItemSlotType.DROP: texture = texture_white
	
	background.texture = texture

func _process(delta):
	quanity_panel.visible = occupant != null or Engine.is_editor_hint()
	
	if occupant:
		item_image.texture = occupant.image
		quanity.text = str(quantity)
	else:
		item_image.texture = null
		
		if Engine.is_editor_hint():
			quanity.text = str(max_items)
		else:
			quanity.text = ""
