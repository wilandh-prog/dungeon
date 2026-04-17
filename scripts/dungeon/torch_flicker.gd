extends Node3D

var _light: OmniLight3D = null
var _base_energy: float = 1.8
var _time_offset: float = 0.0

func _ready() -> void:
	_time_offset = randf() * TAU
	for child in get_children():
		if child is OmniLight3D:
			_light = child
			_base_energy = _light.light_energy
			break

func _process(_delta: float) -> void:
	if _light == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var f := sin(t * 9.0 + _time_offset) * 0.15 \
		   + sin(t * 14.7 + _time_offset * 0.7) * 0.08 \
		   + sin(t * 23.1 + _time_offset * 1.4) * 0.04
	_light.light_energy = _base_energy * max(0.6, 1.0 + f)
