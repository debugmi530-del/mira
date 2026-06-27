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

func _has(method: String) -> bool:
	return _plugin != null and _plugin.has_method(method)

func _load_basic_data() -> void:
	_cached["device_model"] = OS.get_model_name() if OS.has_method("get_model_name") else "Unknown"
	_cached["os_name"] = OS.get_name()
	_cached["battery"] = _get_battery()
	_cached["wifi_ssid"] = _get_wifi()
	_cached["network_operator"] = _get_operator()
	_cached["system_language"] = _get_language()
	_cached["timezone"] = _get_timezone()

# ── Базовые данные ────────────────────────────────────────────────────────

func get_all() -> Dictionary:
	return _cached

func get_device_model() -> String:
	return _cached.get("device_model", "твоё устройство")

func get_battery() -> int:
	return _cached.get("battery", -1)

func _get_battery() -> int:
	if _has("getBatteryLevel"):
		return _plugin.getBatteryLevel()
	return -1

func get_wifi_ssid() -> String:
	return _cached.get("wifi_ssid", "")

func _get_wifi() -> String:
	if _has("getWifiSSID"):
		return _plugin.getWifiSSID()
	return ""

func get_network_operator() -> String:
	return _cached.get("network_operator", "")

func _get_operator() -> String:
	if _has("getNetworkOperator"):
		return _plugin.getNetworkOperator()
	return ""

func _get_language() -> String:
	if _has("getSystemLanguage"):
		return _plugin.getSystemLanguage()
	return ""

func _get_timezone() -> String:
	if _has("getTimezone"):
		return _plugin.getTimezone()
	return ""

func get_system_language() -> String:
	return _cached.get("system_language", "")

func get_timezone() -> String:
	return _cached.get("timezone", "")

# ── Батарея / Зарядка ────────────────────────────────────────────────────

func is_charging() -> bool:
	if _has("isCharging"):
		return _plugin.isCharging()
	return false

# ── Сеть ────────────────────────────────────────────────────────────────

func is_airplane_mode() -> bool:
	if _has("isAirplaneModeOn"):
		return _plugin.isAirplaneModeOn()
	return false

# ── Телефон ──────────────────────────────────────────────────────────────

func get_phone_number() -> String:
	if _has("getPhoneNumber"):
		return _plugin.getPhoneNumber()
	return ""

func get_call_state() -> int:
	if _has("getCallState"):
		return _plugin.getCallState()
	return 0

func get_call_count_today() -> int:
	if _has("getCallCountToday"):
		return _plugin.getCallCountToday()
	return 0

func get_missed_calls_count() -> int:
	if _has("getMissedCallsCount"):
		return _plugin.getMissedCallsCount()
	return 0

func get_last_call_direction() -> int:
	if _has("getLastCallDirection"):
		return _plugin.getLastCallDirection()
	return -1

# ── Контакты ────────────────────────────────────────────────────────────

func load_contacts() -> void:
	if _contacts_loaded:
		return
	if _has("getContacts"):
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

# ── Звонки ──────────────────────────────────────────────────────────────

func get_last_call_name() -> String:
	if _has("getLastCallName"):
		var raw = _plugin.getLastCallName()
		return TextNormalizer.normalize_contact_name(raw)
	return ""

func get_last_call_time_ago() -> String:
	if _has("getLastCallTimeAgo"):
		return _plugin.getLastCallTimeAgo()
	return ""

# ── SMS ─────────────────────────────────────────────────────────────────

func get_sms_snippet() -> String:
	if _has("getSmsSnippet"):
		return _plugin.getSmsSnippet()
	return ""

# ── Местоположение ───────────────────────────────────────────────────────

func get_city() -> String:
	if _has("getCity"):
		return _plugin.getCity()
	return ""

# ── Аккаунты / Календарь ────────────────────────────────────────────────

