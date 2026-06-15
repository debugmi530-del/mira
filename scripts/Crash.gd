extends Node

@onready var glitch_rect: ColorRect = $GlitchRect
@onready var error_label: Label = $ErrorLabel
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_change_app_identity()
	_start_crash_sequence()

func _change_app_identity() -> void:
	if Engine.has_singleton("MiraPlugin"):
		var plugin = Engine.get_singleton("MiraPlugin")
		if plugin.has_method("setAppAlias"):
			plugin.setAppAlias("horror")

func _start_crash_sequence() -> void:
	if anim:
		anim.play("crash_glitch")
	await get_tree().create_timer(0.4).timeout
	_show_error("FATAL ERROR: NullReferenceException")
	await get_tree().create_timer(0.6).timeout
	_show_error("Process: com.mira.companion\nPID: " + str(randi_range(1000, 9999)))
	await get_tree().create_timer(0.5).timeout
	_show_error("SIGABRT")
	await get_tree().create_timer(1.2).timeout
	_force_crash_look()
	await get_tree().create_timer(2.0).timeout
	MemorySystem.set_value("last_phase", GameState.Phase.HORROR)
	get_tree().change_scene_to_file("res://scenes/HorrorPhase.tscn")

func _show_error(text: String) -> void:
	if error_label:
		error_label.text = text
		error_label.visible = true
	if glitch_rect:
		glitch_rect.visible = true
		await get_tree().create_timer(0.15).timeout
		glitch_rect.visible = false

func _force_crash_look() -> void:
	if error_label:
		error_label.text = "Приложение остановлено"
	var bg = get_node_or_null("Background")
	if bg:
		bg.color = Color(0.05, 0.0, 0.0)
