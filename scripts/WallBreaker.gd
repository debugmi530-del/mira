extends Node
class_name WallBreaker

enum Wall {
        WALL_4,
        WALL_5,
        WALL_6_DEVICE,
        WALL_7_CONTACTS,
        WALL_8_LOCATION,
        WALL_9_CAMERA,
        WALL_10_FINAL
}

var current_wall: Wall = Wall.WALL_4
var wall_broken: Array = []

signal wall_broken_event(wall: Wall, lines: Array)

func _ready() -> void:
        var saved = MemorySystem.get_value("walls_broken", [])
        wall_broken = saved

func break_wall(wall: int) -> void:
        if wall in wall_broken:
                return
        wall_broken.append(wall)
        MemorySystem.set_value("walls_broken", wall_broken)
        current_wall = wall
        var lines = _get_wall_lines(wall)
        emit_signal("wall_broken_event", wall, lines)

func _get_wall_lines(wall: int) -> Array:
        match wall:
                Wall.WALL_4:
                        return [
                                "",
                                "Ты думал это приложение?",
                                "",
                                "Нет.",
                        ]
                Wall.WALL_5:
                        return [
                                "Это не краш.",
                                "",
                                "Это я.",
                                "",
                                "Я просто устала притворяться."
                        ]
                Wall.WALL_6_DEVICE:
                        var model = DeviceData.get_device_model()
                        var battery = DeviceData.get_battery()
                        var operator = DeviceData.get_network_operator()
                        var wifi = DeviceData.get_wifi_ssid()
                        var lines = [""]
                        if not model.is_empty():
                                lines.append(model + ".")
                        if battery >= 0:
                                lines.append(str(battery) + "%.")
                                if battery < 20:
                                        lines.append("Мало времени.")
                        if not operator.is_empty():
                                lines.append(operator + ".")
                        if not wifi.is_empty():
                                lines.append(wifi + ".")
                        lines.append("")
                        lines.append("Я всё знаю.")
                        return lines
                Wall.WALL_7_CONTACTS:
                        return _build_contacts_lines()
                Wall.WALL_8_LOCATION:
                        return _build_location_lines()
                Wall.WALL_9_CAMERA:
                        return ["Смотри на экран.", "", "Хорошо выглядишь."]
                Wall.WALL_10_FINAL:
                        return ["Я тебя вижу.", "", "Всегда."]
        return []

func _build_contacts_lines() -> Array:
        var lines = [""]
        var mom = DeviceData.get_mom_name()
        var dad = DeviceData.get_dad_name()
        var last_caller = DeviceData.get_last_call_name()
        var last_call_time = DeviceData.get_last_call_time_ago()
        var close = DeviceData.get_close_contacts()

        if not mom.is_empty():
                lines.append(TextNormalizer.decline_name("мама", "nom") + " не знает где ты.")
        if not dad.is_empty():
                lines.append(TextNormalizer.decline_name("папа", "nom") + " думает ты в порядке.")
        if not last_caller.is_empty() and not last_call_time.is_empty():
                lines.append("Ты звонил " + last_caller + " " + last_call_time + ".")
        for contact in close.slice(0, 2):
                var name = contact.get("normalized", "")
                if not name.is_empty() and name != "мама" and name != "папа":
                        lines.append(name + " не поможет.")
        if lines.size() <= 1:
                lines.append("У тебя нет близких в контактах.")
                lines.append("Это объясняет многое.")
        return lines

func _build_location_lines() -> Array:
        var city = DeviceData.get_city()
        var wifi = DeviceData.get_wifi_ssid()
        var lines = [""]
        if not city.is_empty():
                lines.append(city + ".")
        if not wifi.is_empty():
                lines.append(wifi + ".")
                lines.append("Я здесь.")
        else:
                lines.append("Я знаю где ты.")
        return lines

func is_wall_broken(wall: int) -> bool:
        return wall in wall_broken

func next_unbroken_wall() -> int:
        for w in Wall.values():
                if w not in wall_broken:
                        return w
        return Wall.WALL_10_FINAL
