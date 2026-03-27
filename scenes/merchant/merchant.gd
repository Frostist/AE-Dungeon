extends Area2D

const API_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
const FALLBACK_ITEMS: Array = [
	{"name": "Steel Sword", "type": "steel_sword", "description": "Sharp reliable blade.", "gold_cost": 30},
	{"name": "Health Potion", "type": "health_potion", "description": "Restores 50 HP.", "gold_cost": 15},
	{"name": "Map Scroll", "type": "map_scroll", "description": "Reveals room ahead.", "gold_cost": 20},
]

var items: Array = []
var _http: HTTPRequest

signal shop_ready(items: Array)

func _ready() -> void:
	add_to_group("merchants")
	_http = HTTPRequest.new()
	_http.timeout = 6.0
	add_child(_http)
	_http.request_completed.connect(_on_response)
	_request_stock()

func _request_stock() -> void:
	var weapon_name: String = GameState.weapon.weapon_name if GameState.weapon else "Iron Sword"
	var prompt: String = (
		"Generate 3 shop items for a merchant on floor %d. " % GameState.floor_number +
		"Item types: weapon (iron_sword, steel_sword, war_axe, magic_staff), health_potion, map_scroll. " +
		"Each item: name, type, description (max 5 words), gold_cost (weapons 20-50g, potion 15g, scroll 20g). " +
		"Do not offer iron_sword (player has: %s). Return ONLY JSON: {\"items\":[...]}" % weapon_name
	)
	var body: Dictionary = {"contents": [{"role": "user", "parts": [{"text": prompt}]}]}
	var url: String = API_URL + "?key=" + ConfigLoader.gemini_api_key
	_http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_response(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var text: String = body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed.has("candidates"):
		items = FALLBACK_ITEMS
		shop_ready.emit(items)
		return
	var inner: String = parsed["candidates"][0]["content"]["parts"][0]["text"].strip_edges()
	var data = JSON.parse_string(inner)
	if data == null or not data.has("items"):
		items = FALLBACK_ITEMS
	else:
		items = data["items"]
	shop_ready.emit(items)
