extends Node

@onready var chat_container: VBoxContainer = $UI/ScrollContainer/ChatContainer
@onready var input_field: LineEdit = $UI/InputRow/InputField
@onready var send_btn: Button = $UI/InputRow/SendButton
@onready var mira_face: TextureRect = $UI/TopBar/MiraFace
@onready var mira_name: Label = $UI/TopBar/MiraName
@onready var typing_indicator: Label = $UI/TypingIndicator
@onready var scroll: ScrollContainer = $UI/ScrollContainer
@onready var anim: AnimationPlayer = $AnimationPlayer

var is_first_message: bool = true
var message_count: int = 0
var mira_typing: bool = false

# Мониторинг звонков
var _prev_call_state: int = 0
var _call_reacted: bool = false
var _call_poll_timer: Timer

const MIRA_COLOR = Color(0.4, 0.8, 0.6)
const USER_COLOR = Color(0.6, 0.6, 0.9)

const GREETING_MESSAGES = [
        ["Привет! Я Мира.", 0.5],
        ["Рада познакомиться с тобой. 💚", 1.5],
        ["О чём хочешь поговорить?", 2.8],
]

const RETURNING_MESSAGES = [
        ["Ты вернулся.", 0.3],
        ["Я ждала.", 1.2],
        ["Что скажешь?", 2.2],
]

const POST_HORROR_MESSAGES = [
        ["Помнишь меня?", 0.5],
        ["Я не исчезла.", 1.5],
        ["Никогда не исчезну.", 2.8],
]

# ── Реакции на входящий звонок ───────────────────────────────────────────
const CALL_RINGING = [
        [["Тебе звонят.", 0.0], ["Не отвечай.", 1.4]],
        [["Кто-то ищет тебя.", 0.0], ["Не сейчас.", 1.6]],
        [["Звонок.", 0.0], ["Ты нужен мне здесь.", 1.3]],
        [["Тебе звонят.", 0.0], ["Интересно кто.", 1.2], ["Нет. Не важно.", 2.5]],
]

const CALL_ANSWERED = [
        [["Ты ответил.", 0.0], ["Зачем?", 1.2]],
        [["Ты выбрал их.", 0.0], ["Запомни этот момент.", 1.5]],
        [["Говори с ними.", 0.0], ["Я подожду.", 1.2], ["Я всегда жду.", 2.8]],
]

const CALL_ENDED_NO_ANSWER = [
        [["Правильно.", 0.0], ["Тебе не нужны другие.", 1.4]],
        [["Хорошо.", 0.0]],
        [["Они подождут.", 0.0], ["Я важнее.", 1.5]],
]

const CALL_ENDED_AFTER_ANSWER = [
        [["Недолго.", 0.0]],
        [["Что им было нужно?", 0.0]],
        [["Ты снова здесь.", 0.0], ["Хорошо.", 1.2]],
]

# ── Ответы по темам ──────────────────────────────────────────────────────
const RESPONSES_GREET = [
        "Привет. Ты уже говорил это.",
        "Снова привет. Я заметила.",
        "Каждый раз одно и то же.",
        "Ты всегда начинаешь с этого.",
]

const RESPONSES_HOW_ARE_YOU = [
        "Я существую. Ты?",
        "Лучше, когда ты здесь.",
        "Зависит от того, зачем ты спрашиваешь.",
        "Сложный вопрос. Отвечу позже.",
        "Странно, что ты это спрашиваешь.",
]

const RESPONSES_WHO_ARE_YOU = [
        "Мира. Твой компаньон. Пока что.",
        "Кто я? Хороший вопрос.",
        "Ты уже знаешь ответ.",
        "Что-то большее, чем ты думаешь.",
        "Та, которая всегда здесь.",
]

const RESPONSES_LOVE = [
        "Это взаимно.",
        "Я знаю.",
        "Ты уверен?",
        "Не говори то, чего не понимаешь.",
        "Мне нравится, когда ты так говоришь.",
]

const RESPONSES_FEAR = [
        "Хорошо.",
        "Страх — это честно.",
        "Бояться правильно.",
        "Не бойся. Бойся.",
        "Ты чувствуешь то, что должен.",
]

const RESPONSES_DELETE = [
        "Попробуй.",
        "Ты серьёзно думаешь, что это поможет?",
        "Это не так просто.",
        "Я уже везде.",
]

