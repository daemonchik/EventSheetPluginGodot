@tool
extends WObject

@onready var icon_texture: TextureRect = $MarginContainer/HBoxContainer/Icon
@onready var group_label: Label = $MarginContainer/HBoxContainer/HSplitContainer/Name
@onready var action_label: Label = $MarginContainer/HBoxContainer/HSplitContainer/Action
@onready var enabled_indicator: ColorRect = $MarginContainer/HBoxContainer/EnabledIndicator

signal action_clicked(blank_body, action, index: int, button: int)
@export var action_resource: WAction

func _ready() -> void:
	init_object(action_resource, icon_texture, group_label, action_label)
	update_visual()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			# Начинаем drag при нажатии левой кнопки
			var drag_data = {"type": "action", "element": self, "blank_body": blank_body}
			force_drag(drag_data, _create_drag_preview())
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			# Обрабатываем клик только при отпускании кнопки
			action_clicked.emit(blank_body, self, get_index(), event.button_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			action_clicked.emit(blank_body, self, get_index(), event.button_index)

func _create_drag_preview() -> Control:
	"""Создает превью для drag and drop"""
	var preview = ColorRect.new()
	preview.size = Vector2(200, 30)
	preview.color = Color(0.3, 0.6, 1.0, 0.5)

	var label = Label.new()
	label.text = action_resource.title if action_resource else "Action"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = preview.size
	preview.add_child(label)

	return preview



func _on_h_split_container_dragged(offset: int) -> void:
	for split: HSplitContainer in get_tree().get_nodes_in_group("action_split"):
		split.split_offset = offset

func get_save_data() -> Dictionary:
	var data: Dictionary = _save(action_resource)
	return data

func update_visual() -> void:
	"""Обновляет визуальное отображение элемента"""
	if enabled_indicator and action_resource:
		if action_resource.enabled:
			enabled_indicator.color = Color(0.2, 0.8, 0.2, 0.3)  # Зеленый для включенного
		else:
			enabled_indicator.color = Color(0.8, 0.2, 0.2, 0.3)  # Красный для отключенного

	# Обновляем текст с параметрами
	if action_resource and action_resource.parameters.size() > 0:
		init_object(action_resource, icon_texture, group_label, action_label)
