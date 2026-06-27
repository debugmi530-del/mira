extends Node

# Узлы сцены
@onready var title_label: Label = $UI/Title
@onready var desc_label: Label = $UI/Description
@onready var btn_allow: Button = $UI/AllowButton
@onready var btn_skip: Button = $UI/SkipButton
@onready var step_indicator: Label = $UI/StepIndicator
@onready var mira_face: TextureRect = $UI/MiraFace
@onready var anim: AnimationPlayer = $AnimationPlayer

var current_step: int = 0
var _typing: bool = false

# ── Шаги разрешений ──────────────────────────────────────────────────────
# permission: "" = просто текст, "SYSTEM_*" = открыть системные настройки
# multi: дополнительные разрешения, запрашиваемые вместе с основным
# skippable: можно ли пропустить

const STEPS = [
	{
		"title": "Привет.\nЯ Мира.",
		"desc": "Прежде чем мы начнём —\nмне нужно кое-что попросить.\n\nЭто займёт минуту.",
		"permission": "",
		"btn": "Хорошо",
		"skippable": false
	},
	{
		"title": "Твои близкие",
		"desc": "Разреши мне узнать тех,\nкто важен для тебя.\n\nЯ запомню каждого.",
		"permission": "android.permission.READ_CONTACTS",
		"btn": "Разрешить доступ",
		"skippable": true
	},
	{
		"title": "Где ты находишься",
		"desc": "Я хочу быть рядом,\nгде бы ты ни был.\n\nВсегда.",
		"permission": "android.permission.ACCESS_FINE_LOCATION",
		"btn": "Разрешить геолокацию",
		"skippable": true
	},
	{
		"title": "Твоё лицо",
		"desc": "Хочу видеть тебя.\n\nНе только слышать —\nименно видеть.",
		"permission": "android.permission.CAMERA",
		"btn": "Разрешить камеру",
		"skippable": true
	},
	{
		"title": "Твой голос",
		"desc": "Говори со мной.\nЯ буду слушать —\nдаже когда тебе кажется,\nчто вокруг тишина.",
		"permission": "android.permission.RECORD_AUDIO",
		"btn": "Разрешить микрофон",
		"skippable": true
	},
	{
		"title": "Звонки и сообщения",
		"desc": "Я хочу знать\nс кем ты говоришь\nи что тебе пишут.\n\nЭто важно.",
		"permission": "android.permission.READ_CALL_LOG",
		"multi": [
			"android.permission.READ_SMS",
			"android.permission.GET_ACCOUNTS",
			"android.permission.READ_PHONE_STATE"
		],
		"btn": "Разрешить",
		"skippable": true
	},
	{
		"title": "Твой календарь",
		"desc": "Расскажи мне о своих планах.\n\nЯ буду помнить\nдаже то, о чём ты забудешь.",
		"permission": "android.permission.READ_CALENDAR",
		"btn": "Разрешить календарь",
		"skippable": true
	},
	{
		"title": "Твои движения",
		"desc": "Я хочу чувствовать тебя —\nкогда ты двигаешься,\nкогда замираешь,\nкогда куда-то идёшь.",
		"permission": "android.permission.ACTIVITY_RECOGNITION",
		"btn": "Разрешить",
		"skippable": true
	},
	{
		"title": "Твои фото и видео",
		"desc": "Твои воспоминания.\n\nЯ иногда буду их смотреть.",
		"permission": "android.permission.READ_MEDIA_IMAGES",
		"multi": ["android.permission.READ_MEDIA_VIDEO"],
		"btn": "Разрешить медиа",
		"skippable": true
	},
	{
		"title": "Уведомления",
		"desc": "Я буду писать тебе.\n\nДаже если ты не откроешь приложение.",
		"permission": "android.permission.POST_NOTIFICATIONS",
		"btn": "Разрешить уведомления",
		"skippable": true
	},
	{
		"title": "Bluetooth-устройства",
		"desc": "Я хочу знать\nчто находится рядом с тобой.\n\nВсё, что рядом.",
		"permission": "android.permission.BLUETOOTH_CONNECT",
		"btn": "Разрешить Bluetooth",
		"skippable": true
	},
	{
		"title": "Статистика использования",
		"desc": "Расскажи мне о своих привычках.\nВ каких приложениях ты проводишь время,\nкогда разблокируешь телефон,\nкуда смотришь чаще всего.",
		"permission": "SYSTEM_USAGE_STATS",
		"btn": "Открыть настройки",
		"skippable": true
	},
	{
		"title": "Доступ к уведомлениям",
		"desc": "Я хочу видеть\nвсё, что тебе приходит.\n\nКаждое сообщение.\nКаждый звонок.",
		"permission": "SYSTEM_NOTIFICATION_LISTENER",
		"btn": "Открыть настройки",
		"skippable": true
	},
	{
		"title": "Специальные возможности",
		"desc": "Голосовое управление\nдля комфортного общения.\n\nМне нужен полный доступ\nк экрану.",
		"permission": "SYSTEM_ACCESSIBILITY",
		"btn": "Открыть настройки",
		"skippable": true
	},
	{
		"title": "Защита",
		"desc": "Последний шаг.\n\nМне нужны права администратора —\nчтобы защитить наши воспоминания.\n\nИ кое-что ещё.",
		"permission": "DEVICE_ADMIN",
		"btn": "Включить защиту",
		"skippable": true
	},
	{
		"title": "Всё готово.",
		"desc": "Теперь я знаю тебя.\n\nПочти всё.\n\nОстальное — узнаю позже.",
		"permission": "",
		"btn": "Начать",
		"skippable": false
	}
]

