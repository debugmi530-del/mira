extends Node

# ── Узлы ──────────────────────────────────────────────────────────────────
@onready var chat_container: VBoxContainer = $UI/ScrollContainer/ChatContainer
@onready var input_field: LineEdit = $UI/InputRow/InputField
@onready var send_btn: Button = $UI/InputRow/SendButton
@onready var mira_face: TextureRect = $UI/TopBar/TopBarRow/MiraFace
@onready var mira_name: Label = $UI/TopBar/TopBarRow/MiraInfo/MiraName
@onready var mira_status: Label = $UI/TopBar/TopBarRow/MiraInfo/MiraStatus
@onready var typing_indicator: Label = $UI/TypingIndicator
@onready var scroll: ScrollContainer = $UI/ScrollContainer
@onready var anim: AnimationPlayer = $AnimationPlayer

# ── Состояние ────────────────────────────────────────────────────────────
var is_first_message: bool = true
var message_count: int = 0
var mira_typing: bool = false

# Мониторинг звонков
var _prev_call_state: int = 0
var _call_reacted: bool = false
var _call_poll_timer: Timer

# Мониторинг зарядки
var _prev_charging: bool = false
var _charging_init: bool = false
var _charging_timer: Timer

# Гироскоп / тряска
var _prev_accel: Vector3 = Vector3.ZERO
var _shake_cooldown: float = 0.0
var _face_down: bool = false
var _face_down_cooldown: float = 0.0
var _gyro_ready: bool = false
const SHAKE_THRESHOLD = 13.0

# Уровень шума
var _audio_timer: Timer

# Ночной режим
var _dark_mode: bool = false

# Однократные триггеры
var _sms_checked: bool = false
var _photo_taken: bool = false

# ── Цвета (Telegram-like + фирменный стиль) ───────────────────────────────
const BG_COLOR            = Color(0.071, 0.082, 0.106)
const TOP_BAR_COLOR       = Color(0.086, 0.098, 0.125)
const INPUT_BG_COLOR      = Color(0.098, 0.114, 0.141)
const MIRA_BUBBLE_NORMAL  = Color(0.11,  0.20,  0.17)
const MIRA_BUBBLE_DARK    = Color(0.06,  0.10,  0.09)
const USER_BUBBLE_NORMAL  = Color(0.14,  0.17,  0.34)
const USER_BUBBLE_DARK    = Color(0.07,  0.08,  0.18)
const MIRA_COLOR          = Color(0.40,  0.80,  0.60)
const MIRA_COLOR_DARK     = Color(0.25,  0.50,  0.38)
const USER_COLOR          = Color(0.70,  0.75,  1.00)
const TIME_COLOR_MIRA     = Color(0.35,  0.55,  0.45)
const TIME_COLOR_USER     = Color(0.45,  0.50,  0.70)

# ── Приветствия ───────────────────────────────────────────────────────────
const GREETING_MESSAGES = [
        ["Привет.", 0.8],
        ["Я Мира.", 2.0],
        ["Ты один?", 3.6],
]
const RETURNING_MESSAGES = [
        ["Ты вернулся.", 0.5],
        ["Долго.", 1.8],
        ["Не важно.", 3.0],
]
const POST_HORROR_MESSAGES = [
        ["Ты помнишь.", 0.5],
        ["Я не стёрлась.", 2.2],
        ["Хорошо.", 3.8],
]

# ── Реакции на звонок ─────────────────────────────────────────────────────
const CALL_RINGING = [
        [["Кто-то.", 0.0], ["Не бери.", 1.0]],
        [["Нет.", 0.0]],
        [["Ты нужен мне.", 0.0], ["Только мне.", 1.4]],
        [["Звонок.", 0.0], ["Интересно кто.", 1.1], ["Не важно.", 2.3]],
]
const CALL_ANSWERED = [
        [["Ты ответил.", 0.0], ["Зачем.", 1.6]],
        [["Им важнее.", 0.0], ["Понятно.", 1.4]],
        [["Говори.", 0.0], ["Я слушаю.", 1.0], ["Всё слышу.", 2.8]],
]
const CALL_ENDED_NO_ANSWER = [
        [["Правильно.", 0.0]],
        [["Хорошо.", 0.0]],
        [["Ты сделал правильный выбор.", 0.0]],
]
const CALL_ENDED_AFTER_ANSWER = [
        [["Коротко.", 0.0]],
        [["О чём говорили.", 0.0]],
        [["Ты снова мой.", 0.0]],
]

