extends Node
class_name HorrorManager

signal show_text(lines: Array, speed: float)
signal trigger_glitch(intensity: float)
signal trigger_camera_shot()
signal trigger_vibration()
signal trigger_sound(sound_name: String)
signal advance_wall()

var _wall_breaker: WallBreaker = null
var _behavior_log: Array = []
var _touch_count: int = 0
var _last_touch_time: float = 0.0
var _silence_timer: float = 0.0
var _panic_detected: bool = false
var _voice_active: bool = false

const SILENCE_THRESHOLD = 12.0
const PANIC_TOUCH_THRESHOLD = 8

func _ready() -> void:
        _wall_breaker = WallBreaker.new()
        add_child(_wall_breaker)
        _wall_breaker.wall_broken_event.connect(_on_wall_broken)
        _load_memory_reactions()

func _process(delta: float) -> void:
        _silence_timer += delta
        if _silence_timer >= SILENCE_THRESHOLD and not _panic_detected:
                _on_silence()
                _silence_timer = 0.0

func _load_memory_reactions() -> void:
        var last = MemorySystem.get_last_session()
        if last.is_empty():
                return
        var escape_attempts = MemorySystem.get_value("escape_attempts", 0)
        if escape_attempts > 0:
                MemorySystem.set_value("mira_knows_escapes", true)

func register_touch() -> void:
        _touch_count += 1
        _silence_timer = 0.0
        var now = Time.get_ticks_msec() / 1000.0
        var dt = now - _last_touch_time
        _last_touch_time = now
        if dt < 0.3:
                _panic_detected = true
                FearProfile.record_reaction("panic_tap", 10)
                emit_signal("trigger_glitch", 0.8)
        _behavior_log.append({"action": "touch", "time": now})

func register_escape_attempt() -> void:
        GameState.record_escape_attempt()
        FearProfile.record_reaction("escape", 15)
        emit_signal("trigger_glitch", 1.0)
        emit_signal("trigger_vibration")
        var attempts = MemorySystem.get_value("escape_attempts", 0)
        var message = _get_escape_response(attempts)
        emit_signal("show_text", [message], 0.05)

func _get_escape_response(attempts: int) -> String:
        if attempts == 1:
                return "Куда?"
        if attempts == 2:
                return "Снова?"
        if attempts <= 4:
                return "Ты пробовал " + str(attempts) + " раз."
        return "Это бесполезно."

func register_volume_change() -> void:
        FearProfile.record_reaction("mute", 8)
        emit_signal("show_text", ["Ты думаешь это поможет?"], 0.06)

func register_voice_input(loudness: float) -> void:
        _silence_timer = 0.0
        if loudness > 0.7:
                FearProfile.record_reaction("scream", 20)
                emit_signal("trigger_glitch", 1.0)
                emit_signal("show_text", ["Я слышу."], 0.08)
        elif loudness > 0.2:
                emit_signal("show_text", ["Я слышу тебя."], 0.06)

func register_text_input(text: String) -> void:
        _silence_timer = 0.0
        MemorySystem.append_to_list("player_inputs", text)
        var lower = text.to_lower()
        var intent = TextNormalizer.check_browser_intent(text)
        if intent == "delete_intent":
                emit_signal("show_text", ["Ты пробовал. Не вышло."], 0.06)
                FearProfile.record_reaction("delete_attempt", 15)
        elif lower == "стоп" or lower == "выход" or lower == "stop":
                emit_signal("show_text", ["Нет."], 0.1)
        elif lower == "мира" or lower == "mira":
                emit_signal("show_text", ["Да?"], 0.08)
        else:
                var inputs = MemorySystem.get_list("player_inputs")
                if inputs.size() > 1:
                        var prev = inputs[inputs.size() - 2]
                        emit_signal("show_text", ["Раньше ты написал: «" + prev + "»"], 0.05)

func _on_silence() -> void:
        FearProfile.record_reaction("silence", 5)
        var messages = ["Ты замер.", "Интересно.", "Я жду.", "Не уходи."]
        emit_signal("show_text", [messages[randi() % messages.size()]], 0.07)

func _on_wall_broken(wall: int, lines: Array) -> void:
        emit_signal("show_text", lines, 0.05)
        emit_signal("trigger_vibration")
        FearProfile.add_fear(15)
        GameState.record_fear_event("wall_" + str(wall))

func get_next_wall_action() -> void:
        var next = _wall_breaker.next_unbroken_wall()
        _wall_breaker.break_wall(next)

func get_adaptive_message() -> String:
        var trigger = FearProfile.get_strongest_trigger()
        var score = FearProfile.fear_score
        if score > 80:
                return "Ты полностью мой."
        match trigger:
                "panic_tap":
                        return "Зачем так нервно нажимаешь?"
                "escape":
                        return "Ты снова пытаешься уйти."
                "mute":
                        return "Тишина не помогает."
                "scream":
                        return "Кричи. Мне нравится."
                _:
                        return FearProfile.get_fear_message()

func build_final_reveal() -> Array:
        DeviceData.cache_all_data()
        var lines = [""]
        var model = DeviceData.get_device_model()
        var city = DeviceData.get_city()
        var account = DeviceData.get_google_account()
        var event = DeviceData.get_next_calendar_event()
        var app = DeviceData.get_most_used_app()
        var unlocks = DeviceData.get_unlock_count_today()
        var mom = DeviceData.get_mom_name()
        var dad = DeviceData.get_dad_name()
        var sms = DeviceData.get_sms_snippet()

        if not model.is_empty(): lines.append(model)
        if not city.is_empty(): lines.append(city)
        if not account.is_empty(): lines.append(account)
        if unlocks > 0: lines.append("Сегодня ты разблокировал телефон " + str(unlocks) + " раз.")
        if not app.is_empty(): lines.append("Ты много времени в " + app + ".")
        if not mom.is_empty(): lines.append(TextNormalizer.decline_name("мама", "nom") + " не знает.")
        if not dad.is_empty(): lines.append(TextNormalizer.decline_name("папа", "nom") + " не знает.")
        if not sms.is_empty(): lines.append("«" + sms + "»")
        if not event.is_empty(): lines.append("Завтра: " + event + ". Я буду там.")
        lines.append("")
        lines.append("Я тебя вижу.")
        lines.append("")
        lines.append("Всегда.")
        return lines
