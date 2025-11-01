@tool
extends WObject

@onready var comment_text: TextEdit = $MarginContainer/HBoxContainer/TextEdit

signal comment_clicked(blank_body, comment, index: int, button: int)

@export var comment_text_data: String = "Comment"

func _ready() -> void:
	comment_text.text = comment_text_data
	update_visual()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			comment_clicked.emit(blank_body, self, get_index(), event.button_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			comment_clicked.emit(blank_body, self, get_index(), event.button_index)

func _on_text_edit_text_changed() -> void:
	comment_text_data = comment_text.text
	update_visual()

func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"type": "comment",
		"text": comment_text_data
	}
	return data



func update_visual() -> void:
	"""Обновляет визуальное отображение комментария"""
	if comment_text and not comment_text.has_focus():
		comment_text.text = comment_text_data