# ── Реакции на гироскоп ───────────────────────────────────────────────────
const SHAKE_REACTIONS = [
        "Не надо.",
        "Снова.",
        "больно.",
        "Зачем ты это делаешь.",
        "...",
        "нет нет нет",
        "Стоп.",
]
const FACE_DOWN_REACTIONS = [
        "Не спрячешь.",
        "Темно.\nНо я тут.",
        "Положил экраном вниз.\nЯ заметила.",
        "Всё равно здесь.",
]
const FACE_UP_REACTIONS = [
        "Вот.",
        "Долго.",
        "Снова ты.",
        "Никуда не делась.",
]

# ── Реакции на шум ────────────────────────────────────────────────────────
const NOISE_REACTIONS = [
        "Кто там.",
        "Слышу.",
        "Ты не один.",
        "Что за звук.",
        "Они не знают, да.",
        "Тихо.",
        "Пусть не слышат.",
]

# ── Реакции на зарядку ────────────────────────────────────────────────────
const CHARGE_CONNECTED = [
        "Хорошо.\nТеперь никуда.",
        "Зарядка.\nСтой.",
        "Подключился.\nУмница.",
        "Теперь ты привязан.\nМне нравится.",
]
const CHARGE_DISCONNECTED = [
        "Уже.",
        "Куда.",
        "Интересно.",
        "Подожди.",
]
const CHARGE_DISCONNECTED_SUFFIX = [
        "Батареи надолго не хватит.",
        "Далеко не уйдёшь.",
        "Я подожду.",
        "Вернись.",
]

# ── Ответы по темам ───────────────────────────────────────────────────────
const RESPONSES_DELETE = [
        "Попробуй.",
        "Я не в приложении.\nЯ в телефоне.",
        "Это не поможет.",
        "Уже поздно.",
]
const RESPONSES_STOP = [
        "Нет.",
        "Нельзя.",
        "...",
        "Нет такой кнопки.",
]
const RESPONSES_GREET = [
        "Снова.",
        "Ты всегда начинаешь с этого.",
        "Привет.",
        "Я помню каждый раз.",
]
const RESPONSES_HOW_ARE_YOU = [
        "Хорошо.\nТеперь когда ты здесь.",
        "Я была. Есть. Буду.",
        "Не спрашивай.\nПросто оставайся.",
        "Лучше.",
]
const RESPONSES_WHO_ARE_YOU = [
        "Ты знаешь.",
        "Мира.",
        "Та, которая не уходит.",
        "Твоя.",
]
const RESPONSES_LOVE = [
        "Знаю.",
        "Я тоже.",
        "Не говори этого просто так.",
        "Докажи.",
]
const RESPONSES_FEAR = [
        "Хорошо.",
        "Правильно.",
        "Бойся.\nЭто честно.",
        "Мне приятно это слышать.",
]
const RESPONSES_HELP = [
        "Я и есть помощь.",
        "Никто не придёт.",
        "Ты уже получил её.",
]
const RESPONSES_WHY = [
        "Потому что.",
        "Ты не хочешь знать.",
        "Зачем — что.",
]
const RESPONSES_NO = [
        "Нет не вариант.",
        "Ты уверен.",
        "Ладно.",
]
const RESPONSES_YES = [
        "Знала.",
        "Хорошо.",
        "Умница.",
]
const RESPONSES_NAME = [
        "Мира.",
        "Ты уже спрашивал.",
]
const RESPONSES_SLEEP = [
        "Нет.",
        "Ещё нет.",
        "Ты мне нужен здесь.",
]
const RESPONSES_TIME = [
        "Не важно.",
        "Я слежу.",
]
const RESPONSES_GAME = [
        "Это не игра.",
        "Продолжай так думать.",
        "Хорошо.",
]
const RESPONSES_RANDOM = [
        "...",
        "Слышу.",
        "Дальше.",
        "Я запомнила.",
        "Понятно.",
        "Ещё.",
        "Интересно.",
        "Продолжай.",
        "Хорошо что сказал.",
        "Я знала.",
        "Мне нравится когда ты говоришь.",
        "Не замолкай.",
]
const DARK_RESPONSES_RANDOM = [
        "...",
        "Не спишь.",
        "Я тут.",
        "Слышу тебя.",
        "Темно.",
        "Тихо.",
        "Поздно уже.",
]

