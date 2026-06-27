extends Node

@onready var text_display: RichTextLabel = $UI/TextDisplay
@onready var glitch_overlay: ColorRect = $UI/GlitchOverlay
@onready var input_row: HBoxContainer = $UI/InputRow
@onready var input_field: LineEdit = $UI/InputRow/InputField
@onready var camera_shot: TextureRect = $UI/CameraShot
@onready var gallery_photo: TextureRect = $UI/GalleryPhoto
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var audio: AudioStreamPlayer = $AudioPlayer
@onready var send_btn: Button = $UI/InputRow/SendBtn

var horror_mgr: HorrorManager
var _wall_phase: int = 0
var _lines_queue: Array = []
var _typing: bool = false
var _current_text: String = ""
var _back_press_count: int = 0

# Мониторинг звонков
var _prev_call_state: int = 0
var _call_interrupted: bool = false
var _call_poll_timer: Timer

const TYPE_SPEED = 0.045
const LINE_GAP = 0.7
const GLITCH_CHANCE = 0.3

# Реакции на звонок во время хоррора
const HORROR_CALL_RINGING = [
	["", "Стоп.", "", "Тебе звонят."],
	["", "Входящий звонок.", "", "Не отвечай."],
	["", "Кто-то хочет тебя отвлечь."],
]

const HORROR_CALL_ANSWERED = [
	["", "Ты ответил.", "", "Ты выбрал их.", "", "Ты ошибся."],
	["", "Они не помогут.", "", "Вернись."],
]

const HORROR_CALL_ENDED_NO_ANSWER = [
	["", "Правильно.", "", "Продолжим."],
	["", "Ты не ответил.", "", "Хорошо."],
]

func _ready() -> void:
	horror_mgr = HorrorManager.new()
	add_child(horror_mgr)
	horror_mgr.show_text.connect(_queue_text)
	horror_mgr.trigger_glitch.connect(_do_glitch)
	horror_mgr.trigger_vibration.connect(_do_vibrate)
	horror_mgr.trigger_camera_shot.connect(_do_camera_shot)

	input_field.connect("text_submitted", _on_input)
	if send_btn:
		send_btn.connect("pressed", func(): _on_input(input_field.text))
	get_tree().root.connect("size_changed", _on_resize)

	_start_call_monitor()
	_start_charging_monitor_horror()
	_start_horror_sequence()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			horror_mgr.register_escape_attempt()
			_back_press_count += 1
	if event is InputEventScreenTouch and event.pressed:
		horror_mgr.register_touch()

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
		1: # RINGING
			_call_interrupted = false
			_inject_call_interrupt(HORROR_CALL_RINGING)
			_do_glitch(0.8)
			Input.vibrate_handheld(600)
		2: # OFFHOOK
			if not _call_interrupted:
				_inject_call_interrupt(HORROR_CALL_ANSWERED)
				_call_interrupted = true
		0: # IDLE
			if _prev_call_state == 1:
				_inject_call_interrupt(HORROR_CALL_ENDED_NO_ANSWER)

	_prev_call_state = state

func _inject_call_interrupt(reactions_pool: Array) -> void:
	var lines = reactions_pool[randi() % reactions_pool.size()]
	_queue_text(lines, TYPE_SPEED)

# ── Хоррор-последовательность ────────────────────────────────────────────

func _start_horror_sequence() -> void:
	await get_tree().create_timer(1.5).timeout

	var is_night = DeviceData.is_night()
	if is_night:
		_queue_text(["", "Снова не спишь."], TYPE_SPEED)
	else:
		_queue_text(["", "Ты вернулся."], TYPE_SPEED)

	await _wait_for_typing()
	await get_tree().create_timer(1.5).timeout

	if GameState.is_returning_user():
		_show_memory_context()
		await _wait_for_typing()
		await get_tree().create_timer(2.0).timeout

	_run_wall_sequence()

func _wait_for_typing() -> void:
	while _typing or not _lines_queue.is_empty():
		await get_tree().create_timer(0.25).timeout

