@tool
extends MarginContainer

@onready var hSplitContainer: HSplitContainer = $HSplitContainer
@onready var blank_body_tree: VBoxContainer = $HSplitContainer/Event/VBoxContainer
@onready var actions_tree: VBoxContainer = $HSplitContainer/Action/VBoxContainer
@onready var selected_panel: Panel = $Selected

signal add_action_button(blank_body)
signal bb_popup_button(blank_body, index: int, button: int)

var last_y_size: int = 0
var events: Array
var actions: Array
var comments: Array

func _ready() -> void:
	last_y_size = hSplitContainer.size.y

func _process(delta: float) -> void:
	if last_y_size != hSplitContainer.size.y:
		custom_minimum_size.y = hSplitContainer.size.y
		size.y = hSplitContainer.size.y
		last_y_size = hSplitContainer.size.y

func set_selected(selected: bool):
	selected_panel.visible = selected

func _on_add_action_button_up() -> void:
	add_action_button.emit(self)

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and (event.button_index == MOUSE_BUTTON_LEFT \
			or event.button_index == MOUSE_BUTTON_RIGHT) \
			and event.is_pressed():
		bb_popup_button.emit(self, get_index(), event.button_index)

func _on_h_split_container_dragged(offset: int) -> void:
	for split: HSplitContainer in get_tree().get_nodes_in_group("blank_body_split"):
		split.split_offset = offset

func _can_drop_data(at_position: Vector2, data) -> bool:
	"""Проверяет, можно ли сбросить данные в этот блок"""
	if data is Dictionary:
		var data_type = data.get("type")
		if data_type == "event" or data_type == "action" or data_type == "comment":
			return true
	return false

func _drop_data(at_position: Vector2, data) -> void:
	"""Обрабатывает сброс данных в блок"""
	if data is Dictionary:
		var data_type = data.get("type")
		var element = data.get("element")
		var source_blank_body = data.get("blank_body")

		if element and source_blank_body:
			# Определяем, в какой контейнер сбрасываем
			var target_container = _get_target_container(at_position)

			if source_blank_body == self:
				# Переупорядочивание внутри того же блока
				if target_container:
					var drop_index = _get_drop_index(target_container, at_position)
					_reorder_within_container(target_container, element, drop_index)
			else:
				# Перемещение между разными блоками
				if data_type == "event":
					_move_event_to_this_blank_body(element, source_blank_body)
				elif data_type == "action":
					_move_action_to_this_blank_body(element, source_blank_body)
				elif data_type == "comment":
					_move_comment_to_this_blank_body(element, source_blank_body)

func _move_event_to_this_blank_body(event_element, source_body) -> void:
	"""Перемещает событие в этот блок"""
	if source_body == self:
		return

	# Удаляем из старого блока
	source_body.events.erase(event_element)
	source_body.blank_body_tree.remove_child(event_element)

	# Добавляем в этот блок
	events.append(event_element)
	blank_body_tree.add_child(event_element)
	event_element.blank_body = self

	# Сохраняем изменения
	if Engine.is_editor_hint():
		var editor_interface = EditorInterface
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()

func _move_action_to_this_blank_body(action_element, source_body) -> void:
	"""Перемещает действие в этот блок"""
	if source_body == self:
		return

	# Удаляем из старого блока
	source_body.actions.erase(action_element)
	source_body.actions_tree.remove_child(action_element)

	# Добавляем в новый блок
	actions.append(action_element)
	actions_tree.add_child(action_element)
	actions_tree.move_child(action_element, actions_tree.get_child_count() - 2)
	action_element.blank_body = self

	# Сохраняем изменения
	if Engine.is_editor_hint():
		var editor_interface = EditorInterface
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()

func _move_comment_to_this_blank_body(comment_element, source_body) -> void:
	"""Перемещает комментарий в этот блок"""
	if source_body == self:
		return

	# Удаляем из старого блока
	source_body.comments.erase(comment_element)
	source_body.blank_body_tree.remove_child(comment_element)

	# Добавляем в новый блок
	comments.append(comment_element)
	blank_body_tree.add_child(comment_element)
	blank_body_tree.move_child(comment_element, blank_body_tree.get_child_count() - 2)
	comment_element.blank_body = self

	# Сохраняем изменения
	if Engine.is_editor_hint():
		var editor_interface = EditorInterface
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()

func _get_target_container(at_position: Vector2) -> VBoxContainer:
	"""Определяет целевой контейнер для сброса на основе позиции"""
	var local_pos = at_position - global_position

	# Проверяем, находится ли позиция в области событий/комментариев
	var event_container_rect = Rect2(
		blank_body_tree.global_position - global_position,
		blank_body_tree.size
	)
	if event_container_rect.has_point(local_pos):
		return blank_body_tree

	# Проверяем, находится ли позиция в области действий
	var action_container_rect = Rect2(
		actions_tree.global_position - global_position,
		actions_tree.size
	)
	if action_container_rect.has_point(local_pos):
		return actions_tree

	return null

func _get_drop_index(container: VBoxContainer, at_position: Vector2) -> int:
	"""Определяет индекс для вставки элемента в контейнер"""
	var drop_index = 0
	for i in range(container.get_child_count()):
		var child = container.get_child(i)
		if child is Control:
			var child_rect = Rect2(child.global_position, child.size)
			if at_position.y < child_rect.get_center().y:
				break
		drop_index = i + 1
	return drop_index

func _reorder_within_container(container: VBoxContainer, element, new_index: int) -> void:
	"""Переупорядочивает элемент внутри контейнера"""
	var current_index = element.get_index()
	if current_index != new_index and new_index >= 0 and new_index <= container.get_child_count():
		container.move_child(element, new_index)
		# Обновляем массивы в зависимости от типа контейнера
		if container == blank_body_tree:
			# Для событий и комментариев
			if element in events:
				events.erase(element)
				events.insert(min(new_index, events.size()), element)
			elif element in comments:
				comments.erase(element)
				comments.insert(min(new_index, comments.size()), element)
		elif container == actions_tree:
			# Для действий
			if element in actions:
				actions.erase(element)
				actions.insert(min(new_index, actions.size()), element)

func _save() -> Dictionary:
	var events_data: Dictionary = {}
	var actions_data: Dictionary = {}
	var comments_data: Dictionary = {}

	for i in events.size():
		var event = events[i]
		events_data[i] = event.get_save_data()

	for i in actions.size():
		var action = actions[i]
		actions_data[i] = action.get_save_data()

	for i in comments.size():
		var comment = comments[i]
		comments_data[i] = comment.get_save_data()

	var data: Dictionary = {
		"events": events_data,
		"actions": actions_data,
		"comments": comments_data,
	}

	return data
