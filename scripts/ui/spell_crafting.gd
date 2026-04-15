extends Control

signal spell_crafted(spell_data: Dictionary)

@onready var inventory_list: ItemList = $PanelContainer/HBox/InventoryPanel/InventoryList
@onready var slot1_button: Button = $PanelContainer/HBox/CraftingPanel/VBox/Slots/Slot1
@onready var slot2_button: Button = $PanelContainer/HBox/CraftingPanel/VBox/Slots/Slot2
@onready var slot3_button: Button = $PanelContainer/HBox/CraftingPanel/VBox/Slots/Slot3
@onready var craft_button: Button = $PanelContainer/HBox/CraftingPanel/VBox/CraftButton
@onready var clear_button: Button = $PanelContainer/HBox/CraftingPanel/VBox/ClearButton
@onready var preview_label: Label = $PanelContainer/HBox/PreviewPanel/VBox/PreviewText
@onready var equip_option: OptionButton = $PanelContainer/HBox/CraftingPanel/VBox/EquipSlot

var player_inventory: Node = null
var crafting_slots: Array[SpellFragment] = [null, null, null]
var selected_slot: int = -1
var _list_index_to_fragment: Array[SpellFragment] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	slot1_button.pressed.connect(func(): _on_slot_pressed(0))
	slot2_button.pressed.connect(func(): _on_slot_pressed(1))
	slot3_button.pressed.connect(func(): _on_slot_pressed(2))
	craft_button.pressed.connect(_on_craft)
	clear_button.pressed.connect(_on_clear)
	inventory_list.item_selected.connect(_on_inventory_item_selected)

	# Disable focus on all interactive elements so Tab isn't consumed by UI navigation
	for btn: Button in [slot1_button, slot2_button, slot3_button, craft_button, clear_button]:
		btn.focus_mode = Control.FOCUS_NONE
	equip_option.focus_mode = Control.FOCUS_NONE
	inventory_list.focus_mode = Control.FOCUS_CLICK

	# Equip slot options
	for i in Constants.MAX_SPELL_SLOTS:
		equip_option.add_item("Slot %d" % (i + 1), i)

	visible = false

func open(inventory: Node) -> void:
	player_inventory = inventory
	visible = true
	_refresh_inventory()
	_refresh_preview()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.set_crafting(true)

func close() -> void:
	visible = false
	_on_clear()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.set_crafting(false)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("open_crafting"):
		close()
		get_viewport().set_input_as_handled()

func _refresh_inventory() -> void:
	inventory_list.clear()
	_list_index_to_fragment.clear()
	if player_inventory == null:
		return

	for frag: SpellFragment in player_inventory.fragments:
		# Skip fragments already placed in crafting slots
		if frag in crafting_slots:
			continue
		var idx := inventory_list.add_item(frag.get_display_name())
		inventory_list.set_item_custom_fg_color(idx, frag.icon_color)
		_list_index_to_fragment.append(frag)

func _on_inventory_item_selected(index: int) -> void:
	if player_inventory == null:
		return
	if index < 0 or index >= _list_index_to_fragment.size():
		return

	# Find first empty slot
	var target_slot := -1
	for i in 3:
		if crafting_slots[i] == null:
			target_slot = i
			break

	if target_slot == -1:
		return # All slots full

	var frag: SpellFragment = _list_index_to_fragment[index]
	crafting_slots[target_slot] = frag
	_refresh_inventory() # Re-filter list to hide placed fragment
	_refresh_slots()
	_refresh_preview()

func _on_slot_pressed(slot: int) -> void:
	# Remove fragment from slot
	crafting_slots[slot] = null
	_refresh_inventory() # Show returned fragment in list again
	_refresh_slots()
	_refresh_preview()

func _refresh_slots() -> void:
	var buttons := [slot1_button, slot2_button, slot3_button]
	for i in 3:
		if crafting_slots[i] != null:
			buttons[i].text = crafting_slots[i].get_display_name()
			buttons[i].modulate = crafting_slots[i].icon_color
		else:
			buttons[i].text = "[Empty]"
			buttons[i].modulate = Color.WHITE

func _refresh_preview() -> void:
	var frags: Array = []
	for slot in crafting_slots:
		if slot != null:
			frags.append(slot)

	if frags.is_empty():
		preview_label.text = "Place fragments to preview spell"
		craft_button.disabled = true
		return

	var spell: Dictionary = SpellDatabase.compute_spell(frags)
	if spell.is_empty():
		preview_label.text = "Invalid combination"
		craft_button.disabled = true
		return

	craft_button.disabled = false
	var text := ""
	text += "Name: %s\n" % spell.name
	text += "Damage: %.1f\n" % spell.damage
	text += "Mana Cost: %.1f\n" % spell.mana_cost
	text += "Element: %s\n" % spell.element
	text += "Shape: %s\n" % spell.shape
	if spell.status_effect != "none":
		text += "Status: %s (%.1fs)\n" % [spell.status_effect, spell.status_duration]
	if spell.is_empowered:
		text += "EMPOWERED!\n"
	if spell.is_hybrid:
		text += "Hybrid Bonus: %s\n" % spell.hybrid_bonus
	if spell.modifiers.size() > 0:
		text += "Modifiers: %s\n" % ", ".join(spell.modifiers)
	preview_label.text = text

func _on_craft() -> void:
	var frags: Array = []
	for slot in crafting_slots:
		if slot != null:
			frags.append(slot)

	if frags.is_empty():
		return

	var spell: Dictionary = SpellDatabase.compute_spell(frags)
	if spell.is_empty():
		return

	# Remove used fragments from inventory
	for frag: SpellFragment in frags:
		player_inventory.remove_fragment(frag)

	# Equip to selected slot
	var slot_idx: int = equip_option.get_selected_id()
	player_inventory.equip_spell(slot_idx, spell)

	GameManager.on_spell_crafted()
	SdkManager.happy_time()
	spell_crafted.emit(spell)

	# Auto-close after successful craft
	close()

func _on_clear() -> void:
	crafting_slots = [null, null, null]
	_refresh_slots()
	_refresh_preview()
