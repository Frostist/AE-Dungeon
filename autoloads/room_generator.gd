extends Node

signal room_ready(grid_data: Dictionary)

const API_URL: String = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent"
const TIMEOUT: float = 8.0

var _http: HTTPRequest

const FALLBACK_GRID: Dictionary = {
	"grid": [
		["empty","empty","empty","empty","empty","empty"],
		["empty","empty","empty","empty","empty","empty"],
		["empty","empty","empty","empty","empty","empty"],
		["empty","empty","chest","empty","empty","empty"],
		["empty","empty","empty","empty","empty","empty"],
		["empty","empty","empty","empty","empty","empty"],
		["empty","empty","empty","empty","empty","empty"],
		["empty","empty","empty","empty","empty","empty"],
	],
	"description": "A quiet chamber.",
	"room_type": "treasure"
}

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_response)

func request_room(floor_num: int, room_num: int) -> void:
	var is_boss_room: bool = floor_num % 5 == 0 and room_num == 5
	print("\n=== AI ROOM GENERATION REQUEST ===")
	print("Floor: ", floor_num, " | Room: ", room_num, " | Boss Room: ", is_boss_room)
	
	var prompt: String = (
		"Generate room %d of 5 on floor %d. " % [room_num, floor_num] +
		"Grid: 6 columns × 8 rows. grid[row][col] — grid[0] is the top row. " +
		"Valid cell values: empty, enemy:goblin, enemy:skeleton, enemy:orc, chest, merchant, trap, " +
		("boss (this IS a boss room). " if is_boss_room else "boss (NOT a boss room — do not use boss). ") +
		"Rules: max 3 enemies per room. Boss rooms: boss + 1 optional chest, no other enemies. " +
		"Merchant rooms: 1 merchant, no enemies. grid[0][2] and grid[7][2] must be empty (doors). " +
		"Respond with JSON only, no markdown."
	)
	print("Prompt sent to AI: ", prompt)

	var body: Dictionary = {
		"contents": [{"role": "user", "parts": [{"text": prompt}]}],
		"systemInstruction": {"parts": [{"text":
			"You are a dungeon master for a pixel roguelike. Generate varied rooms. " +
			"Increase difficulty with floor number. Return ONLY valid JSON, no commentary, no code fences."
		}]}
	}

	var url: String = API_URL + "?key=" + ConfigLoader.gemini_api_key
	var headers: PackedStringArray = ["Content-Type: application/json"]
	print("Sending HTTP request to Gemini API...")
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		print("ERROR: HTTP request failed with error code: ", err)
		push_warning("RoomGenerator: request failed, using fallback")
		room_ready.emit(_validated(FALLBACK_GRID))
	else:
		print("HTTP request sent successfully, waiting for response...")

func _on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("\n=== HTTP RESPONSE RECEIVED ===")
	print("Result code: ", result, " (0=SUCCESS)")
	print("HTTP status: ", response_code)
	print("Body length: ", body.size(), " bytes")
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("ERROR: HTTP request failed with result: ", result)
		push_warning("RoomGenerator: HTTP error %d, using fallback" % result)
		room_ready.emit(_validated(FALLBACK_GRID))
		return

	var text: String = body.get_string_from_utf8()
	print("Response preview (first 500 chars): ", text.substr(0, 500))
	
	var parsed = JSON.parse_string(text)
	if parsed == null:
		print("ERROR: Failed to parse outer JSON response")
		push_warning("RoomGenerator: outer JSON parse failed")
		room_ready.emit(_validated(FALLBACK_GRID))
		return

	var inner_text: String = ""
	if parsed.has("candidates"):
		inner_text = parsed["candidates"][0]["content"]["parts"][0]["text"]
	else:
		push_warning("RoomGenerator: unexpected response shape")
		room_ready.emit(_validated(FALLBACK_GRID))
		return

	print("\n=== RAW AI RESPONSE ===")
	print(inner_text)
	print("======================\n")
	
	# Strip markdown code fences if present
	var cleaned_text = inner_text.strip_edges()
	if cleaned_text.begins_with("```"):
		# Remove opening fence (```json or ```)
		var first_newline = cleaned_text.find("\n")
		if first_newline > 0:
			cleaned_text = cleaned_text.substr(first_newline + 1)
		# Remove closing fence
		if cleaned_text.ends_with("```"):
			cleaned_text = cleaned_text.substr(0, cleaned_text.length() - 3)
		cleaned_text = cleaned_text.strip_edges()
	
	var grid_data = JSON.parse_string(cleaned_text)
	if grid_data == null or not grid_data.has("grid"):
		push_warning("RoomGenerator: grid JSON parse failed")
		print("Failed to parse: ", cleaned_text)
		room_ready.emit(_validated(FALLBACK_GRID))
		return

	print("AI Response received:")
	print("  Description: ", grid_data.get("description", "N/A"))
	print("  Room Type: ", grid_data.get("room_type", "N/A"))
	_print_grid(grid_data.get("grid", []))
	room_ready.emit(_validated(grid_data))

func _print_grid(grid: Array) -> void:
	print("  Grid layout:")
	for row_idx in grid.size():
		var row_str = "    Row %d: " % row_idx
		for cell in grid[row_idx]:
			var cell_str = str(cell)
			if cell_str == "empty":
				row_str += "[ . ]"
			elif cell_str.begins_with("enemy:"):
				row_str += "[E:%s]" % cell_str.substr(6, 1).to_upper()
			elif cell_str == "chest":
				row_str += "[CHT]"
			elif cell_str == "merchant":
				row_str += "[MER]"
			elif cell_str == "trap":
				row_str += "[TRP]"
			elif cell_str == "boss":
				row_str += "[BSS]"
			else:
				row_str += "[???]"
		print(row_str)

func _validated(data: Dictionary) -> Dictionary:
	data = data.duplicate(true)
	var grid: Array = data.get("grid", [])
	while grid.size() < 8:
		grid.append(["empty","empty","empty","empty","empty","empty"])
	grid = grid.slice(0, 8)
	var valid_tokens: Array = ["empty","enemy:goblin","enemy:skeleton","enemy:orc",
							   "chest","merchant","trap","boss"]
	var floor_num: int = GameState.floor_number
	var room_num: int = GameState.room_number
	for r in 8:
		var row: Array = grid[r]
		while row.size() < 6:
			row.append("empty")
		row = row.slice(0, 6)
		for c in 6:
			if not (row[c] in valid_tokens):
				push_warning("RoomGenerator: unknown token '%s' → empty" % row[c])
				row[c] = "empty"
			if row[c] == "boss" and not (floor_num % 5 == 0 and room_num == 5):
				push_warning("RoomGenerator: boss token in non-boss room → orc")
				row[c] = "enemy:orc"
		grid[r] = row
	grid[0][2] = "empty"
	grid[7][2] = "empty"
	data["grid"] = grid
	return data
