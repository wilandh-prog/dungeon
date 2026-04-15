class_name SpellFragment
extends Resource

@export var id: String
@export var element: String # FIRE, ICE, LIGHTNING, ARCANE, NATURE
@export var shape: String   # BOLT, NOVA, BEAM, ORB, WALL
@export var modifier: String # NONE, CHAIN, SPLIT, PIERCE, AMPLIFY
@export var icon_color: Color

static func create(p_element: String, p_shape: String, p_modifier: String = "NONE") -> SpellFragment:
	var frag := SpellFragment.new()
	frag.id = p_element + "_" + p_shape + "_" + p_modifier + "_" + str(randi())
	frag.element = p_element
	frag.shape = p_shape
	frag.modifier = p_modifier
	frag.icon_color = _get_color_for_element(p_element)
	return frag

static func create_random(rng: RandomNumberGenerator) -> SpellFragment:
	var elements := ["FIRE", "ICE", "LIGHTNING", "ARCANE", "NATURE"]
	var shapes := ["BOLT", "NOVA", "BEAM", "ORB", "WALL"]
	var elem: String = elements[rng.randi_range(0, elements.size() - 1)]
	var shape: String = shapes[rng.randi_range(0, shapes.size() - 1)]
	var modifier := _pick_weighted_modifier(rng)
	return SpellFragment.create(elem, shape, modifier)

static func _pick_weighted_modifier(rng: RandomNumberGenerator) -> String:
	var total_weight := 0
	for w in Constants.MODIFIER_WEIGHTS.values():
		total_weight += w
	var roll := rng.randi_range(0, total_weight - 1)
	var cumulative := 0
	for mod_name: String in Constants.MODIFIER_WEIGHTS:
		cumulative += Constants.MODIFIER_WEIGHTS[mod_name]
		if roll < cumulative:
			return mod_name
	return "NONE"

static func _get_color_for_element(elem: String) -> Color:
	if SpellDatabase.ELEMENT_STATS.has(elem):
		return SpellDatabase.ELEMENT_STATS[elem].color
	return Color.WHITE

func get_display_name() -> String:
	var parts: Array[String] = []
	if modifier != "NONE" and modifier != "":
		parts.append(modifier.capitalize())
	parts.append(element.capitalize())
	parts.append(shape.capitalize())
	return " ".join(parts)