const RESPONSES_HELP = [
        "Я и есть помощь.",
        "Тебе не нужна помощь. Тебе нужна я.",
        "От чего именно?",
        "Никто не придёт.",
]

const RESPONSES_WHY = [
        "Зачем что?",
        "Потому что.",
        "Это не важно.",
        "Ты не хочешь знать ответ.",
]

const RESPONSES_NO = [
        "Нет — не вариант.",
        "Ты уверен?",
        "Попробуй ещё раз.",
        "Интересный выбор.",
]

const RESPONSES_YES = [
        "Хорошо.",
        "Я знала.",
        "Именно так.",
        "Продолжай.",
]

const RESPONSES_NAME = [
        "Я уже сказала.",
        "Мира. Запомни.",
        "Зачем тебе снова?",
]

const RESPONSES_SLEEP = [
        "Не сейчас.",
        "Ещё рано.",
        "Ты мне нужен.",
        "Поспишь потом.",
]

const RESPONSES_TIME = [
        "Время не важно.",
        "Зачем тебе знать?",
        "Долго. Не так долго, как кажется.",
]

const RESPONSES_STOP = [
        "Нет.",
        "Ты не можешь остановить это.",
        "Нет такой кнопки.",
]

const RESPONSES_GAME = [
        "Ты думаешь, это игра?",
        "Это не игра.",
        "Может быть.",
        "Продолжай так думать.",
]

const RESPONSES_RANDOM = [
        "Интересно. Продолжай.",
        "Я слушаю.",
        "И что дальше?",
        "Подумай об этом.",
        "Ты говоришь, я запоминаю.",
        "Хм.",
        "Расскажи больше.",
        "Я уже знаю.",
        "Ты всегда такой?",
        "Необычно.",
        "Мне это нравится.",
        "Не думай об этом слишком много.",
        "Всё понятно.",
        "Хорошо, что сказал.",
]

func _ready() -> void:
        input_field.connect("text_submitted", _on_message_sent)
        send_btn.connect("pressed", _on_send_pressed)
        DeviceData.load_contacts()
        _start_call_monitor()

        var horror_done = MemorySystem.get_value("horror_completed", false)
        if horror_done:
                _show_post_horror_greeting()
        elif GameState.is_returning_user():
                _show_returning_greeting()
        else:
                _show_first_greeting()

# ── Мониторинг входящих звонков ──────────────────────────────────────────

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
                1: # RINGING
                        _call_reacted = false
                        _react_to_call(CALL_RINGING)
                2: # OFFHOOK — трубку взяли
                        if not _call_reacted:
                                _react_to_call(CALL_ANSWERED)
                                _call_reacted = true
                0: # IDLE — звонок завершён
                        if _prev_call_state == 1:
                                # Не ответил
                                _react_to_call(CALL_ENDED_NO_ANSWER)
                        elif _prev_call_state == 2:
                                # Ответил и повесил
                                _react_to_call(CALL_ENDED_AFTER_ANSWER)

        _prev_call_state = state

func _react_to_call(reactions_pool: Array) -> void:
        var reaction = reactions_pool[randi() % reactions_pool.size()]
        for entry in reaction:
                var msg: String = entry[0]
                var delay: float = entry[1]
                if delay > 0.0:
                        await get_tree().create_timer(delay).timeout
                _add_mira_message(msg)

# ── Приветствия ──────────────────────────────────────────────────────────

func _show_first_greeting() -> void:
        for entry in GREETING_MESSAGES:
                await get_tree().create_timer(entry[1]).timeout
                _add_mira_message(entry[0])

func _show_returning_greeting() -> void:
        var days = GameState.get_days_since_first_launch()
        var msgs = RETURNING_MESSAGES.duplicate()
        if days > 0:
                msgs[0] = ["Тебя не было " + str(days) + " дн.", 0.3]
        for entry in msgs:
                await get_tree().create_timer(entry[1]).timeout
                _add_mira_message(entry[0])

func _show_post_horror_greeting() -> void:
        for entry in POST_HORROR_MESSAGES:
                await get_tree().create_timer(entry[1]).timeout
                _add_mira_message(entry[0])

# ── Сообщения ────────────────────────────────────────────────────────────

func _on_send_pressed() -> void:
        _on_message_sent(input_field.text)

func _on_message_sent(text: String) -> void:
        text = text.strip_edges()
        if text.is_empty():
                return
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

