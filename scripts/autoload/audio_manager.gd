extends Node

# Audio manager with placeholder structure
# Audio streams can be swapped in later without changing any calling code

var sfx_players: Dictionary = {}

const SFX_NAMES := [
	"spell_cast", "spell_hit", "enemy_hit", "enemy_death",
	"player_hit", "pickup_fragment", "door_open", "ui_click", "boss_intro",
]

func _ready() -> void:
	# Create AudioStreamPlayer for each sound effect
	for sfx_name in SFX_NAMES:
		var player := AudioStreamPlayer.new()
		player.name = sfx_name
		player.bus = "SFX"
		add_child(player)
		sfx_players[sfx_name] = player

func play(sfx_name: String) -> void:
	if sfx_players.has(sfx_name):
		var player: AudioStreamPlayer = sfx_players[sfx_name]
		if player.stream != null:
			player.play()

func set_stream(sfx_name: String, stream: AudioStream) -> void:
	if sfx_players.has(sfx_name):
		sfx_players[sfx_name].stream = stream