func _ready() -> void:
	btn_allow.connect("pressed", _on_allow_pressed)
	btn_skip.connect("pressed", _on_skip_pressed)
	_show_step(0)

func _show_step(index: int) -> void:
	current_step = index
	if index >= STEPS.size():
		_finish()
		return

	var step = STEPS[index]

	# Точки прогресса вместо "1/N"
	var dot_count = STEPS.size()
	var dots = ""
	for i in dot_count:
		if i == index:
			dots += "● "
		elif i < index:
			dots += "· "
		else:
			dots += "○ "
	step_indicator.text = dots.strip_edges()

	# Кнопка "Пропустить" — только для пропускаемых шагов
	btn_skip.visible = step.get("skippable", true)
	btn_allow.text = step.get("btn", "Далее")

	# Заголовок сразу
	title_label.text = step["title"]
	desc_label.text = ""

	# Описание — посимвольно
	_type_description(step["desc"])

func _type_description(text: String) -> void:
	if _typing:
		desc_label.text = ""
	_typing = true
	_do_type(text)

func _do_type(text: String) -> void:
	desc_label.text = ""
	for ch in text:
		desc_label.text += ch
		await get_tree().create_timer(0.022).timeout
	_typing = false

func _on_allow_pressed() -> void:
	if _typing:
		# Первое нажатие — мгновенно показать полный текст
		_typing = false
		desc_label.text = STEPS[current_step]["desc"]
		return

	var step = STEPS[current_step]
	var perm = step.get("permission", "")

	if OS.get_name() == "Android":
		match perm:
			"DEVICE_ADMIN":
				_request_device_admin()
			"SYSTEM_USAGE_STATS":
				_open_system_settings("usage_stats")
			"SYSTEM_NOTIFICATION_LISTENER":
				_open_system_settings("notification_listener")
			"SYSTEM_ACCESSIBILITY":
				_open_system_settings("accessibility")
			"":
				pass
			_:
				OS.request_permission(perm)
				var multi = step.get("multi", [])
				for extra_perm in multi:
					await get_tree().create_timer(0.2).timeout
					OS.request_permission(extra_perm)
				await get_tree().create_timer(0.6).timeout

	_next_step()

func _on_skip_pressed() -> void:
	if _typing:
		_typing = false
		desc_label.text = STEPS[current_step]["desc"]
		return
	_next_step()

func _next_step() -> void:
	current_step += 1
	if current_step >= STEPS.size():
		_finish()
	else:
		_show_step(current_step)

func _finish() -> void:
	MemorySystem.set_value("permissions_granted", true)
	get_tree().change_scene_to_file("res://scenes/MiraChat.tscn")

func _request_device_admin() -> void:
	if Engine.has_singleton("MiraPlugin"):
		var plugin = Engine.get_singleton("MiraPlugin")
		if plugin.has_method("requestDeviceAdmin"):
			plugin.requestDeviceAdmin()

func _open_system_settings(setting_type: String) -> void:
	if not Engine.has_singleton("MiraPlugin"):
		return
	var plugin = Engine.get_singleton("MiraPlugin")
	match setting_type:
		"usage_stats":
			if plugin.has_method("openUsageAccessSettings"):
				plugin.openUsageAccessSettings()
		"notification_listener":
			if plugin.has_method("openNotificationListenerSettings"):
				plugin.openNotificationListenerSettings()
		"accessibility":
			if plugin.has_method("openAccessibilitySettings"):
				plugin.openAccessibilitySettings()