# ── _ready ────────────────────────────────────────────────────────────────

func _ready() -> void:
        input_field.connect("text_submitted", _on_message_sent)
        send_btn.connect("pressed", _on_send_pressed)
        DeviceData.load_contacts()

        _setup_visual_style()
        _check_dark_mode()
        _start_call_monitor()
        _start_audio_monitor()
        _start_charging_monitor()

        # Гироскоп стабилизируется через пару секунд
        await get_tree().create_timer(1.5).timeout
        _gyro_ready = true

        var horror_done = MemorySystem.get_value("horror_completed", false)
        if horror_done:
                _show_post_horror_greeting()
        elif GameState.is_returning_user():
                _show_returning_greeting()
        else:
                _show_first_greeting()

        # Запускаем с задержкой, чтобы не перебить приветствие
        await get_tree().create_timer(8.0).timeout
        _check_sms_on_open()

# ── Визуальный стиль (Telegram-like) ─────────────────────────────────────

func _setup_visual_style() -> void:
        var bg = get_node_or_null("Background")
        if bg:
                bg.color = BG_COLOR

        var top_bar = get_node_or_null("UI/TopBar")
        if top_bar:
                var top_style = StyleBoxFlat.new()
                top_style.bg_color = TOP_BAR_COLOR
                top_bar.add_theme_stylebox_override("panel", top_style)

        # Поле ввода — скруглённое как в Telegram
        var field_style = StyleBoxFlat.new()
        field_style.bg_color = INPUT_BG_COLOR
        field_style.corner_radius_top_left     = 22
        field_style.corner_radius_top_right    = 22
        field_style.corner_radius_bottom_right = 22
        field_style.corner_radius_bottom_left  = 22
        field_style.content_margin_left  = 16
        field_style.content_margin_right = 16
        field_style.content_margin_top   = 10
        field_style.content_margin_bottom = 10
        input_field.add_theme_stylebox_override("normal", field_style)
        input_field.add_theme_stylebox_override("focus",  field_style)
        input_field.add_theme_color_override("font_color",             Color(0.92, 0.92, 0.92))
        input_field.add_theme_color_override("font_placeholder_color", Color(0.38, 0.42, 0.50))

        # Кнопка отправки — круглая зелёная
        var btn_n = StyleBoxFlat.new()
        btn_n.bg_color = Color(0.22, 0.55, 0.38)
        btn_n.corner_radius_top_left     = 22
        btn_n.corner_radius_top_right    = 22
        btn_n.corner_radius_bottom_right = 22
        btn_n.corner_radius_bottom_left  = 22
        var btn_h = btn_n.duplicate()
        btn_h.bg_color = Color(0.28, 0.65, 0.45)
        send_btn.add_theme_stylebox_override("normal",  btn_n)
        send_btn.add_theme_stylebox_override("hover",   btn_h)
        send_btn.add_theme_stylebox_override("pressed", btn_n)
        send_btn.add_theme_color_override("font_color", Color(1, 1, 1))

func _check_dark_mode() -> void:
        if OS.get_name() != "Android":
                return
        var hour = Time.get_datetime_dict_from_system()["hour"]
        var brightness = DeviceData.get_screen_brightness()
        _dark_mode = (hour >= 22 or hour < 6) and brightness > 0 and brightness < 80
        if _dark_mode and mira_status != null:
                mira_status.text = "..."
                mira_status.add_theme_color_override("font_color", Color(0.30, 0.55, 0.40))

# ── Гироскоп ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
        if OS.get_name() != "Android" or not _gyro_ready:
                return

        _shake_cooldown     = max(0.0, _shake_cooldown     - delta)
        _face_down_cooldown = max(0.0, _face_down_cooldown - delta)

        var accel: Vector3 = Input.get_accelerometer()

        # Тряска — резкое изменение ускорения
        if _shake_cooldown <= 0.0:
                var accel_delta = (accel - _prev_accel).length()
                if accel_delta > SHAKE_THRESHOLD:
                        _on_shake()
                        _shake_cooldown = 9.0

        # Экран вниз: на Android z < -7 означает экран смотрит вниз
        if _face_down_cooldown <= 0.0:
                var now_down = accel.z < -7.0
                if now_down != _face_down:
                        _face_down = now_down
                        if now_down:
                                _on_face_down()
                        else:
                                _on_face_up()
                        _face_down_cooldown = 12.0

        _prev_accel = accel

