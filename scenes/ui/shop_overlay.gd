extends CanvasLayer

@onready var gold_label: Label = $PanelContainer/VBoxContainer/HBoxContainer/GoldLabel
@onready var item_list: VBoxContainer = $PanelContainer/VBoxContainer/ItemList
@onready var merchant_line: Label = $PanelContainer/VBoxContainer/MerchantLine
@onready var chat_input: LineEdit = $PanelContainer/VBoxContainer/HBoxContainer2/ChatInput
@onready var chat_send: Button = $PanelContainer/VBoxContainer/HBoxContainer2/ChatSend

const WEAPON_MAP: Dictionary = {
	"iron_sword": "res://resources/weapons/iron_sword.tres",
	"steel_sword": "res://resources/weapons/steel_sword.tres",
	"war_axe": "res://resources/weapons/war_axe.tres",
	"magic_staff": "res://resources/weapons/magic_staff.tres",
}

signal closed

func _ready() -> void:
	$PanelContainer/VBoxContainer/HBoxContainer/CloseBtn.pressed.connect(
		func(): closed.emit(); hide())
	chat_send.pressed.connect(_on_chat_send)
	chat_input.text_submitted.connect(func(_t): _on_chat_send())
	ChatManager.response_ready.connect(_on_merchant_reply)
	hide()

func open_with_items(items: Array) -> void:
	gold_label.text = "💰 %dg" % GameState.gold
	for child in item_list.get_children():
		child.queue_free()
	for item in items:
		_add_item_row(item)
	merchant_line.text = '"Welcome, traveler."'
	ChatManager.start_conversation("The Merchant", "merchant")
	show()

func _add_item_row(item: Dictionary) -> void:
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "%s — %s" % [item["name"], item.get("description", "")]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buy_btn := Button.new()
	buy_btn.text = "%dg" % item.get("gold_cost", 0)
	buy_btn.pressed.connect(func(): _buy(item, buy_btn))
	row.add_child(name_lbl)
	row.add_child(buy_btn)
	item_list.add_child(row)

func _buy(item: Dictionary, btn: Button) -> void:
	var cost: int = item.get("gold_cost", 0)
	if GameState.gold < cost:
		merchant_line.text = '"You cannot afford that."'
		return
	GameState.gold -= cost
	gold_label.text = "💰 %dg" % GameState.gold
	btn.disabled = true
	match item["type"]:
		"health_potion":
			GameState.hp = min(GameState.hp + 50, GameState.max_hp)
		"map_scroll":
			var preview_room: int = GameState.room_number + 1
			var preview_floor: int = GameState.floor_number
			if preview_room > 5:
				preview_room = 1
				preview_floor += 1
			RoomGenerator.room_ready.connect(_on_preview_ready, CONNECT_ONE_SHOT)
			RoomGenerator.request_room(preview_floor, preview_room)
		_:
			if WEAPON_MAP.has(item["type"]):
				GameState.weapon = load(WEAPON_MAP[item["type"]])
	merchant_line.text = '"A fine choice."'

func _on_chat_send() -> void:
	var msg := chat_input.text.strip_edges()
	if msg.is_empty():
		return
	chat_input.text = ""
	ChatManager.send_message(msg)

func _on_merchant_reply(text: String) -> void:
	merchant_line.text = '"%s"' % text

func _on_preview_ready(grid_data: Dictionary) -> void:
	merchant_line.text = '"Ahead: %s — %s"' % [
		grid_data.get("room_type", "???").capitalize(),
		grid_data.get("description", "")
	]
