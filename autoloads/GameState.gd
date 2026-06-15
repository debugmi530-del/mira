extends Node

enum Phase {
	COMPANION,
	CRASH,
	HORROR,
	FINAL
}

var current_phase: Phase = Phase.COMPANION
var first_message_sent: bool = false
var session_start_time: int = 0
var app_launched_count: int = 0

signal phase_changed(new_phase: Phase)
signal fear_score_updated(score: int)

func _ready() -> void:
	session_start_time = Time.get_unix_time_from_system()
	app_launched_count = MemorySystem.get_value("app_launched_count", 0) + 1
	MemorySystem.set_value("app_launched_count", app_launched_count)
	MemorySystem.set_value("last_launch", Time.get_unix_time_from_system())

func set_phase(phase: Phase) -> void:
	current_phase = phase
	MemorySystem.set_value("last_phase", phase)
	emit_signal("phase_changed", phase)

func on_first_message() -> void:
	first_message_sent = true
	MemorySystem.set_value("first_message_time", Time.get_unix_time_from_system())
	set_phase(Phase.CRASH)

func get_session_duration() -> int:
	return Time.get_unix_time_from_system() - session_start_time

func is_returning_user() -> bool:
	return app_launched_count > 1

func get_days_since_first_launch() -> int:
	var first = MemorySystem.get_value("first_launch", Time.get_unix_time_from_system())
	var now = Time.get_unix_time_from_system()
	return int((now - first) / 86400)

func record_escape_attempt() -> void:
	var attempts = MemorySystem.get_value("escape_attempts", 0) + 1
	MemorySystem.set_value("escape_attempts", attempts)
	FearProfile.add_fear(5)

func record_fear_event(event: String) -> void:
	var events = MemorySystem.get_value("fear_events", [])
	events.append({"event": event, "time": Time.get_unix_time_from_system()})
	MemorySystem.set_value("fear_events", events)
