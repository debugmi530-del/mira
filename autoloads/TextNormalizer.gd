extends Node

const MOM_PATTERNS = [
	"мам", "мамоч", "мамул", "мамуль", "мамаш", "матер", "мать", "мачех", "mom", "mama", "mum", "mother"
]
const DAD_PATTERNS = [
	"пап", "батен", "батян", "батяня", "бать", "отец", "отчи", "dad", "papa", "father", "батя"
]
const CLOSE_EMOJI = ["❤", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "💕", "💗", "💓", "💞", "💘", "😍", "🥰"]

const DELETE_TRIGGERS = [
	"удал", "снест", "убра", "избав", "uninstall", "remove", "удали",
	"как выйти", "марго", "мира", "приложен", "страшн", "помогите",
	"что это", "вирус", "взломал", "слежк"
]

func normalize_contact_name(raw_name: String) -> String:
	var lower = raw_name.to_lower().strip_edges()
	lower = _strip_emojis(lower)
	lower = _strip_extras(lower)

	if _matches_any(lower, MOM_PATTERNS):
		return "мама"
	if _matches_any(lower, DAD_PATTERNS):
		return "папа"
	return _extract_first_name(raw_name)

func _strip_emojis(text: String) -> String:
	var result = text
	for emoji in CLOSE_EMOJI:
		result = result.replace(emoji, "")
	return result.strip_edges()

func _strip_extras(text: String) -> String:
	var result = text
	for extra in ["(дом)", "(моб)", "(раб)", "(work)", "(home)", "(личный)", "мама", "папа"]:
		result = result.replace(extra, "")
	return result.strip_edges()

func _matches_any(text: String, patterns: Array) -> bool:
	for p in patterns:
		if text.begins_with(p) or text.contains(p):
			return true
	return false

func _extract_first_name(raw: String) -> String:
	var cleaned = _strip_emojis(raw.strip_edges())
	var parts = cleaned.split(" ")
	if parts.size() > 0 and parts[0].length() > 1:
		return parts[0]
	return cleaned

func categorize_contact(raw_name: String) -> String:
	var lower = raw_name.to_lower()
	if _matches_any(lower, MOM_PATTERNS):
		return "family_mom"
	if _matches_any(lower, DAD_PATTERNS):
		return "family_dad"
	if _has_emoji(raw_name):
		return "close_friend"
	if raw_name.split(" ").size() >= 3:
		return "formal"
	if raw_name.length() < 8 and not raw_name.contains(" "):
		return "friend"
	return "acquaintance"

func _has_emoji(text: String) -> bool:
	for emoji in CLOSE_EMOJI:
		if text.contains(emoji):
			return true
	return false

func check_browser_intent(text: String) -> String:
	var lower = text.to_lower()
	for trigger in DELETE_TRIGGERS:
		if lower.contains(trigger):
			return "delete_intent"
	if lower.contains("мира") or lower.contains("mira"):
		return "searched_mira"
	if lower.contains("страшн") or lower.contains("horror") or lower.contains("scary"):
		return "fear_search"
	return "none"

func decline_name(base: String, form: String) -> String:
	if base == "мама":
		match form:
			"gen": return "мамы"
			"dat": return "маме"
			"acc": return "маму"
			"ins": return "мамой"
			"pre": return "маме"
			_: return "мама"
	if base == "папа":
		match form:
			"gen": return "папы"
			"dat": return "папе"
			"acc": return "папу"
			"ins": return "папой"
			"pre": return "папе"
			_: return "папа"
	return base
