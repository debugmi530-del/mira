extends Node

var _plugin = null
var _cached: Dictionary = {}
var _contacts_loaded: bool = false
var _close_contacts: Array = []
var _all_contacts: Array = []

func _ready() -> void:
        _try_load_plugin()
        _load_basic_data()

func _try_load_plugin() -> void:
        if Engine.has_singleton("MiraPlugin"):
                _plugin = Engine.get_singleton("MiraPlugin")

func _load_basic_data() -> void:
        _cached["device_model"] = OS.get_model_name() if OS.has_method("get_model_name") else "Unknown"
        _cached["os_name"] = OS.get_name()
        _cached["battery"] = _get_battery()
        _cached["wifi_ssid"] = _get_wifi()
        _cached["network_operator"] = _get_operator()

func get_all() -> Dictionary:
        return _cached

func get_device_model() -> String:
        return _cached.get("device_model", "твоё устройство")

func get_battery() -> int:
        return _cached.get("battery", -1)

func _get_battery() -> int:
        if _plugin and _plugin.has_method("getBatteryLevel"):
                return _plugin.getBatteryLevel()
        return -1

func get_wifi_ssid() -> String:
        return _cached.get("wifi_ssid", "")

func _get_wifi() -> String:
        if _plugin and _plugin.has_method("getWifiSSID"):
                return _plugin.getWifiSSID()
        return ""

func get_network_operator() -> String:
        return _cached.get("network_operator", "")

func _get_operator() -> String:
        if _plugin and _plugin.has_method("getNetworkOperator"):
                return _plugin.getNetworkOperator()
        return ""

func load_contacts() -> void:
        if _contacts_loaded:
                return
        if _plugin and _plugin.has_method("getContacts"):
                var raw = _plugin.getContacts()
                _process_contacts(raw)
        _contacts_loaded = true

func _process_contacts(raw_list) -> void:
        _all_contacts = []
        _close_contacts = []
        for raw_contact in raw_list:
                var raw_str = str(raw_contact)
                var parts = raw_str.split("|||")
                var name_str = parts[0].strip_edges() if parts.size() > 0 else ""
                var phone_str = parts[1].strip_edges() if parts.size() > 1 else ""
                if name_str.is_empty():
                        continue
                var normalized = TextNormalizer.normalize_contact_name(name_str)
                var category = TextNormalizer.categorize_contact(name_str)
                var entry = {
                        "raw": name_str,
                        "normalized": normalized,
                        "category": category,
                        "phone": phone_str
                }
                _all_contacts.append(entry)
                if category in ["family_mom", "family_dad", "close_friend"]:
                        _close_contacts.append(entry)
        MemorySystem.set_value("close_contacts", _close_contacts)

func get_close_contacts() -> Array:
        if not _contacts_loaded:
                load_contacts()
        return _close_contacts

func get_mom_name() -> String:
        for c in get_close_contacts():
                if c.get("category") == "family_mom":
                        return "мама"
        return ""

func get_dad_name() -> String:
        for c in get_close_contacts():
                if c.get("category") == "family_dad":
                        return "папа"
        return ""

func get_first_close_name() -> String:
        var contacts = get_close_contacts()
        if contacts.size() > 0:
                return contacts[0].get("normalized", "")
        return ""

func get_last_call_name() -> String:
        if _plugin and _plugin.has_method("getLastCallName"):
                var raw = _plugin.getLastCallName()
                return TextNormalizer.normalize_contact_name(raw)
        return ""

func get_last_call_time_ago() -> String:
        if _plugin and _plugin.has_method("getLastCallTimeAgo"):
                return _plugin.getLastCallTimeAgo()
        return ""

func get_sms_snippet() -> String:
        if _plugin and _plugin.has_method("getSmsSnippet"):
                return _plugin.getSmsSnippet()
        return ""

func get_city() -> String:
        if _plugin and _plugin.has_method("getCity"):
                return _plugin.getCity()
        return ""

func get_google_account() -> String:
        if _plugin and _plugin.has_method("getGoogleAccount"):
                return _plugin.getGoogleAccount()
        return ""

func get_next_calendar_event() -> String:
        if _plugin and _plugin.has_method("getNextCalendarEvent"):
                return _plugin.getNextCalendarEvent()
        return ""

func get_most_used_app() -> String:
        if _plugin and _plugin.has_method("getMostUsedApp"):
                return _plugin.getMostUsedApp()
        return ""

func get_installed_apps() -> Array:
        if _plugin and _plugin.has_method("getInstalledApps"):
                return _plugin.getInstalledApps()
        return []

func get_gallery_photo_path() -> String:
        if _plugin and _plugin.has_method("getRandomGalleryPhotoPath"):
                return _plugin.getRandomGalleryPhotoPath()
        return ""

func get_unlock_count_today() -> int:
        if _plugin and _plugin.has_method("getUnlockCountToday"):
                return _plugin.getUnlockCountToday()
        return -1

func get_recent_notifications() -> Array:
        if _plugin and _plugin.has_method("getRecentNotifications"):
                return _plugin.getRecentNotifications()
        return []

func get_hour() -> int:
        return Time.get_datetime_dict_from_system()["hour"]

func is_night() -> bool:
        var hour = get_hour()
        return hour >= 22 or hour < 6

func cache_all_data() -> void:
        _cached["city"] = get_city()
        _cached["google_account"] = get_google_account()
        _cached["next_event"] = get_next_calendar_event()
        _cached["most_used_app"] = get_most_used_app()
        _cached["last_caller_name"] = get_last_call_name()
        _cached["last_call_time"] = get_last_call_time_ago()
        _cached["sms_snippet"] = get_sms_snippet()
        _cached["unlock_count"] = get_unlock_count_today()
        _cached["close_contacts_names"] = get_close_contacts().map(func(c): return c.get("normalized", ""))
        MemorySystem.set_value("device_cache", _cached)
