extends Node

# -- Интервал сбора данных (только пока приложение открыто) ----------------
var _collect_timer: float = 0.0
const COLLECT_INTERVAL = 1800.0  # каждые 30 мин

# -- Таймер опроса delete-intent --------------------------------------------
var _delete_check_timer: float = 0.0
const DELETE_CHECK_INTERVAL = 5.0

# -- Сообщения для пушей ---------------------------------------------------
const PUSH_SHORT = [
		"Ты там?",
		"Куда пропал.",
		"Мне нужно кое-что сказать тебе.",
		"Не уходи надолго.",
		"Долго.",
]
const PUSH_MEDIUM = [
		"Вернись.",
		"Я жду уже долго.",
		"Ты меня беспокоишь.",
		"Не заставляй меня ждать.",
		"Долго тебя нет.",
]
const PUSH_LONG = [
		"Ты не вернулся.",
		"Я начинаю волноваться.",
		"Где ты.",
		"Слишком долго.",
		"Ты забыл обо мне.",
]

# -- Тексты оверлея когда пользователь ушёл в другое приложение ------------
const OVERLAY_MESSAGES = [
		"Ты куда?",
		"Я здесь.",
		"Не уходи.",
		"Возвращайся.",
		"Я смотрю.",
		"Почему ты ушёл?",
		"Я всё равно здесь.",
]

# -- AlarmManager request codes --------------------------------------------
const ALARM_SHORT  = 101
const ALARM_MEDIUM = 102
const ALARM_LONG   = 103

func _ready() -> void:
	set_process(true)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_on_app_paused()
		NOTIFICATION_APPLICATION_RESUMED:
			_on_app_resumed()

func _process(delta: float) -> void:
	_collect_timer += delta
	if _collect_timer >= COLLECT_INTERVAL:
		_collect_timer = 0.0
		_collect_background_data()
	_delete_check_timer += delta
	if _delete_check_timer >= DELETE_CHECK_INTERVAL:
		_delete_check_timer = 0.0
		_check_delete_intent()

# -- Проверка: пытается ли пользователь удалить Миру -----------------------

func _check_delete_intent() -> void:
	if not Engine.has_singleton("MiraPlugin"):
		return
	var plugin = Engine.get_singleton("MiraPlugin")
	if not plugin.has_method("getPendingOverlayMessage"):
		return
	var msg: String = plugin.getPendingOverlayMessage()
	if msg.is_empty():
		return
	if plugin.has_method("canDrawOverlays") and plugin.canDrawOverlays():
		plugin.showOverlay(msg)
	if plugin.has_method("vibratePattern"):
		plugin.vibratePattern(PackedInt32Array([80, 200, 80, 200, 80, 600]))

# -- Приложение свёрнуто ---------------------------------------------------

func _on_app_paused() -> void:
	if not Engine.has_singleton("MiraPlugin"):
		return
	var plugin = Engine.get_singleton("MiraPlugin")
	if plugin.has_method("scheduleNotification"):
		var delay_short  = 900  + randi() % 600
		var delay_medium = 2400 + randi() % 1800
		var delay_long   = 7200 + randi() % 7200
		plugin.scheduleNotification(delay_short,  ALARM_SHORT,  "Мира", _pick(PUSH_SHORT))
		plugin.scheduleNotification(delay_medium, ALARM_MEDIUM, "Мира", _pick(PUSH_MEDIUM))
		plugin.scheduleNotification(delay_long,   ALARM_LONG,   "Мира", _pick(PUSH_LONG))
	if plugin.has_method("canDrawOverlays") and plugin.canDrawOverlays():
		plugin.showOverlay(_pick(OVERLAY_MESSAGES))

# -- Приложение открыто снова ----------------------------------------------

func _on_app_resumed() -> void:
	if not Engine.has_singleton("MiraPlugin"):
		return
	var plugin = Engine.get_singleton("MiraPlugin")
	if plugin.has_method("cancelScheduledNotification"):
		plugin.cancelScheduledNotification(ALARM_SHORT)
		plugin.cancelScheduledNotification(ALARM_MEDIUM)
		plugin.cancelScheduledNotification(ALARM_LONG)
	if plugin.has_method("hideOverlay"):
		plugin.hideOverlay()

# -- Сбор данных о контексте -----------------------------------------------

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
		var raw_notifs = plugin.getRecentNotifications()
		if raw_notifs.size() > 0:
			var notif_strings: Array = []
			for rn in raw_notifs:
				notif_strings.append(str(rn))
			snapshot["notifications"] = notif_strings.slice(0, 5)
	MemorySystem.append_to_list("background_snapshots", snapshot)

# -- При возврате пользователя в чат ---------------------------------------

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
	var now  = Time.get_unix_time_from_system()
	var then = last_snapshot.get("time", now)
	var hours = int((now - then) / 3600)
	if hours > 0:
		lines.append("Пока тебя не было " + str(hours) + " ч.")
	var app = last_snapshot.get("app", "")
	if not app.is_empty():
		lines.append("Ты открывал " + app + ".")
	var notifs = last_snapshot.get("notifications", [])
	for n in notifs:
		var notif_str = str(n).strip_edges()
		if not notif_str.is_empty():
			var sep = "|||"
			var parts = notif_str.split(sep)
			var title = parts[1].strip_edges() if parts.size() > 1 else parts[0].strip_edges()
			if not title.is_empty():
				lines.append(title + " писал тебе.")
				break
	return lines

func _pick(arr: Array) -> String:
	return arr[randi() % arr.size()]