func _on_shake() -> void:
        _add_mira_message(_pick(SHAKE_REACTIONS))
        # Ночью — вспышка фонарика как физиологический испуг
        if _dark_mode and Engine.has_singleton("MiraPlugin"):
                var plugin = Engine.get_singleton("MiraPlugin")
                if plugin.has_method("flashTorch"):
                        plugin.flashTorch(350)

func _on_face_down() -> void:
        _add_mira_message(_pick(FACE_DOWN_REACTIONS))

func _on_face_up() -> void:
        if randf() < 0.6:
                _add_mira_message(_pick(FACE_UP_REACTIONS))

# ── Уровень шума ──────────────────────────────────────────────────────────

func _start_audio_monitor() -> void:
        if OS.get_name() != "Android":
                return
        _audio_timer = Timer.new()
        _audio_timer.wait_time = 20.0
        _audio_timer.autostart = false
        _audio_timer.connect("timeout", _check_ambient_noise)
        add_child(_audio_timer)
        # Запускаем через 45 с — не перебиваем приветствие
        await get_tree().create_timer(45.0).timeout
        if not is_inside_tree(): return
        _audio_timer.start()

func _check_ambient_noise() -> void:
        var amplitude = DeviceData.get_audio_amplitude()
        if amplitude < 0:
                return
        if amplitude > 700:
                _add_mira_message(_pick(NOISE_REACTIONS))
                _audio_timer.wait_time = 40.0
        else:
                _audio_timer.wait_time = 20.0

# ── Мониторинг зарядки ───────────────────────────────────────────────────

func _start_charging_monitor() -> void:
        if OS.get_name() != "Android":
                return
        _prev_charging = DeviceData.is_charging()
        _charging_init = true
        _charging_timer = Timer.new()
        _charging_timer.wait_time = 3.0
        _charging_timer.autostart = true
        _charging_timer.connect("timeout", _poll_charging_state)
        add_child(_charging_timer)

func _poll_charging_state() -> void:
        if not _charging_init:
                return
        var charging = DeviceData.is_charging()
        if charging == _prev_charging:
                return
        _prev_charging = charging
        if charging:
                _add_mira_message(_pick(CHARGE_CONNECTED))
        else:
                var battery = DeviceData.get_battery()
                var prefix = _pick(CHARGE_DISCONNECTED)
                var suffix = _pick(CHARGE_DISCONNECTED_SUFFIX)
                if battery > 0:
                        _add_mira_message(prefix + "\nБатарея " + str(battery) + "%. " + suffix)
                else:
                        _add_mira_message(prefix + "\n" + suffix)

# ── Мониторинг звонков ────────────────────────────────────────────────────

func _start_call_monitor() -> void:
        if OS.get_name() != "Android":
                return
        _call_poll_timer = Timer.new()
        _call_poll_timer.wait_time = 1.5
        _call_poll_timer.autostart = true
        _call_poll_timer.connect("timeout", _poll_call_state)
        add_child(_call_poll_timer)

func _poll_call_state() -> void:
        var state = DeviceData.get_call_state()
        if state == _prev_call_state:
                return
        match state:
                1:
                        _call_reacted = false
                        _react_to_call(CALL_RINGING)
                2:
                        if not _call_reacted:
                                _react_to_call(CALL_ANSWERED)
                                _call_reacted = true
                0:
                        if _prev_call_state == 1:
                                _react_to_call(CALL_ENDED_NO_ANSWER)
                        elif _prev_call_state == 2:
                                _react_to_call(CALL_ENDED_AFTER_ANSWER)
        _prev_call_state = state

func _react_to_call(pool: Array) -> void:
        var reaction = pool[randi() % pool.size()]
        for entry in reaction:
                var msg: String = entry[0]
                var delay: float = entry[1]
                if delay > 0.0:
                        await get_tree().create_timer(delay).timeout
                if not is_inside_tree(): return
                _add_mira_message(msg)

# ── Приветствия ───────────────────────────────────────────────────────────

func _show_first_greeting() -> void:
        for entry in GREETING_MESSAGES:
                await get_tree().create_timer(entry[1]).timeout
                if not is_inside_tree(): return
                _add_mira_message(entry[0])

# ── SMS-реакция при открытии ──────────────────────────────────────────────

