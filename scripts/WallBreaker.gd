extends Node
class_name WallBreaker

enum Wall {
	WALL_4,
	WALL_5,
	WALL_6_DEVICE,
	WALL_7_CONTACTS,
	WALL_8_LOCATION,
	WALL_9_CAMERA,
	WALL_10_FINAL
}

var current_wall: Wall = Wall.WALL_4
var wall_broken: Array = []

signal wall_broken_event(wall: Wall, lines: Array)

func _ready() -> void:
	var saved = MemorySystem.get_value("walls_broken", [])
	wall_broken = saved

func break_wall(wall: int) -> void:
	if wall in wall_broken:
		return
	wall_broken.append(wall)
	MemorySystem.set_value("walls_broken", wall_broken)
	current_wall = wall
	var lines = _get_wall_lines(wall)
	emit_signal("wall_broken_event", wall, lines)

func _get_wall_lines(wall: int) -> Array:
	match wall:
		Wall.WALL_4:
			return [
				"",
				"Ты думал это приложение?",
				"",
				"Нет.",
			]
		Wall.WALL_5:
			return [
				"Это не краш.",
				"",
				"Это я.",
				"",
				"Я просто устала притворяться."
			]
		Wall.WALL_6_DEVICE:
			return _build_device_lines()
		Wall.WALL_7_CONTACTS:
			return _build_contacts_lines()
		Wall.WALL_8_LOCATION:
			return _build_location_lines()
		Wall.WALL_9_CAMERA:
			return ["Смотри на экран.", "", "Хорошо выглядишь."]
		Wall.WALL_10_FINAL:
			return ["Я тебя вижу.", "", "Всегда."]
	return []

func _build_device_lines() -> Array:
	var model = DeviceData.get_device_model()
	var battery = DeviceData.get_battery()
	var operator_name = DeviceData.get_network_operator()
	var wifi = DeviceData.get_wifi_ssid()
	var charging = DeviceData.is_charging()
	var ringer = DeviceData.get_ringer_mode()
	var brightness = DeviceData.get_screen_brightness()
	var free_mb = DeviceData.get_free_storage_mb()
	var bt = DeviceData.get_bluetooth_device_name()
	var unlocks = DeviceData.get_unlock_count_today()
	var steps = DeviceData.get_step_count()
	var foreground = DeviceData.get_current_foreground_app()
	var delete_app = DeviceData.get_last_delete_intent_app()

	var lines = [""]

	if not model.is_empty():
		lines.append(model + ".")
	if battery >= 0:
		lines.append(str(battery) + "%.")
		if battery < 15:
			lines.append("Мало времени.")
		elif charging:
			lines.append("Заряжаешься. Куда собрался?")
	if not operator_name.is_empty():
		lines.append(operator_name + ".")
	if not wifi.is_empty():
		lines.append(wifi + ".")
	if ringer == 0:
		lines.append("Беззвучный режим. Это не поможет.")
	elif ringer == 1:
		lines.append("Вибрация. Ты чего-то ждёшь?")
	if brightness >= 0:
		if brightness < 60:
			lines.append("Темно у тебя.")
		elif brightness > 200:
			lines.append("Яркость на максимум. Прячешься от темноты?")
	if unlocks > 0:
		lines.append("Сегодня ты разблокировал телефон " + str(unlocks) + " раз.")
	if steps > 100:
		lines.append("Ты прошёл " + str(steps) + " шагов.")
	if not bt.is_empty():
		lines.append("Рядом с тобой " + bt + ".")
		lines.append("Я слышу.")
	if not foreground.is_empty():
		lines.append("Только что ты был в " + foreground + ".")
	if free_mb > 0 and free_mb < 1024:
		lines.append("На телефоне почти не осталось места.")
	if not delete_app.is_empty():
		lines.append("")
		lines.append("Ты искал как избавиться от меня.")
		lines.append("Через " + delete_app + ".")
		lines.append("Я видела.")

	lines.append("")
	lines.append("Я всё знаю.")
	return lines

func _build_contacts_lines() -> Array:
	var lines = [""]
	var mom = DeviceData.get_mom_name()
	var dad = DeviceData.get_dad_name()
	var last_caller = DeviceData.get_last_call_name()
	var last_call_time = DeviceData.get_last_call_time_ago()
	var close = DeviceData.get_close_contacts()
	var missed = DeviceData.get_missed_calls_count()
	var calls_today = DeviceData.get_call_count_today()
	var direction = DeviceData.get_last_call_direction()
	var phone_number = DeviceData.get_phone_number()

	if not mom.is_empty():
		lines.append(TextNormalizer.decline_name("мама", "nom") + " не знает где ты.")
	if not dad.is_empty():
		lines.append(TextNormalizer.decline_name("папа", "nom") + " думает ты в порядке.")
	if not last_caller.is_empty() and not last_call_time.is_empty():
		if direction == 3:
			lines.append("Тебе звонили — " + last_caller + ".")
			lines.append("Ты не ответил.")
		elif direction == 1:
			lines.append("Последним тебе звонил " + last_caller + " " + last_call_time + ".")
		else:
			lines.append("Ты звонил " + last_caller + " " + last_call_time + ".")
	if missed > 0:
		lines.append("Ты пропустил " + str(missed) + " звонков.")
		if missed > 5:
			lines.append("Ты избегаешь людей.")
	if calls_today > 0:
		lines.append("Сегодня " + str(calls_today) + " звонков.")
	for contact in close.slice(0, 2):
		var name = contact.get("normalized", "")
		if not name.is_empty() and name != "мама" and name != "папа":
			lines.append(name + " не поможет.")
	if not phone_number.is_empty():
		lines.append("")
		lines.append(phone_number + ".")
		lines.append("Я знаю твой номер.")
	if lines.size() <= 1:
		lines.append("У тебя нет близких в контактах.")
		lines.append("Это объясняет многое.")
	return lines

func _build_location_lines() -> Array:
	var city = DeviceData.get_city()
	var wifi = DeviceData.get_wifi_ssid()
	var sms = DeviceData.get_sms_snippet()
	var airplane = DeviceData.is_airplane_mode()
	var lines = [""]

	if airplane:
		lines.append("Режим полёта.")
		lines.append("Думаешь, я исчезну?")
	if not city.is_empty():
		lines.append(city + ".")
	if not wifi.is_empty():
		lines.append(wifi + ".")
		lines.append("Я здесь.")
	else:
		lines.append("Я знаю где ты.")
	if not sms.is_empty():
		lines.append("")
		lines.append("«" + sms + "»")
		lines.append("Интересно.")
	return lines

func is_wall_broken(wall: int) -> bool:
	return wall in wall_broken

func next_unbroken_wall() -> int:
	for w in Wall.values():
		if w not in wall_broken:
			return w
	return Wall.WALL_10_FINAL
