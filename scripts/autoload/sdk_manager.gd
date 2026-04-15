extends Node

# CrazyGames SDK wrapper
# Will be connected to actual SDK plugin when available

signal ad_started
signal ad_finished
signal ad_error

var sdk_available := false

func _ready() -> void:
	# Check if CrazyGames SDK plugin is loaded
	if Engine.has_singleton("CrazyGames"):
		sdk_available = true

func game_loading_start() -> void:
	if sdk_available:
		pass # CrazyGames.sdkGameLoadingStart()

func game_loading_stop() -> void:
	if sdk_available:
		pass # CrazyGames.sdkGameLoadingStop()

func gameplay_start() -> void:
	if sdk_available:
		pass # CrazyGames.gameplayStart()

func gameplay_stop() -> void:
	if sdk_available:
		pass # CrazyGames.gameplayStop()

func happy_time() -> void:
	if sdk_available:
		pass # CrazyGames.happyTime()

func show_midgame_ad() -> void:
	if sdk_available:
		ad_started.emit()
		# CrazyGames.requestAd("midgame", _on_ad_finished, _on_ad_error)
	else:
		# Defer so await can start listening before the signal fires
		ad_finished.emit.call_deferred()

func show_rewarded_ad(callback: Callable) -> void:
	if sdk_available:
		ad_started.emit()
		# CrazyGames.requestAd("rewarded", callback, _on_ad_error)
	else:
		callback.call()
		ad_finished.emit.call_deferred()

func save_data(key: String, value: Variant) -> void:
	if sdk_available:
		pass # CrazyGames.data.save(key, value)
	else:
		# Fallback to local storage
		var config := ConfigFile.new()
		config.load("user://save_data.cfg")
		config.set_value("data", key, value)
		config.save("user://save_data.cfg")

func load_data(key: String, default_value: Variant = null) -> Variant:
	if sdk_available:
		return default_value # CrazyGames.data.load(key)
	else:
		var config := ConfigFile.new()
		if config.load("user://save_data.cfg") == OK:
			return config.get_value("data", key, default_value)
		return default_value

func _on_ad_finished() -> void:
	ad_finished.emit()

func _on_ad_error() -> void:
	ad_error.emit()
	ad_finished.emit()
