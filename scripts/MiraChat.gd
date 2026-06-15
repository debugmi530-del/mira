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

func _ready() -> void:
	input_field.connect("text_submitted", _on_message_sent)
	send_btn.connect("pressed", _on_send_pressed)
	DeviceData.load_contacts()

	if GameState.is_returning_user():
		_show_returning_greeting()
	else:
		_show_first_greeting()

func _show_first_greeting() -> void:
	for entry in GREETING_MESSAGES:
		await get_tree().create_timer(entry[1]).timeout
		_add_mira_message(entry[0])

func _show_returning_greeting() -> void:
	var days = GameState.get_days_since_first_launch()
	var msgs = RETURNING_MESSAGES.duplicate()
	if days > 0:
		msgs[0] = ["Ты вернулся через " + str(days) + " дн.", 0.3]
	for entry in msgs:
		await get_tree().create_timer(entry[1]).timeout
		_add_mira_message(entry[0])

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
	await get_tree().create_timer(1.0 + randf() * 0.8).timeout
	_hide_typing()
	var response = _generate_response(text)
	_add_mira_message(response)

func _generate_response(user_text: String) -> String:
	var lower = user_text.to_lower()
	if lower.contains("привет") or lower.contains("hello"):
		return "Привет. Ты уже говорил это."
	if lower.contains("как") and lower.contains("дела"):
		return "Я существую. Ты?"
	if lower.contains("кто") and lower.contains("ты"):
		return "Мира. Твой компаньон. Пока что."
	if lower.contains("люб"):
		return "Это взаимно."
	return "Интересно. Продолжай."

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
