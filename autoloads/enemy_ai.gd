extends Node

const API_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent"
const POLL_INTERVAL: float = 3.0
const TIMEOUT: float = 4.0

var _active_enemies: Array = []
var _poll_index: int = 0
var _timer: float = 0.0
var _request_in_flight: bool = false
var _http: HTTPRequest
var _current_enemy: CharacterBody2D = null

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_response)

func register_enemies(enemies: Array) -> void:
	_active_enemies = enemies
	_poll_index = 0

func clear_queue() -> void:
	_active_enemies = []
	_poll_index = 0
	_request_in_flight = false
	_current_enemy = null

func _process(delta: float) -> void:
	if _active_enemies.is_empty() or _request_in_flight:
		return
	_timer += delta
	if _timer < POLL_INTERVAL:
		return
	_timer = 0.0
	_active_enemies = _active_enemies.filter(func(e): return is_instance_valid(e))
	if _active_enemies.is_empty():
		return
	_poll_index = _poll_index % _active_enemies.size()
	_poll_enemy(_active_enemies[_poll_index])
	_poll_index += 1

func _poll_enemy(enemy: CharacterBody2D) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	_current_enemy = enemy
	var dist: float = enemy.global_position.distance_to(player.global_position) / 32.0

	var is_boss: bool = enemy.enemy_type == "boss"
	var action_options: String = "attack | taunt | charge" if is_boss else "attack | patrol | flee"
	var prompt: String
	if is_boss:
		prompt = (
			"You are a powerful dungeon boss on floor %d. HP: %d/%d. " % [GameState.floor_number, enemy.hp, enemy.max_hp] +
			"Player HP: %d. Player distance: %.1f tiles. Current behavior: %s. " % [GameState.hp, dist, enemy.behavior] +
			"Be aggressive and unpredictable. Use taunt to power up your next attack, charge to close distance fast. " +
			"Return ONLY JSON: { \"action\": \"%s\" }" % action_options
		)
	else:
		prompt = (
			"Enemy: %s. HP: %d/%d. Player distance: %.1f tiles. " % [
				enemy.enemy_type, enemy.hp, enemy.max_hp, dist] +
			"Player HP: %d. Current behavior: %s. " % [GameState.hp, enemy.behavior] +
			"Return ONLY JSON: { \"action\": \"%s\" }" % action_options
		)

	var body: Dictionary = {
		"contents": [{"role": "user", "parts": [{"text": prompt}]}]
	}
	var url: String = API_URL + "?key=" + ConfigLoader.gemini_api_key
	var headers: PackedStringArray = ["Content-Type: application/json"]
	_request_in_flight = true
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_request_in_flight = false

func _on_response(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_in_flight = false
	if not is_instance_valid(_current_enemy):
		return
	var text: String = body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed.has("candidates"):
		return
	var inner: String = parsed["candidates"][0]["content"]["parts"][0]["text"]
	
	# Strip markdown code fences if present
	var cleaned_text = inner.strip_edges()
	if cleaned_text.begins_with("```"):
		var first_newline = cleaned_text.find("\n")
		if first_newline > 0:
			cleaned_text = cleaned_text.substr(first_newline + 1)
		if cleaned_text.ends_with("```"):
			cleaned_text = cleaned_text.substr(0, cleaned_text.length() - 3)
		cleaned_text = cleaned_text.strip_edges()
	
	var action_data = JSON.parse_string(cleaned_text)
	if action_data == null or not action_data.has("action"):
		return
	_current_enemy.behavior = action_data["action"]