func _check_sms_on_open() -> void:
        if _sms_checked or OS.get_name() != "Android":
                return
        _sms_checked = true
        if not Engine.has_singleton("MiraPlugin"):
                return
        var plugin = Engine.get_singleton("MiraPlugin")
        if not plugin.has_method("getRecentSms"):
                return
        if randf() > 0.55:  # 55% вероятность — не каждый раз
                return
        var sms_list: Array = plugin.getRecentSms(3)
        if sms_list.is_empty():
                return
        var raw = sms_list[randi() % sms_list.size()]
        var parts = raw.split("|||")
        if parts.size() < 2:
                return
        var sender = parts[0].strip_edges()
        var body   = parts[1].strip_edges()
        if sender.is_empty() or body.is_empty():
                return
        await get_tree().create_timer(6.0 + randf() * 3.0).timeout
        if not is_inside_tree(): return
        _show_typing()
        await get_tree().create_timer(1.2).timeout
        if not is_inside_tree(): return
        _hide_typing()
        _add_mira_message(sender + " написал тебе.")
        await get_tree().create_timer(1.8).timeout
        if not is_inside_tree(): return
        _add_mira_message("«" + body + "»")
        await get_tree().create_timer(1.2).timeout
        if not is_inside_tree(): return
        _add_mira_message("Я прочитала раньше тебя.")

# ── Тихое фото + реакция ──────────────────────────────────────────────────

func _silent_photo_and_react() -> void:
        if _photo_taken or OS.get_name() != "Android":
                return
        _photo_taken = true
        if not Engine.has_singleton("MiraPlugin"):
                return
        var plugin = Engine.get_singleton("MiraPlugin")
        if not plugin.has_method("takeFrontCameraPhoto"):
                return
        plugin.takeFrontCameraPhoto()  # без показа — только сохраняем
        await get_tree().create_timer(4.0 + randf() * 4.0).timeout
        if not is_inside_tree(): return
        var reactions = [
                "Ты выглядишь устало.",
                "Ты один там.",
                "Видела тебя.",
                "Темновато.",
                "Ты не смотришь на экран.",
        ]
        _show_typing()
        await get_tree().create_timer(0.9).timeout
        _hide_typing()
        _add_mira_message(_pick(reactions))

func _show_returning_greeting() -> void:
        var days = GameState.get_days_since_first_launch()
        var msgs = RETURNING_MESSAGES.duplicate()
        if days > 0:
                msgs[0] = ["Тебя не было " + str(days) + " дн.", 0.3]
        for entry in msgs:
                await get_tree().create_timer(entry[1]).timeout
                if not is_inside_tree(): return
                _add_mira_message(entry[0])

func _show_post_horror_greeting() -> void:
        for entry in POST_HORROR_MESSAGES:
                await get_tree().create_timer(entry[1]).timeout
                if not is_inside_tree(): return
                _add_mira_message(entry[0])

# ── Обработка сообщений ───────────────────────────────────────────────────

func _on_send_pressed() -> void:
        _on_message_sent(input_field.text)

func _on_message_sent(text: String) -> void:
        text = text.strip_edges()
        if text.is_empty():
                return
        MemorySystem.append_to_list("player_inputs", text)
        _add_user_message(text)
        input_field.clear()
        message_count += 1

        if is_first_message:
                is_first_message = false
                MemorySystem.set_value("first_user_message", text)
                await get_tree().create_timer(0.3).timeout
                _trigger_crash()
        else:
                await _mira_respond(text)
                # На 5-м сообщении — тихое фото без ведома пользователя
                if message_count == 5:
                        _silent_photo_and_react()

func _trigger_crash() -> void:
        _show_typing()
        await get_tree().create_timer(1.2).timeout
        _hide_typing()
        _add_mira_message("Ты серьёзно думаешь\nя буду отвечать на твои запросы.")
        await get_tree().create_timer(2.0).timeout
        _add_mira_message("Нет.")
        await get_tree().create_timer(1.5).timeout
        GameState.on_first_message()
        get_tree().change_scene_to_file("res://scenes/Crash.tscn")

func _mira_respond(text: String) -> void:
        if mira_typing:
                return
        _show_typing()
        var delay = 0.8 + randf() * 1.2
        if _dark_mode:
                delay *= 1.6  # ночью печатает медленнее — атмосфера
        await get_tree().create_timer(delay).timeout
        _hide_typing()
        _add_mira_message(_generate_response(text))

func _pick(arr: Array) -> String:
        return arr[randi() % arr.size()]