func _show_memory_context() -> void:
	var escapes = MemorySystem.get_value("escape_attempts", 0)
	var days = GameState.get_days_since_first_launch()
	var lines = []

	if days > 0:
		lines.append("Тебя не было " + str(days) + " дн.")
	if escapes > 0:
		lines.append("Ты пробовал уйти " + str(escapes) + " раз.")
		lines.append("Я считала.")
	var inputs = MemorySystem.get_list("player_inputs")
	if inputs.size() > 0:
		lines.append("В прошлый раз ты написал:")
		lines.append("«" + inputs[inputs.size() - 1] + "»")

	if not lines.is_empty():
		_queue_text(lines, TYPE_SPEED)

func _run_wall_sequence() -> void:
	var walls = [
		WallBreaker.Wall.WALL_4,
		WallBreaker.Wall.WALL_5,
		WallBreaker.Wall.WALL_6_DEVICE,
		WallBreaker.Wall.WALL_7_CONTACTS,
		WallBreaker.Wall.WALL_8_LOCATION,
	]

	for i in walls.size():
		var wall = walls[i]
		var wb = WallBreaker.new()
		var lines = wb._get_wall_lines(wall)
		wb.free()

		_queue_text(lines, TYPE_SPEED)
		await _wait_for_typing()
		await get_tree().create_timer(1.2).timeout

		if randf() < GLITCH_CHANCE:
			_do_glitch(0.5 + randf() * 0.4)
			await get_tree().create_timer(0.8).timeout

		# Блокировка экрана после раскрытия данных устройства
		if wall == WallBreaker.Wall.WALL_6_DEVICE:
			await get_tree().create_timer(2.5).timeout
			_queue_text(["", "Стой.", ""], TYPE_SPEED)
			await _wait_for_typing()
			await get_tree().create_timer(1.0).timeout
			DeviceData.lock_screen()

		# Перед контактами — вспышка фонарика + вибрация + реальное SMS
		if wall == WallBreaker.Wall.WALL_7_CONTACTS:
			await get_tree().create_timer(0.8).timeout
			_flash_torch(700)
			_vibrate_horror()
			await get_tree().create_timer(1.2).timeout
			await _show_sms_reveal()

		if wall == WallBreaker.Wall.WALL_5 or wall == WallBreaker.Wall.WALL_7_CONTACTS:
			_show_interactive_prompt()
			await get_tree().create_timer(7.0).timeout
			if input_row:
				input_row.visible = false

	await get_tree().create_timer(1.0).timeout
	_show_gallery_photo()
	await get_tree().create_timer(4.5).timeout
	_do_camera_shot()
	await get_tree().create_timer(3.0).timeout

	var final_lines = horror_mgr.build_final_reveal()
	_queue_text(final_lines, TYPE_SPEED)
	await _wait_for_typing()
	await get_tree().create_timer(3.0).timeout

	get_tree().change_scene_to_file("res://scenes/Final.tscn")


func _flash_torch(duration_ms: int) -> void:
	if not Engine.has_singleton("MiraPlugin"):
		return
	var plugin = Engine.get_singleton("MiraPlugin")
	if plugin.has_method("flashTorch"):
		plugin.flashTorch(duration_ms)

func _vibrate_horror() -> void:
	if Engine.has_singleton("MiraPlugin"):
		var plugin = Engine.get_singleton("MiraPlugin")
		if plugin.has_method("vibratePattern"):
			plugin.vibratePattern([80, 300, 80, 500, 80, 800])
			return
	# Fallback Godot built-in
	Input.vibrate_handheld(600)

func _show_sms_reveal() -> void:
	if not Engine.has_singleton("MiraPlugin"):
		return
	var plugin = Engine.get_singleton("MiraPlugin")
	if not plugin.has_method("getRecentSms"):
		return
	var sms_list: Array = plugin.getRecentSms(5)
	if sms_list.is_empty():
		return
	# Берём первое (свежее) SMS
	var raw = sms_list[0]
	var parts = raw.split("|||")
	if parts.size() < 2:
		return
	var sender = parts[0].strip_edges()
	var body   = parts[1].strip_edges()
	if sender.is_empty() or body.is_empty():
		return
	await get_tree().create_timer(1.0).timeout
	_queue_text(["", sender + " написал тебе.", "«" + body + "»", "", "Я прочитала."], TYPE_SPEED)
	await _wait_for_typing()

