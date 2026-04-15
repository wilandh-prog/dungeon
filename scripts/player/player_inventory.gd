extends Node

signal fragment_added(fragment: SpellFragment)
signal fragment_removed(fragment: SpellFragment)
signal spell_equipped(slot: int, spell_data: Dictionary)
signal active_spell_changed(slot: int)

var fragments: Array[SpellFragment] = []
var spell_slots: Array[Dictionary] = [{}, {}, {}, {}] # 4 spell slots
var active_slot: int = 0

func add_fragment(fragment: SpellFragment) -> void:
	fragments.append(fragment)
	fragment_added.emit(fragment)
	GameManager.on_fragment_collected()

func remove_fragment(fragment: SpellFragment) -> void:
	var idx := fragments.find(fragment)
	if idx >= 0:
		fragments.remove_at(idx)
		fragment_removed.emit(fragment)

func get_fragment_count() -> int:
	return fragments.size()

func equip_spell(slot: int, spell_data: Dictionary) -> void:
	if slot >= 0 and slot < Constants.MAX_SPELL_SLOTS:
		spell_slots[slot] = spell_data
		spell_equipped.emit(slot, spell_data)

func get_active_spell() -> Dictionary:
	return spell_slots[active_slot]

func cycle_spell(direction: int) -> void:
	for i in range(1, Constants.MAX_SPELL_SLOTS):
		var candidate: int = ((active_slot + direction * i) % Constants.MAX_SPELL_SLOTS + Constants.MAX_SPELL_SLOTS) % Constants.MAX_SPELL_SLOTS
		if not spell_slots[candidate].is_empty():
			active_slot = candidate
			active_spell_changed.emit(active_slot)
			return

func has_spell_equipped() -> bool:
	return not spell_slots[active_slot].is_empty()
