extends Node

const ELEMENT_STATS := {
	"FIRE": {"base_damage": 25.0, "mana_cost": 15.0, "color": Color(1.0, 0.3, 0.1), "status_effect": "burn", "status_duration": 3.0},
	"ICE": {"base_damage": 18.0, "mana_cost": 12.0, "color": Color(0.3, 0.7, 1.0), "status_effect": "slow", "status_duration": 4.0},
	"LIGHTNING": {"base_damage": 30.0, "mana_cost": 20.0, "color": Color(1.0, 1.0, 0.3), "status_effect": "stun", "status_duration": 1.5},
	"ARCANE": {"base_damage": 22.0, "mana_cost": 18.0, "color": Color(0.8, 0.3, 1.0), "status_effect": "none", "status_duration": 0.0},
	"NATURE": {"base_damage": 15.0, "mana_cost": 10.0, "color": Color(0.2, 0.8, 0.3), "status_effect": "poison", "status_duration": 5.0},
}

const SHAPE_STATS := {
	"BOLT": {"speed": 20.0, "range": 30.0, "aoe_radius": 0.0, "damage_multiplier": 1.0, "mana_multiplier": 1.0},
	"NOVA": {"speed": 0.0, "range": 0.0, "aoe_radius": 5.0, "damage_multiplier": 0.8, "mana_multiplier": 1.3},
	"BEAM": {"speed": 0.0, "range": 15.0, "aoe_radius": 0.0, "damage_multiplier": 0.5, "mana_multiplier": 1.5},
	"ORB": {"speed": 8.0, "range": 20.0, "aoe_radius": 3.0, "damage_multiplier": 1.2, "mana_multiplier": 1.4},
	"WALL": {"speed": 0.0, "range": 8.0, "aoe_radius": 0.0, "damage_multiplier": 0.6, "mana_multiplier": 1.2},
}

const HYBRID_ELEMENTS := {
	"FIRE+ICE": {"name": "STEAM", "color": Color(0.8, 0.8, 0.9), "bonus": "stun", "bonus_duration": 2.0, "damage_mult": 1.1},
	"FIRE+LIGHTNING": {"name": "PLASMA", "color": Color(1.0, 0.6, 0.2), "bonus": "aoe_on_hit", "bonus_duration": 0.0, "damage_mult": 1.3},
	"FIRE+ARCANE": {"name": "HELLFIRE", "color": Color(0.8, 0.1, 0.3), "bonus": "dot_ignore_resist", "bonus_duration": 4.0, "damage_mult": 1.15},
	"FIRE+NATURE": {"name": "ASH", "color": Color(0.5, 0.4, 0.3), "bonus": "slow_damage", "bonus_duration": 3.0, "damage_mult": 1.0},
	"ICE+LIGHTNING": {"name": "SHATTER", "color": Color(0.5, 0.8, 1.0), "bonus": "bonus_vs_cc", "bonus_duration": 0.0, "damage_mult": 1.2},
	"ICE+ARCANE": {"name": "VOID FROST", "color": Color(0.3, 0.2, 0.7), "bonus": "pull_slow", "bonus_duration": 3.0, "damage_mult": 1.0},
	"ICE+NATURE": {"name": "THORN ICE", "color": Color(0.2, 0.6, 0.5), "bonus": "ground_damage", "bonus_duration": 5.0, "damage_mult": 1.05},
	"LIGHTNING+ARCANE": {"name": "SURGE", "color": Color(0.9, 0.5, 1.0), "bonus": "fast_cast", "bonus_duration": 0.0, "damage_mult": 1.25},
	"LIGHTNING+NATURE": {"name": "STORM", "color": Color(0.4, 0.7, 0.3), "bonus": "random_hits", "bonus_duration": 0.0, "damage_mult": 1.1},
	"ARCANE+NATURE": {"name": "WILD MAGIC", "color": Color(0.6, 0.4, 0.8), "bonus": "random_property", "bonus_duration": 0.0, "damage_mult": 1.4},
}

const MODIFIER_NAMES := {
	"NONE": "",
	"CHAIN": "Chain",
	"SPLIT": "Split",
	"PIERCE": "Piercing",
	"AMPLIFY": "Amplified",
}

const SHAPE_NAMES := {
	"BOLT": "Bolt",
	"NOVA": "Nova",
	"BEAM": "Beam",
	"ORB": "Orb",
	"WALL": "Wall",
}

# Discovery tracking
var discovered_combos: Dictionary = {}
var total_possible_combos: int = 0

func _ready() -> void:
	# 5 elements + 10 hybrids = 15 element options, 5 shapes, 5 modifiers
	# But we count unique combos the player can discover
	total_possible_combos = 5 * 5 * 5 # element * shape * modifier (single element)
	total_possible_combos += 10 * 5 * 5 # hybrid * shape * modifier
	# Simplified: just count what players actually craft
	total_possible_combos = 50 # reasonable target

func get_hybrid_key(elem1: String, elem2: String) -> String:
	var sorted := [elem1, elem2]
	sorted.sort()
	return sorted[0] + "+" + sorted[1]