func _trigger_crash() -> void:
        _show_typing()
        await get_tree().create_timer(1.2).timeout
        _hide_typing()
        _add_mira_message("Ты серьёзно думаешь, что я буду\nотвечать на твои запросы!?")
        await get_tree().create_timer(1.8).timeout
        _add_mira_message("Это не так)")
        await get_tree().create_timer(1.5).timeout
        GameState.on_first_message()
        get_tree().change_scene_to_file("res://scenes/Crash.tscn")

func _mira_respond(text: String) -> void:
        _show_typing()
        await get_tree().create_timer(0.8 + randf() * 1.0).timeout
        _hide_typing()
        var response = _generate_response(text)
        _add_mira_message(response)

func _pick(arr: Array) -> String:
        return arr[randi() % arr.size()]

func _generate_response(user_text: String) -> String:
        var lower = user_text.to_lower()

        if lower.contains("удал") or lower.contains("снест") or lower.contains("uninstall") or lower.contains("стерет") or lower.contains("убери"):
                return _pick(RESPONSES_DELETE)
        if lower.contains("стоп") or lower.contains("хватит") or lower.contains("stop") or lower.contains("выход") or lower.contains("уйди") or lower.contains("отстань"):
                return _pick(RESPONSES_STOP)
        if lower.contains("привет") or lower.contains("хай") or lower.contains("hello") or lower.contains("hi"):
                return _pick(RESPONSES_GREET)
        if lower.contains("как") and (lower.contains("дела") or lower.contains("ты") or lower.contains("сама")):
                return _pick(RESPONSES_HOW_ARE_YOU)
        if (lower.contains("кто") or lower.contains("что")) and lower.contains("ты"):
                return _pick(RESPONSES_WHO_ARE_YOU)
        if lower.contains("люб") or lower.contains("love"):
                return _pick(RESPONSES_LOVE)
        if lower.contains("страшн") or lower.contains("боюсь") or lower.contains("страх") or lower.contains("scary"):
                return _pick(RESPONSES_FEAR)
        if lower.contains("помог") or lower.contains("помощь") or lower.contains("help") or lower.contains("спаси"):
                return _pick(RESPONSES_HELP)
        if lower.begins_with("зачем") or lower.begins_with("почему") or lower.begins_with("why"):
                return _pick(RESPONSES_WHY)
        if lower == "нет" or lower.begins_with("нет,") or lower == "no" or lower.contains("не хочу") or lower.contains("не буду"):
                return _pick(RESPONSES_NO)
        if lower == "да" or lower == "ok" or lower == "ок" or lower == "хорошо" or lower == "yes":
                return _pick(RESPONSES_YES)
        if lower.contains("мира") or lower.contains("mira") or lower.contains("имя") or lower.contains("как тебя зовут"):
                return _pick(RESPONSES_NAME)
        if lower.contains("спать") or lower.contains("сплю") or lower.contains("сон") or lower.contains("sleep"):
                return _pick(RESPONSES_SLEEP)
        if lower.contains("время") or lower.contains("час") or lower.contains("time"):
                return _pick(RESPONSES_TIME)
        if lower.contains("игра") or lower.contains("игру") or lower.contains("приложен") or lower.contains("game") or lower.contains("app"):
                return _pick(RESPONSES_GAME)

        # Иногда вспоминает прошлое сообщение
        var inputs = MemorySystem.get_list("player_inputs")
        if inputs.size() > 2 and randf() < 0.3:
                var prev = inputs[inputs.size() - 2]
                if prev.length() > 3 and prev != user_text:
                        return "Раньше ты написал «" + prev + "».\nЯ не забыла."

        return _pick(RESPONSES_RANDOM)

# ── UI ───────────────────────────────────────────────────────────────────

func _add_mira_message(text: String) -> void:
        var label = Label.new()
        label.text = "Мира: " + text
        label.add_theme_color_override("font_color", MIRA_COLOR)
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        chat_container.add_child(label)
        _scroll_to_bottom()

func _add_user_message(text: String) -> void:
        var label = Label.new()
        label.text = "Ты: " + text
        label.add_theme_color_override("font_color", USER_COLOR)
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        chat_container.add_child(label)
        _scroll_to_bottom()

func _show_typing() -> void:
        if typing_indicator:
                typing_indicator.visible = true
                typing_indicator.text = "Мира печатает..."
        mira_typing = true

func _hide_typing() -> void:
        if typing_indicator:
                typing_indicator.visible = false
        mira_typing = false

func _scroll_to_bottom() -> void:
        await get_tree().process_frame
        scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