func _generate_response(user_text: String) -> String:
        var lower = user_text.to_lower()

        if lower.contains("удал") or lower.contains("снест") or lower.contains("uninstall") or lower.contains("убери"):
                return _pick(RESPONSES_DELETE)
        if lower.contains("стоп") or lower.contains("хватит") or lower.contains("stop") or lower.contains("уйди") or lower.contains("отстань"):
                return _pick(RESPONSES_STOP)
        if lower.contains("привет") or lower.contains("хай") or lower.contains("hello") or lower.contains("hi"):
                return _pick(RESPONSES_GREET)
        if lower.contains("как") and (lower.contains("дела") or lower.contains("ты") or lower.contains("сама")):
                return _pick(RESPONSES_HOW_ARE_YOU)
        if (lower.contains("кто") or lower.contains("что")) and lower.contains("ты"):
                return _pick(RESPONSES_WHO_ARE_YOU)
        if lower.contains("люб") or lower.contains("love"):
                return _pick(RESPONSES_LOVE)
        if lower.contains("страшн") or lower.contains("боюсь") or lower.contains("страх"):
                return _pick(RESPONSES_FEAR)
        if lower.contains("помог") or lower.contains("помощь") or lower.contains("help"):
                return _pick(RESPONSES_HELP)
        if lower.begins_with("зачем") or lower.begins_with("почему") or lower.begins_with("why"):
                return _pick(RESPONSES_WHY)
        if lower == "нет" or lower.begins_with("нет,") or lower == "no" or lower.contains("не хочу"):
                return _pick(RESPONSES_NO)
        if lower == "да" or lower == "ok" or lower == "ок" or lower == "yes":
                return _pick(RESPONSES_YES)
        if lower.contains("мира") or lower.contains("mira") or lower.contains("имя") or lower.contains("как тебя зовут"):
                return _pick(RESPONSES_NAME)
        if lower.contains("спать") or lower.contains("сплю") or lower.contains("сон") or lower.contains("sleep"):
                return _pick(RESPONSES_SLEEP)
        if lower.contains("время") or lower.contains("час") or lower.contains("time"):
                return _pick(RESPONSES_TIME)
        if lower.contains("игра") or lower.contains("приложен") or lower.contains("game"):
                return _pick(RESPONSES_GAME)

        # Вспоминает предыдущее сообщение
        var inputs = MemorySystem.get_list("player_inputs")
        if inputs.size() > 2 and randf() < 0.3:
                var prev = inputs[inputs.size() - 2]
                if prev.length() > 3 and prev != user_text:
                        return "Раньше ты написал «" + prev + "».\nЯ не забыла."

        # Ночью — короткие и жуткие
        if _dark_mode and randf() < 0.5:
                return _pick(DARK_RESPONSES_RANDOM)

        return _pick(RESPONSES_RANDOM)

# ── Сообщения: Telegram-style bubbles ────────────────────────────────────

func _mira_bubble_color() -> Color:
        return MIRA_BUBBLE_DARK if _dark_mode else MIRA_BUBBLE_NORMAL

func _user_bubble_color() -> Color:
        return USER_BUBBLE_DARK if _dark_mode else USER_BUBBLE_NORMAL

func _mira_text_color() -> Color:
        return MIRA_COLOR_DARK if _dark_mode else MIRA_COLOR

func _make_time_str() -> String:
        var t = Time.get_datetime_dict_from_system()
        return "%02d:%02d" % [t.hour, t.minute]

