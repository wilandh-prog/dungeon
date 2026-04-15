extends Control

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxLeft/HPBar
@onready var mana_bar: ProgressBar = $MarginContainer/VBoxLeft/ManaBar
@onready var fragment_label: Label = $MarginContainer/TopRight/FragmentCount
@onready var spell_slots_container: HBoxContainer = $MarginContainer/BottomCenter/SpellSlots
@onready var minimap: Control = $MarginContainer/TopRight/Minimap
@onready var crosshair: Control = $Crosshair

var player: CharacterBody3D = null
var inventory: Node = null
var spell_labels: Array[Label] = []

func _ready() -> void:
	# Create spell slot labels
	for i in Constants.MAX_SPELL_SLOTS:
		var label := Label.new()
		label.text = "[%d] ---" % (i + 1)
		label.custom_minimum_size = Vector2(120, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spell_slots_container.add_child(label)
		spell_labels.append(label)

func setup(p_player: CharacterBody3D) -> void:
	player = p_player
	inventory = player.get_node("PlayerInventory")

	player.hp_changed.connect(_on_hp_changed)
	player.mana_changed.connect(_on_mana_changed)
	inventory.fragment_added.connect(_on_fragment_changed)
	inventory.fragment_removed.connect(_on_fragment_changed)
	inventory.spell_equipped.connect(_on_spell_equipped)
	inventory.active_spell_changed.connect(_on_active_spell_changed)

	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	mana_bar.max_value = player.max_mana
	mana_bar.value = player.mana
	fragment_label.text = "Fragments: 0"

func _on_hp_changed(current: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current

func _on_mana_changed(current: float, max_mana: float) -> void:
	mana_bar.max_value = max_mana
	mana_bar.value = current

func _on_fragment_changed(_fragment: SpellFragment) -> void:
	if inventory:
		fragment_label.text = "Fragments: %d" % inventory.get_fragment_count()

func _on_spell_equipped(slot: int, spell_data: Dictionary) -> void:
	if slot >= 0 and slot < spell_labels.size():
		if spell_data.is_empty():
			spell_labels[slot].text = "[%d] ---" % (slot + 1)
			spell_labels[slot].modulate = Color.WHITE
		else:
			spell_labels[slot].text = "[%d] %s" % [slot + 1, spell_data.name]
			spell_labels[slot].modulate = spell_data.get("color", Color.WHITE)

func _on_active_spell_changed(slot: int) -> void:
	for i in spell_labels.size():
		if i == slot:
			spell_labels[i].add_theme_font_size_override("font_size", 18)
		else:
			spell_labels[i].remove_theme_font_size_override("font_size")

func setup_minimap(rooms: Dictionary, connections: Array[Array]) -> void:
	minimap.update_data(rooms, connections)

func update_minimap_player(player_pos: Vector2i) -> void:
	minimap.set_player_room(player_pos)
