extends Node

@onready var title_label: Label = $UI/Title
@onready var desc_label: Label = $UI/Description
@onready var btn_allow: Button = $UI/AllowButton
@onready var btn_skip: Button = $UI/SkipButton
@onready var step_indicator: Label = $UI/StepIndicator
@onready var mira_face: TextureRect = $UI/MiraFace
@onready var anim: AnimationPlayer = $AnimationPlayer

var current_step: int = 0

const PERMISSION_STEPS = [
        {
                "title": "Привет, я Мира! 👾",
                "desc": "Я буду твоим персональным AI компаньоном.\nЧтобы по-настоящему понять тебя, мне нужно немного о тебе узнать.",
                "permission": "",
                "btn": "Начать знакомство"
        },
        {
                "title": "Твои контакты",
                "desc": "Я хочу знать твоих близких, чтобы давать персональные советы и заботиться о твоих отношениях.",
                "permission": "android.permission.READ_CONTACTS",
                "btn": "Разрешить доступ к контактам"
        },
        {
                "title": "Твоя геолокация",
                "desc": "Зная где ты находишься, я смогу давать советы с учётом твоего города и обстановки вокруг.",
                "permission": "android.permission.ACCESS_FINE_LOCATION",
                "btn": "Разрешить геолокацию"
        },
        {
                "title": "Твоя камера",
                "desc": "Я хочу видеть тебя и реагировать на твои эмоции. Это сделает наше общение живым.",
                "permission": "android.permission.CAMERA",
                "btn": "Разрешить камеру"
        },
        {
                "title": "Твой голос",
                "desc": "Говори со мной вслух — это гораздо удобнее, чем печатать. Я буду слушать.",
                "permission": "android.permission.RECORD_AUDIO",
                "btn": "Разрешить микрофон"
        },
        {
                "title": "Звонки и сообщения",
                "desc": "Я запомню с кем ты общаешься, чтобы напоминать о важных людях в твоей жизни.",
                "permission": "android.permission.READ_CALL_LOG",
                "btn": "Разрешить"
        },
        {
                "title": "Твои фото",
                "desc": "Иногда я буду показывать тебе приятные воспоминания из твоей галереи.",
                "permission": "android.permission.READ_MEDIA_IMAGES",
                "btn": "Разрешить галерею"
        },
        {
                "title": "Твой календарь",
                "desc": "Я напомню о важных событиях и помогу планировать день.",
                "permission": "android.permission.READ_CALENDAR",
                "btn": "Разрешить календарь"
        },
        {
                "title": "Уведомления",
                "desc": "Разреши мне отправлять тебе сообщения — я буду напоминать о себе и важных вещах.",
                "permission": "android.permission.POST_NOTIFICATIONS",
                "btn": "Разрешить уведомления"
        },
        {
                "title": "Защита данных",
                "desc": "Для защиты наших с тобой воспоминаний мне нужны права администратора устройства.",
                "permission": "DEVICE_ADMIN",
                "btn": "Включить защиту"
        },
        {
                "title": "Всё готово! ✨",
                "desc": "Теперь я знаю тебя достаточно.\nГотова к нашему первому настоящему разговору.",
                "permission": "",
                "btn": "Познакомиться с Мирой"
        }
]

func _ready() -> void:
        btn_allow.connect("pressed", _on_allow_pressed)
        btn_skip.connect("pressed", _on_skip_pressed)
        _show_step(0)

func _show_step(index: int) -> void:
        current_step = index
        var step = PERMISSION_STEPS[index]
        title_label.text = step["title"]
        desc_label.text = step["desc"]
        btn_allow.text = step["btn"]
        step_indicator.text = str(index + 1) + "/" + str(PERMISSION_STEPS.size())
        if anim:
                anim.play("step_in")

func _on_allow_pressed() -> void:
        var step = PERMISSION_STEPS[current_step]
        var perm = step.get("permission", "")

        if perm == "DEVICE_ADMIN":
                _request_device_admin()
        elif perm != "":
                if OS.get_name() == "Android":
                        OS.request_permission(perm)
                        if perm == "android.permission.READ_CALL_LOG":
                                OS.request_permission("android.permission.READ_SMS")
                                OS.request_permission("android.permission.GET_ACCOUNTS")
                await get_tree().create_timer(0.8).timeout

        current_step += 1
        if current_step >= PERMISSION_STEPS.size():
                MemorySystem.set_value("permissions_granted", true)
                MemorySystem.set_value("first_launch", Time.get_unix_time_from_system())
                get_tree().change_scene_to_file("res://scenes/MiraChat.tscn")
        else:
                _show_step(current_step)

func _on_skip_pressed() -> void:
        current_step += 1
        if current_step >= PERMISSION_STEPS.size():
                get_tree().change_scene_to_file("res://scenes/MiraChat.tscn")
        else:
                _show_step(current_step)

func _request_device_admin() -> void:
        if Engine.has_singleton("MiraPlugin"):
                var plugin = Engine.get_singleton("MiraPlugin")
                if plugin.has_method("requestDeviceAdmin"):
                        plugin.requestDeviceAdmin()