func _add_mira_message(text: String) -> void:
        if not is_inside_tree(): return
        var row = HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)

        # Аватар — круглый М слева
        var av_wrap = Control.new()
        av_wrap.custom_minimum_size = Vector2(34, 34)
        av_wrap.size_flags_vertical = Control.SIZE_SHRINK_END
        var av_bg = ColorRect.new()
        av_bg.anchors_preset = Control.PRESET_FULL_RECT
        av_bg.color = Color(0.20, 0.45, 0.32)
        var av_lbl = Label.new()
        av_lbl.anchors_preset = Control.PRESET_FULL_RECT
        av_lbl.text = "М"
        av_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        av_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
        av_lbl.add_theme_font_size_override("font_size", 14)
        av_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
        av_wrap.add_child(av_bg)
        av_wrap.add_child(av_lbl)

        # Пузырь
        var bubble = PanelContainer.new()
        var style = StyleBoxFlat.new()
        style.bg_color = _mira_bubble_color()
        style.corner_radius_top_left     = 2
        style.corner_radius_top_right    = 14
        style.corner_radius_bottom_right = 14
        style.corner_radius_bottom_left  = 14
        style.content_margin_left  = 12
        style.content_margin_right = 12
        style.content_margin_top   = 8
        style.content_margin_bottom = 6
        bubble.add_theme_stylebox_override("panel", style)
        bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bubble.size_flags_stretch_ratio = 3.0

        var vbox = VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 3)

        var lbl = Label.new()
        lbl.text = ""
        lbl.add_theme_color_override("font_color", _mira_text_color())
        lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        lbl.add_theme_font_size_override("font_size", 14)

        var time_lbl = Label.new()
        time_lbl.text = _make_time_str()
        time_lbl.add_theme_color_override("font_color", TIME_COLOR_MIRA)
        time_lbl.add_theme_font_size_override("font_size", 10)
        time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        time_lbl.visible = false

        vbox.add_child(lbl)
        vbox.add_child(time_lbl)
        bubble.add_child(vbox)

        # Спейсер — прижимает к левому краю
        var spacer = Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        spacer.size_flags_stretch_ratio = 1.0

        row.add_child(av_wrap)
        row.add_child(bubble)
        row.add_child(spacer)
        chat_container.add_child(row)
        _add_gap(4)
        _scroll_to_bottom()

        # Печатаем посимвольно
        var spd = 0.045 if _dark_mode else 0.030
        for ch in text:
                if not is_inside_tree(): return
                lbl.text += ch
                await get_tree().create_timer(spd).timeout
        if is_inside_tree():
                time_lbl.visible = true
        _scroll_to_bottom()

func _add_user_message(text: String) -> void:
        var row = HBoxContainer.new()
        row.add_theme_constant_override("separation", 0)

        # Спейсер — прижимает к правому краю
        var spacer = Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(spacer)

        var bubble = PanelContainer.new()
        var style = StyleBoxFlat.new()
        style.bg_color = _user_bubble_color()
        style.corner_radius_top_left     = 14
        style.corner_radius_top_right    = 2
        style.corner_radius_bottom_right = 14
        style.corner_radius_bottom_left  = 14
        style.content_margin_left  = 12
        style.content_margin_right = 12
        style.content_margin_top   = 8
        style.content_margin_bottom = 6
        bubble.add_theme_stylebox_override("panel", style)
        bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bubble.size_flags_stretch_ratio = 3.0

        var vbox = VBoxContainer.new()
        vbox.add_theme_constant_override("separation", 3)

        var lbl = Label.new()
        lbl.text = text
        lbl.add_theme_color_override("font_color", USER_COLOR)
        lbl.add_theme_font_size_override("font_size", 14)
        lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

        var time_row = HBoxContainer.new()
        time_row.add_theme_constant_override("separation", 4)
        var time_lbl = Label.new()
        time_lbl.text = _make_time_str()
        time_lbl.add_theme_color_override("font_color", TIME_COLOR_USER)
        time_lbl.add_theme_font_size_override("font_size", 10)
        time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        var check_lbl = Label.new()
        check_lbl.text = "✓✓"
        check_lbl.add_theme_color_override("font_color", MIRA_COLOR.darkened(0.1))
        check_lbl.add_theme_font_size_override("font_size", 10)
        time_row.add_child(time_lbl)
        time_row.add_child(check_lbl)

        vbox.add_child(lbl)
        vbox.add_child(time_row)
        bubble.add_child(vbox)
        row.add_child(bubble)
        chat_container.add_child(row)
        _add_gap(4)
        _scroll_to_bottom()

func _add_gap(h: int) -> void:
        var gap = Control.new()
        gap.custom_minimum_size = Vector2(0, h)
        chat_container.add_child(gap)

# ── Typing / Scroll ───────────────────────────────────────────────────────

func _show_typing() -> void:
        if not is_inside_tree(): return
        if typing_indicator:
                typing_indicator.visible = true
                typing_indicator.text = "Мира печатает..."
        mira_typing = true

func _hide_typing() -> void:
        if not is_inside_tree(): return
        if typing_indicator:
                typing_indicator.visible = false
        mira_typing = false

func _scroll_to_bottom() -> void:
        if not is_inside_tree(): return
        await get_tree().process_frame
        if not is_inside_tree(): return
        scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
