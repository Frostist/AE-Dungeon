extends CanvasLayer

@onready var npc_label: Label = $Panel/VBoxContainer/NPCNameLabel
@onready var msg_log: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/MessageLog
@onready var msg_input: LineEdit = $Panel/VBoxContainer/HBoxContainer/MessageInput
@onready var send_button: Button = $Panel/VBoxContainer/HBoxContainer/SendButton
@onready var close_button: Button = $CloseButton

var _typing_text: String = ""
var _typing_index: int = 0
var _typing_timer: float = 0.0
var _typing_label: Label = null

signal closed

func _ready() -> void:
	send_button.pressed.connect(_on_send)
	msg_input.text_submitted.connect(func(_t): _on_send())
	close_button.pressed.connect(func(): closed.emit(); hide())
	ChatManager.response_ready.connect(_on_response_ready)
	hide()

func open_for(npc_name: String, npc_type: String) -> void:
	npc_label.text = npc_name.to_upper()
	for child in msg_log.get_children():
		child.queue_free()
	_typing_text = ""
	_typing_index = 0
	_typing_label = null
	msg_input.text = ""
	ChatManager.start_conversation(npc_name, npc_type)
	show()

func _on_send() -> void:
	var msg := msg_input.text.strip_edges()
	if msg.is_empty():
		return
	_add_message(msg, Color.CORNFLOWER_BLUE)
	msg_input.text = ""
	send_button.disabled = true
	ChatManager.send_message(msg)

func _on_response_ready(text: String) -> void:
	if not visible:
		return
	send_button.disabled = false
	_start_typing(text)

func _start_typing(text: String) -> void:
	_typing_text = text
	_typing_index = 0
	_typing_timer = 0.0
	_typing_label = Label.new()
	_typing_label.text = ""
	_typing_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_log.add_child(_typing_label)

func _process(delta: float) -> void:
	if _typing_label == null or _typing_index >= _typing_text.length():
		return
	_typing_timer += delta
	var chars_per_second: float = ChatManager.TYPING_SPEED
	var chars_to_add: int = int(_typing_timer * chars_per_second)
	if chars_to_add > 0:
		_typing_timer -= chars_to_add / chars_per_second
		_typing_index = min(_typing_index + chars_to_add, _typing_text.length())
		_typing_label.text = _typing_text.substr(0, _typing_index)
	if _typing_index >= _typing_text.length():
		_typing_label = null

func _add_message(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_log.add_child(lbl)
