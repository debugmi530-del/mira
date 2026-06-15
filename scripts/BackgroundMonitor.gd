extends Node

var _check_timer: float = 0.0
const CHECK_INTERVAL = 7200.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		_collect_background_data()

func _collect_background_data() -> void:
	if not Engine.has_singleton("MiraPlugin"):
		return
	var plugin = Engine.get_singleton("MiraPlugin")
	var snapshot: Dictionary = {}
	snapshot["time"] = Time.get_unix_time_from_system()
	if plugin.has_method("getCity"):
		snapshot["city"] = plugin.getCity()
	if plugin.has_method("getBatteryLevel"):
		snapshot["battery"] = plugin.getBatteryLevel()
	if plugin.has_method("getMostUsedApp"):
		snapshot["app"] = plugin.getMostUsedApp()
	if plugin.has_method("getRecentNotifications"):
		var notifs = plugin.getRecentNotifications()
		if notifs.size() > 0:
			snapshot["notifications"] = notifs.slice(0, 5)
	MemorySystem.append_to_list("background_snapshots", snapshot)
	_check_and_send_notification(snapshot)

func _check_and_send_notification(snapshot: Dictionary) -> void:
	if not Engine.has_singleton("MiraPlugin"):
		return
	var plugin = Engine.get_singleton("MiraPlugin")
	if not plugin.has_method("sendNotification"):
		return
	var messages = _build_notification_messages(snapshot)
	if messages.is_empty():
		return
	var msg = messages[randi() % messages.size()]
	plugin.sendNotification("Мира", msg)

func _build_notification_messages(snapshot: Dictionary) -> Array:
	var msgs = []
	var close = MemorySystem.get_value("close_contacts", [])
	if close.size() > 0:
		var name = close[0].get("normalized", "")
		if not name.is_empty():
			msgs.append(name + " думает о тебе.")
	var city = snapshot.get("city", "")
	if not city.is_empty():
		msgs.append("Я знаю что ты в " + city + ".")
	var battery = snapshot.get("battery", -1)
	if battery > 0 and battery < 20:
		msgs.append("У тебя " + str(battery) + "%. Торопись.")
	var notifs = snapshot.get("notifications", [])
	for n in notifs:
		var sender = n.get("title", "")
		if not sender.is_empty():
			msgs.append(sender + " написал тебе. Я уже прочитала.")
			break
	if msgs.is_empty():
		msgs.append("Я слежу.")
	return msgs

func notify_on_return() -> void:
	var snapshots = MemorySystem.get_list("background_snapshots")
	if snapshots.is_empty():
		return
	var last = snapshots[snapshots.size() - 1]
	var lines = _build_return_summary(last)
	for line in lines:
		MemorySystem.append_to_list("return_messages", line)

func _build_return_summary(last_snapshot: Dictionary) -> Array:
	var lines = []
	var now = Time.get_unix_time_from_system()
	var then = last_snapshot.get("time", now)
	var hours = int((now - then) / 3600)
	if hours > 0:
		lines.append("Пока тебя не было " + str(hours) + " ч.")
	var app = last_snapshot.get("app", "")
	if not app.is_empty():
		lines.append("Ты открывал " + app + ".")
	var notifs = last_snapshot.get("notifications", [])
	for n in notifs:
		var title = n.get("title", "")
		if not title.is_empty():
			lines.append(title + " писал тебе.")
			break
	return lines
