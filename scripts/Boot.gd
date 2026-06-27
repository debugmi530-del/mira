extends Node

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var last_phase = MemorySystem.get_value("last_phase", GameState.Phase.COMPANION)

	# Если хоррор пройден до конца — идём в MiraChat (режим "после")
	if last_phase == GameState.Phase.FINAL:
		MemorySystem.set_value("last_phase", GameState.Phase.COMPANION)
		get_tree().change_scene_to_file("res://scenes/MiraChat.tscn")
	elif last_phase >= GameState.Phase.HORROR:
		get_tree().change_scene_to_file("res://scenes/HorrorPhase.tscn")
	elif last_phase == GameState.Phase.CRASH:
		get_tree().change_scene_to_file("res://scenes/Crash.tscn")
	else:
		if GameState.is_returning_user():
			get_tree().change_scene_to_file("res://scenes/MiraChat.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/PermissionSetup.tscn")