func compute_spell(fragments: Array) -> Dictionary:
	if fragments.size() < 1 or fragments.size() > 3:
		return {}

	var elements: Array[String] = []
	var shape := ""
	var modifiers: Array[String] = []

	for frag in fragments:
		if frag.element != "" and frag.element != "NONE":
			elements.append(frag.element)
		if frag.shape != "" and frag.shape != "NONE" and shape == "":
			shape = frag.shape
		if frag.modifier != "" and frag.modifier != "NONE":
			modifiers.append(frag.modifier)

	if shape == "":
		shape = "BOLT" # default fallback

	# Determine element
	var is_empowered := false
	var is_hybrid := false
	var element_name := ""
	var element_color := Color.WHITE
	var base_damage := 20.0
	var base_mana := 15.0
	var status_effect := "none"
	var status_duration := 0.0
	var hybrid_bonus := ""
	var hybrid_bonus_duration := 0.0
	var extra_damage_mult := 1.0

	if elements.size() == 0:
		element_name = "ARCANE"
		var e_stats: Dictionary = ELEMENT_STATS["ARCANE"]
		base_damage = e_stats.base_damage
		base_mana = e_stats.mana_cost
		element_color = e_stats.color
		status_effect = e_stats.status_effect
		status_duration = e_stats.status_duration
	elif elements.size() == 1 or (elements.size() >= 2 and elements[0] == elements[1]):
		var elem: String = elements[0]
		var e_stats: Dictionary = ELEMENT_STATS[elem]
		base_damage = e_stats.base_damage
		base_mana = e_stats.mana_cost
		element_color = e_stats.color
		status_effect = e_stats.status_effect
		status_duration = e_stats.status_duration
		element_name = elem

		if elements.size() >= 2 and elements[0] == elements[1]:
			is_empowered = true
			base_damage *= Constants.EMPOWERED_DAMAGE_MULT
			base_mana *= Constants.EMPOWERED_MANA_MULT
	else:
		# Hybrid
		is_hybrid = true
		var key := get_hybrid_key(elements[0], elements[1])
		if HYBRID_ELEMENTS.has(key):
			var hybrid: Dictionary = HYBRID_ELEMENTS[key]
			element_name = hybrid.name
			element_color = hybrid.color
			hybrid_bonus = hybrid.bonus
			hybrid_bonus_duration = hybrid.bonus_duration
			extra_damage_mult = hybrid.damage_mult
			# Average the two elements' base stats
			var e1: Dictionary = ELEMENT_STATS[elements[0]]
			var e2: Dictionary = ELEMENT_STATS[elements[1]]
			base_damage = (e1.base_damage + e2.base_damage) / 2.0 * extra_damage_mult
			base_mana = (e1.mana_cost + e2.mana_cost) / 2.0
		else:
			element_name = elements[0]
			var e_stats: Dictionary = ELEMENT_STATS[elements[0]]
			base_damage = e_stats.base_damage
			base_mana = e_stats.mana_cost
			element_color = e_stats.color

	# Apply shape stats
	var s_stats: Dictionary = SHAPE_STATS[shape]
	var final_damage: float = base_damage * s_stats.damage_multiplier
	var final_mana: float = base_mana * s_stats.mana_multiplier

	# Apply modifiers
	for mod in modifiers:
		match mod:
			"AMPLIFY":
				final_damage *= Constants.AMPLIFY_DAMAGE_MULT
				final_mana *= Constants.AMPLIFY_MANA_MULT
			"CHAIN", "SPLIT", "PIERCE":
				final_mana *= 1.2

	# Build spell name
	var name_parts: Array[String] = []
	for mod in modifiers:
		if MODIFIER_NAMES.has(mod) and MODIFIER_NAMES[mod] != "":
			name_parts.append(MODIFIER_NAMES[mod])
	if is_empowered:
		name_parts.append("Greater")
	name_parts.append(element_name.capitalize() if not is_hybrid else element_name)
	name_parts.append(SHAPE_NAMES[shape])
	var spell_name := " ".join(name_parts)

	# Build combo key for discovery tracking
	var combo_key := element_name + "_" + shape
	for mod in modifiers:
		combo_key += "_" + mod
	if not discovered_combos.has(combo_key):
		discovered_combos[combo_key] = true

	return {
		"name": spell_name,
		"element": element_name,
		"shape": shape,
		"modifiers": modifiers.duplicate(),
		"damage": final_damage,
		"mana_cost": final_mana,
		"color": element_color,
		"speed": s_stats.speed,
		"range": s_stats.range,
		"aoe_radius": s_stats.aoe_radius,
		"status_effect": status_effect,
		"status_duration": status_duration,
		"hybrid_bonus": hybrid_bonus,
		"hybrid_bonus_duration": hybrid_bonus_duration,
		"is_empowered": is_empowered,
		"is_hybrid": is_hybrid,
		"is_beam": shape == "BEAM",
	}

func get_discovery_count() -> int:
	return discovered_combos.size()