func get_google_account() -> String:
	if _has("getGoogleAccount"):
		return _plugin.getGoogleAccount()
	return ""

func get_next_calendar_event() -> String:
	if _has("getNextCalendarEvent"):
		return _plugin.getNextCalendarEvent()
	return ""

# ── Приложения ───────────────────────────────────────────────────────────

func get_most_used_app() -> String:
	if _has("getMostUsedApp"):
		return _plugin.getMostUsedApp()
	return ""

func get_installed_apps() -> Array:
	if _has("getInstalledApps"):
		return _plugin.getInstalledApps()
	return []

func get_unlock_count_today() -> int:
	if _has("getUnlockCountToday"):
		return _plugin.getUnlockCountToday()
	return -1

func get_current_foreground_app() -> String:
	if _has("getCurrentForegroundApp"):
		return _plugin.getCurrentForegroundApp()
	return ""

# ── Медиа ────────────────────────────────────────────────────────────────

func get_gallery_photo_path() -> String:
	if _has("getRandomGalleryPhotoPath"):
		return _plugin.getRandomGalleryPhotoPath()
	return ""

func get_random_video_path() -> String:
	if _has("getRandomVideoPath"):
		return _plugin.getRandomVideoPath()
	return ""

# ── Звук ────────────────────────────────────────────────────────────────

func get_ringer_mode() -> int:
	if _has("getRingerMode"):
		return _plugin.getRingerMode()
	return -1

func get_audio_amplitude() -> int:
	if _has("getAudioAmplitude"):
		return _plugin.getAudioAmplitude()
	return -1

# ── Экран / Хранилище ────────────────────────────────────────────────────

func get_screen_brightness() -> int:
	if _has("getScreenBrightness"):
		return _plugin.getScreenBrightness()
	return -1

func get_free_storage_mb() -> int:
	if _has("getFreeStorageMB"):
		return int(_plugin.getFreeStorageMB())
	return -1

func get_total_storage_mb() -> int:
	if _has("getTotalStorageMB"):
		return int(_plugin.getTotalStorageMB())
	return -1

# ── Bluetooth ────────────────────────────────────────────────────────────

func get_bluetooth_device_name() -> String:
	if _has("getBluetoothDeviceName"):
		return _plugin.getBluetoothDeviceName()
	return ""

func get_bluetooth_devices() -> Array:
	if _has("getBluetoothDevices"):
		return Array(_plugin.getBluetoothDevices())
	return []

# ── Шагомер ──────────────────────────────────────────────────────────────

func get_step_count() -> int:
	if _has("getStepCount"):
		return _plugin.getStepCount()
	return -1

# ── Уведомления / Accessibility ──────────────────────────────────────────

func get_recent_notifications() -> Array:
	if _has("getRecentNotifications"):
		return _plugin.getRecentNotifications()
	return []

func get_captured_texts() -> Array:
	if _has("getCapturedTexts"):
		return Array(_plugin.getCapturedTexts())
	return []

func get_last_delete_intent_app() -> String:
	if _has("getLastDeleteIntentApp"):
		return _plugin.getLastDeleteIntentApp()
	return ""

# ── Блокировка экрана ────────────────────────────────────────────────────

func lock_screen() -> void:
	if _has("lockScreen"):
		_plugin.lockScreen()

# ── Вспомогательные ──────────────────────────────────────────────────────

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
	_cached["bluetooth_device"] = get_bluetooth_device_name()
	_cached["ringer_mode"] = get_ringer_mode()
	_cached["charging"] = is_charging()
	_cached["free_storage_mb"] = get_free_storage_mb()
	_cached["step_count"] = get_step_count()
	_cached["missed_calls"] = get_missed_calls_count()
	_cached["call_count_today"] = get_call_count_today()
	_cached["foreground_app"] = get_current_foreground_app()
	_cached["delete_intent_app"] = get_last_delete_intent_app()
	MemorySystem.set_value("device_cache", _cached)
