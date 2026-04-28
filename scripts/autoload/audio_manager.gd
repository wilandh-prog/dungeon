extends Node

var sfx_players: Dictionary = {}

const SFX_NAMES := [
	"spell_cast", "spell_hit", "enemy_hit", "enemy_death",
	"player_hit", "pickup_fragment", "door_open", "ui_click", "boss_intro",
]

func _ready() -> void:
	for sfx_name in SFX_NAMES:
		var player := AudioStreamPlayer.new()
		player.name = sfx_name
		player.bus = "Master"
		add_child(player)
		sfx_players[sfx_name] = player
		var path := "res://resources/audio/%s.ogg" % sfx_name
		if ResourceLoader.exists(path):
			player.stream = load(path)

func play(sfx_name: String, pitch_scale: float = 1.0) -> void:
	if sfx_players.has(sfx_name):
		var player: AudioStreamPlayer = sfx_players[sfx_name]
		if player.stream != null:
			player.pitch_scale = pitch_scale
			player.play()

func set_stream(sfx_name: String, stream: AudioStream) -> void:
	if sfx_players.has(sfx_name):
		sfx_players[sfx_name].stream = stream
