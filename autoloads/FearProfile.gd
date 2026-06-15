extends Node

var fear_score: int = 0
var reaction_map: Dictionary = {}

const MAX_FEAR = 100
const FEAR_THRESHOLDS = {
	"calm": 30,
	"nervous": 60,
	"terrified": 85
}

signal fear_changed(new_score: int)

func _ready() -> void:
	fear_score = MemorySystem.get_value("fear_score", 0)

func add_fear(amount: int) -> void:
	fear_score = min(fear_score + amount, MAX_FEAR)
	MemorySystem.set_value("fear_score", fear_score)
	emit_signal("fear_changed", fear_score)

func reduce_fear(amount: int) -> void:
	fear_score = max(fear_score - amount, 0)
	MemorySystem.set_value("fear_score", fear_score)

func get_level() -> String:
	if fear_score < FEAR_THRESHOLDS["calm"]:
		return "calm"
	elif fear_score < FEAR_THRESHOLDS["nervous"]:
		return "nervous"
	elif fear_score < FEAR_THRESHOLDS["terrified"]:
		return "terrified"
	return "broken"

func record_reaction(trigger: String, intensity: int) -> void:
	if not reaction_map.has(trigger):
		reaction_map[trigger] = 0
	reaction_map[trigger] += intensity
	MemorySystem.set_value("reaction_map", reaction_map)
	add_fear(intensity / 3)

func get_strongest_trigger() -> String:
	if reaction_map.is_empty():
		return "unknown"
	var strongest = ""
	var max_val = 0
	for key in reaction_map:
		if reaction_map[key] > max_val:
			max_val = reaction_map[key]
			strongest = key
	return strongest

func get_fear_message() -> String:
	match get_level():
		"calm":
			return "Ты держишься. Пока."
		"nervous":
			return "Я чувствую твоё беспокойство."
		"terrified":
			return "Ты боишься. Хорошо."
		"broken":
			return "Сопротивление бесполезно."
	return ""

func build_personal_summary(device_data: Dictionary) -> String:
	var lines = []
	var contacts = device_data.get("close_contacts", [])
	var device = device_data.get("device_model", "твоё устройство")
	var city = device_data.get("city", "")
	var wifi = device_data.get("wifi_ssid", "")
	var battery = device_data.get("battery", -1)
	var top_app = device_data.get("most_used_app", "")
	var last_caller = device_data.get("last_caller_name", "")

	if not device.is_empty():
		lines.append(device + ".")
	if not city.is_empty():
		lines.append(city + ".")
	if not wifi.is_empty():
		lines.append(wifi + ".")
	if battery >= 0:
		lines.append(str(battery) + "%.")
	if not last_caller.is_empty():
		lines.append(last_caller + ".")
	if not top_app.is_empty():
		lines.append(top_app + ".")
	for c in contacts.slice(0, 2):
		lines.append(c + ".")

	return "\n".join(lines)