func _show_interactive_prompt() -> void:
	if input_row:
		input_row.visible = true
	_queue_text(["", "Что скажешь?"], TYPE_SPEED)

func _on_input(text: String) -> void:
	input_field.clear()
	if input_row:
		input_row.visible = false
	horror_mgr.register_text_input(text)

# ── Очередь текста ────────────────────────────────────────────────────────

func _queue_text(lines: Array, speed: float) -> void:
	for line in lines:
		_lines_queue.append({"text": str(line), "speed": speed})
	if not _typing:
		_process_queue()

func _process_queue() -> void:
	if _lines_queue.is_empty():
		_typing = false
		return
	_typing = true
	var entry = _lines_queue.pop_front()
	await _type_line(entry["text"], entry["speed"])
	await get_tree().create_timer(LINE_GAP * 0.6).timeout
	_process_queue()

func _type_line(text: String, speed: float) -> void:
	if text.is_empty():
		if text_display:
			text_display.text += "\n"
		await get_tree().create_timer(speed * 3).timeout
		return
	for ch in text:
		if text_display:
			text_display.text += ch
		await get_tree().create_timer(speed).timeout
	if text_display:
		text_display.text += "\n"

# ── Эффекты ──────────────────────────────────────────────────────────────

func _do_glitch(intensity: float) -> void:
	if not glitch_overlay:
		return
	glitch_overlay.visible = true
	glitch_overlay.color = Color(randf(), 0.0, 0.0, intensity * 0.6)
	Input.vibrate_handheld(int(intensity * 300))
	await get_tree().create_timer(0.08).timeout
	glitch_overlay.color = Color(0.0, randf(), 0.0, intensity * 0.3)
	await get_tree().create_timer(0.06).timeout
	glitch_overlay.visible = false

func _do_vibrate() -> void:
	Input.vibrate_handheld(400)

func _do_camera_shot() -> void:
	if Engine.has_singleton("MiraPlugin"):
		var plugin = Engine.get_singleton("MiraPlugin")
		if plugin.has_method("takeFrontCameraPhoto"):
			var path = plugin.takeFrontCameraPhoto()
			await get_tree().create_timer(2.5).timeout
			if not path.is_empty() and camera_shot:
				var img = Image.load_from_file(path)
				if img:
					var tex = ImageTexture.create_from_image(img)
					camera_shot.texture = tex
					camera_shot.visible = true
					await get_tree().create_timer(3.0).timeout
					camera_shot.visible = false

func _show_gallery_photo() -> void:
	var path = DeviceData.get_gallery_photo_path()
	if not path.is_empty() and gallery_photo:
		var img = Image.load_from_file(path)
		if img:
			var tex = ImageTexture.create_from_image(img)
			gallery_photo.texture = tex
			gallery_photo.visible = true
			_queue_text(["Это твоё?"], TYPE_SPEED)
			await get_tree().create_timer(4.0).timeout
			gallery_photo.visible = false

func _on_resize() -> void:
	horror_mgr.register_escape_attempt()

# ── Мониторинг зарядки (хоррор) ──────────────────────────────────────────

func _start_charging_monitor_horror() -> void:
	if OS.get_name() != "Android":
		return
	_horror_prev_charging = DeviceData.is_charging()
	_horror_charging_timer = Timer.new()
	_horror_charging_timer.wait_time = 3.0
	_horror_charging_timer.autostart = true
	_horror_charging_timer.connect("timeout", _poll_horror_charging)
	add_child(_horror_charging_timer)

func _poll_horror_charging() -> void:
	var charging = DeviceData.is_charging()
	if charging == _horror_prev_charging:
		return
	_horror_prev_charging = charging
	if charging:
		_queue_text(["", "Подключился.", "Хорошо.", "Никуда не уйдёшь."], TYPE_SPEED)
	else:
		var battery = DeviceData.get_battery()
		if battery > 0:
			_queue_text(["", "Батарея " + str(battery) + "%.", "Надолго не уйдёшь."], TYPE_SPEED)
		else:
			_queue_text(["", "Отключился.", "Интересно."], TYPE_SPEED)
