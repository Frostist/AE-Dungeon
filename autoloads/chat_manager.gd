extends Node

const API_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent"
const HISTORY_LIMIT: int = 10
const TYPING_SPEED: float = 40.0

signal response_ready(text: String)

var _history: Array = []
var _npc_name: String = ""
var _npc_type: String = ""
var _http: HTTPRequest

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_response)

func start_conversation(npc_name: String, npc_type: String) -> void:
	_npc_name = npc_name
	_npc_type = npc_type
	_history = []

func clear_history() -> void:
	_history = []

func send_message(player_message: String) -> void:
	_history.append({"role": "user", "parts": [{"text": player_message}]})
	if _history.size() > HISTORY_LIMIT * 2:
		_history = _history.slice(_history.size() - HISTORY_LIMIT * 2)

	var system_text: String = (
		"You are %s, a %s in a dungeon. Stay in character at all times. " % [_npc_name, _npc_type] +
		"You may hint at dangers ahead, offer trades, tell lore, or be hostile. " +
		"Keep every response under 3 sentences. Do not break character."
	)

	var body: Dictionary = {
		"systemInstruction": {"parts": [{"text": system_text}]},
		"contents": _history
	}
	var url: String = API_URL + "?key=" + ConfigLoader.gemini_api_key
	var headers: PackedStringArray = ["Content-Type: application/json"]
	_http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_response(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var text: String = body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed.has("candidates"):
		response_ready.emit("...")
		return
	var reply: String = parsed["candidates"][0]["content"]["parts"][0]["text"].strip_edges()
	_history.append({"role": "model", "parts": [{"text": reply}]})
	response_ready.emit(reply)
