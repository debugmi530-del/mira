extends Node

const SAVE_PATH = "user://mira_memory.cfg"
var _data: Dictionary = {}
var _config: ConfigFile

func _ready() -> void:
	_config = ConfigFile.new()
	_load()
	if not _data.has("first_launch"):
		_data["first_launch"] = Time.get_unix_time_from_system()
		_save()

func _load() -> void:
	var err = _config.load(SAVE_PATH)
	if err == OK:
		for key in _config.get_section_keys("memory"):
			_data[key] = _config.get_value("memory", key)

func _save() -> void:
	for key in _data:
		_config.set_value("memory", key, _data[key])
	_config.save(SAVE_PATH)

func set_value(key: String, value) -> void:
	_data[key] = value
	_save()

func get_value(key: String, default = null):
	return _data.get(key, default)

func has(key: String) -> bool:
	return _data.has(key)

func append_to_list(key: String, value) -> void:
	var list = _data.get(key, [])
	list.append(value)
	if list.size() > 100:
		list = list.slice(list.size() - 100)
	set_value(key, list)

func get_list(key: String) -> Array:
	return _data.get(key, [])

func save_session(data: Dictionary) -> void:
	var sessions = get_list("sessions")
	data["timestamp"] = Time.get_unix_time_from_system()
	sessions.append(data)
	if sessions.size() > 20:
		sessions = sessions.slice(sessions.size() - 20)
	set_value("sessions", sessions)

func get_sessions() -> Array:
	return get_list("sessions")

func get_last_session() -> Dictionary:
	var sessions = get_sessions()
	if sessions.size() > 1:
		return sessions[sessions.size() - 2]
	return {}

func clear_all() -> void:
	_data.clear()
	_config = ConfigFile.new()
	_config.save(SAVE_PATH)
