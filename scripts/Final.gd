extends Node

@onready var camera_photo: TextureRect = $UI/CameraPhoto
@onready var overlay_text: Label = $UI/OverlayText
@onready var sub_text: Label = $UI/SubText
@onready var glitch_overlay: ColorRect = $UI/GlitchOverlay
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
        MemorySystem.set_value("last_phase", GameState.Phase.FINAL)
        _run_final_sequence()

func _run_final_sequence() -> void:
        await get_tree().create_timer(0.5).timeout
        _take_photo_and_show()
        await get_tree().create_timer(2.5).timeout
        _show_overlay_text()
        await get_tree().create_timer(3.0).timeout
        _show_sub_text()
        await get_tree().create_timer(2.0).timeout
        _lock_screen()

func _take_photo_and_show() -> void:
        if Engine.has_singleton("MiraPlugin"):
                var plugin = Engine.get_singleton("MiraPlugin")
                if plugin.has_method("takeFrontCameraPhoto"):
                        var path = plugin.takeFrontCameraPhoto()
                        await get_tree().create_timer(2.5).timeout
                        if not path.is_empty():
                                var img = Image.load_from_file(path)
                                if img:
                                        var tex = ImageTexture.create_from_image(img)
                                        if camera_photo:
                                                camera_photo.texture = tex
                                                camera_photo.visible = true
                                                if anim:
                                                        anim.play("photo_reveal")
        _do_glitch_sequence()

func _do_glitch_sequence() -> void:
        for i in range(5):
                if glitch_overlay:
                        glitch_overlay.visible = true
                        glitch_overlay.color = Color(randf() * 0.5, 0.0, 0.0, 0.4)
                Input.vibrate_handheld(200)
                await get_tree().create_timer(0.1).timeout
                if glitch_overlay:
                        glitch_overlay.visible = false
                await get_tree().create_timer(0.05 + randf() * 0.1).timeout

func _show_overlay_text() -> void:
        if overlay_text:
                overlay_text.visible = true
                overlay_text.text = ""
                var full_text = "Я тебя вижу."
                for ch in full_text:
                        overlay_text.text += ch
                        await get_tree().create_timer(0.08).timeout
        Input.vibrate_handheld(500)

func _show_sub_text() -> void:
        if sub_text:
                sub_text.visible = true
                sub_text.text = ""
                var texts = ["", "Всегда."]
                var fear_level = FearProfile.get_level()
                if fear_level == "broken":
                        texts = ["", "Ты полностью мой.", "", "Всегда."]
                elif fear_level == "terrified":
                        texts = ["", "Ты боялся.", "", "Правильно.", "", "Всегда."]

                for line in texts:
                        if line.is_empty():
                                sub_text.text += "\n"
                                await get_tree().create_timer(0.5).timeout
                        else:
                                for ch in line:
                                        sub_text.text += ch
                                        await get_tree().create_timer(0.07).timeout
                                await get_tree().create_timer(0.8).timeout

func _lock_screen() -> void:
        Input.vibrate_handheld(1000)
        MemorySystem.save_session({
                "fear_score": FearProfile.fear_score,
                "fear_level": FearProfile.get_level(),
                "walls_broken": MemorySystem.get_value("walls_broken", []),
                "escape_attempts": MemorySystem.get_value("escape_attempts", 0)
        })
        await get_tree().create_timer(1.5).timeout
        if Engine.has_singleton("MiraPlugin"):
                var plugin = Engine.get_singleton("MiraPlugin")
                if plugin.has_method("lockScreen"):
                        plugin.lockScreen()
