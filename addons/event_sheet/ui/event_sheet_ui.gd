@tool
extends Control

class_name EventSheetUI

## Ссылки на элементы UI
var events_list: ItemList
var conditions_tree: Tree
var actions_tree: Tree
var add_event_button: Button
var add_sub_event_button: Button
var add_group_button: Button
var delete_button: Button
var duplicate_button: Button
var add_condition_button: Button
var add_action_button: Button
var search_field: LineEdit

## Текущий загруженный контейнер событий
var current_container: EventSheetData.EventSheet = null

## Текущее выбранное событие
var current_event: EventSheetData.Event = null

## Путь к текущему JSON файлу
var current_json_path: String = ""

## Система Undo/Redo
var undo_redo: EventSheetUndoRedo = null

## Флаг для отладки
var debug_mode: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	
	_find_ui_nodes()
	_find_search_field()
	
	if conditions_tree == null or actions_tree == null or events_list == null:
		push_error("EventSheetUI: Не удалось найти все необходимые узлы!")
		return
	
	# Инициализируем Undo/Redo
	undo_redo = EventSheetUndoRedo.new()
	
	# Подключаем сигналы кнопок
	if add_event_button:
		add_event_button.pressed.connect(_on_add_event_pressed)
	if add_sub_event_button:
		add_sub_event_button.pressed.connect(_on_add_sub_event_pressed)
	if add_group_button:
		add_group_button.pressed.connect(_on_add_group_pressed)
	if delete_button:
		delete_button.pressed.connect(_on_delete_pressed)
	if duplicate_button:
		duplicate_button.pressed.connect(_on_duplicate_pressed)
	
	if add_condition_button:
		add_condition_button.pressed.connect(_on_add_condition_button_pressed)
	if add_action_button:
		add_action_button.pressed.connect(_on_add_action_button_pressed)
	
	# Подключаем сигналы деревьев
	conditions_tree.item_selected.connect(_on_conditions_tree_item_selected)
	actions_tree.item_selected.connect(_on_actions_tree_item_selected)
	conditions_tree.item_activated.connect(_on_conditions_tree_item_activated)
	actions_tree.item_activated.connect(_on_actions_tree_item_activated)
	
	conditions_tree.gui_input.connect(_on_conditions_tree_gui_input)
	actions_tree.gui_input.connect(_on_actions_tree_gui_input)
	events_list.item_activated.connect(_on_events_list_item_double_clicked)
	
	conditions_tree.empty_clicked.connect(_on_conditions_tree_empty_clicked)
	actions_tree.empty_clicked.connect(_on_actions_tree_empty_clicked)
	
	# Подключаем сигнал списка событий
	events_list.item_selected.connect(_on_events_list_item_selected)
	
	if debug_mode:
		print("EventSheetUI инициализирован!")


## Найти все узлы UI
func _find_ui_nodes() -> void:
	events_list = find_child("EventsList", true, false)
	conditions_tree = find_child("ConditionsTree", true, false)
	actions_tree = find_child("ActionsTree", true, false)
	
	add_event_button = find_child("AddEventButton", true, false)
	add_sub_event_button = find_child("AddSubEventButton", true, false)
	add_group_button = find_child("AddGroupButton", true, false)
	delete_button = find_child("DeleteButton", true, false)
	duplicate_button = find_child("DuplicateButton", true, false)
	
	add_condition_button = find_child("AddConditionButton", true, false)
	add_action_button = find_child("AddActionButton", true, false)


## Найти поле поиска
func _find_search_field() -> void:
	search_field = find_child("SearchField", true, false)
	if search_field:
		search_field.text_changed.connect(_on_search_field_changed)
		var clear_button = find_child("ClearButton", true, false)
		if clear_button:
			clear_button.pressed.connect(func():
				search_field.clear()
				_refresh_events_list()
			)


## Загружает JSON файл
func load_json(file_path: String) -> void:
	current_json_path = file_path
	current_container = EventSheetData.FileManager.load_from_file(file_path)
	
	if current_container == null:
		_show_error("Не удалось загрузить: %s" % file_path)
		return
	
	# Инициализируем историю
	undo_redo.save_state(current_container)
	
	_refresh_events_list()
	
	# Загружаем первое событие
	if current_container.events.size() > 0:
		events_list.select(0)
		_on_events_list_item_selected(0)
	
	if debug_mode:
		print("JSON загружен: %s" % file_path)


## Обновляет список всех событий
func _refresh_events_list() -> void:
	if events_list == null or current_container == null:
		return
	
	events_list.clear()
	
	for i in range(current_container.events.size()):
		var event = current_container.events[i]
		var text = "[%d] %s" % [i + 1, event.event_name]
		
		if not event.enabled:
			text = "[OFF] " + text
		
		events_list.add_item(text)


## Обновить список событий с фильтром поиска
func _refresh_filtered_events_list(search_text: String) -> void:
	if events_list == null or current_container == null:
		return
	
	events_list.clear()
	
	var search_lower = search_text.to_lower()
	
	for i in range(current_container.events.size()):
		var event = current_container.events[i]
		
		# Проверяем совпадает ли имя с поиском
		if search_text.is_empty() or event.event_name.to_lower().contains(search_lower):
			var text = "[%d] %s" % [i + 1, event.event_name]
			
			if not event.enabled:
				text = "[OFF] " + text
			
			events_list.add_item(text)


## Обновляет дерево условий
func _refresh_conditions_tree() -> void:
	if conditions_tree == null:
		return
		
	conditions_tree.clear()
	
	if current_event == null:
		return
	
	var root = conditions_tree.create_item()
	root.set_text(0, "Conditions (%d)" % current_event.conditions.size())
	root.set_custom_color(0, Color.LIGHT_GRAY)
	
	for i in range(current_event.conditions.size()):
		var condition = current_event.conditions[i]
		var item = conditions_tree.create_item(root)
		item.set_text(0, condition.get_display_text())
		item.set_metadata(0, i)
		
		if condition.inverted:
			item.set_custom_color(0, Color.SALMON)


## Обновляет дерево действий
func _refresh_actions_tree() -> void:
	if actions_tree == null:
		return
		
	actions_tree.clear()
	
	if current_event == null:
		return
	
	var root = actions_tree.create_item()
	root.set_text(0, "Actions (%d)" % current_event.actions.size())
	root.set_custom_color(0, Color.LIGHT_GRAY)
	
	for i in range(current_event.actions.size()):
		var action = current_event.actions[i]
		var item = actions_tree.create_item(root)
		item.set_text(0, action.get_display_text())
		item.set_metadata(0, i)


# ============ ОБРАБОТЧИКИ СПИСКА СОБЫТИЙ ============

func _on_events_list_item_selected(index: int) -> void:
	if current_container == null or index >= current_container.events.size():
		return
	
	current_event = current_container.events[index]
	_refresh_conditions_tree()
	_refresh_actions_tree()
	
	if debug_mode:
		print("Выбрано событие: %d (%s)" % [index, current_event.event_name])


func _on_events_list_item_double_clicked(index: int) -> void:
	if current_container == null or index >= current_container.events.size():
		return
	
	var event = current_container.events[index]
	_show_rename_dialog(event)


# ============ ОБРАБОТЧИКИ КНОПОК ============

func _on_add_event_pressed() -> void:
	if current_container == null:
		_show_error("Контейнер событий не загружен")
		return
	
	_save_to_history()
	
	var new_event = EventSheetData.Event.new()
	new_event.event_name = "New Event"
	current_container.add_event(new_event)
	
	_refresh_events_list()
	events_list.select(current_container.events.size() - 1)
	_on_events_list_item_selected(current_container.events.size() - 1)
	_save_json()


func _on_add_sub_event_pressed() -> void:
	if current_event == null:
		_show_error("Выберите событие")
		return
	
	_save_to_history()
	
	var sub_event = EventSheetData.Event.new()
	sub_event.event_name = "Sub Event"
	current_event.sub_events.append(sub_event)
	_save_json()


func _on_add_group_pressed() -> void:
	if current_container == null:
		_show_error("Контейнер событий не загружен")
		return
	
	_save_to_history()
	
	var group_event = EventSheetData.Event.new()
	group_event.event_name = "--- GROUP ---"
	current_container.add_event(group_event)
	
	_refresh_events_list()
	_save_json()


func _on_delete_pressed() -> void:
	if current_event == null or current_container == null:
		return
	
	_save_to_history()
	
	var index = current_container.events.find(current_event)
	if index != -1:
		current_container.remove_event(index)
		current_event = null
		
		_refresh_events_list()
		_refresh_conditions_tree()
		_refresh_actions_tree()
		_save_json()


func _on_duplicate_pressed() -> void:
	if current_event == null or current_container == null:
		return
	
	_save_to_history()
	
	var duplicated_event = EventSheetData.Event.new()
	duplicated_event.event_name = current_event.event_name + " (copy)"
	duplicated_event.comment = current_event.comment
	duplicated_event.enabled = current_event.enabled
	
	for condition in current_event.conditions:
		var new_condition = EventSheetData.Condition.new()
		new_condition.condition_name = condition.condition_name
		new_condition.target_object = condition.target_object
		new_condition.parameters = condition.parameters.duplicate()
		new_condition.inverted = condition.inverted
		duplicated_event.conditions.append(new_condition)
	
	for action in current_event.actions:
		var new_action = EventSheetData.Action.new()
		new_action.action_name = action.action_name
		new_action.target_object = action.target_object
		new_action.parameters = action.parameters.duplicate()
		duplicated_event.actions.append(new_action)
	
	var index = current_container.events.find(current_event)
	if index != -1:
		current_container.insert_event(index + 1, duplicated_event)
		_refresh_events_list()
		events_list.select(index + 1)
		_on_events_list_item_selected(index + 1)
		_save_json()


func _on_add_condition_button_pressed() -> void:
	_show_condition_selector()


func _on_add_action_button_pressed() -> void:
	_show_action_selector()


# ============ ОБРАБОТЧИКИ ДЕРЕВЬЕВ ============

func _on_conditions_tree_item_selected() -> void:
	var selected = conditions_tree.get_selected()
	if selected:
		var index = selected.get_metadata(0)
		if index != null and current_event != null and index < current_event.conditions.size():
			if debug_mode:
				print("Выбрано условие: %d" % index)


func _on_actions_tree_item_selected() -> void:
	var selected = actions_tree.get_selected()
	if selected:
		var index = selected.get_metadata(0)
		if index != null and current_event != null and index < current_event.actions.size():
			if debug_mode:
				print("Выбрано действие: %d" % index)


func _on_conditions_tree_item_activated() -> void:
	var selected = conditions_tree.get_selected()
	if selected:
		var index = selected.get_metadata(0)
		if index != null and current_event != null and index < current_event.conditions.size():
			_show_condition_params_dialog(current_event.conditions[index])


func _on_actions_tree_item_activated() -> void:
	var selected = actions_tree.get_selected()
	if selected:
		var index = selected.get_metadata(0)
		if index != null and current_event != null and index < current_event.actions.size():
			_show_action_params_dialog(current_event.actions[index])


# ============ КОНТЕКСТНОЕ МЕНЮ ============

func _on_conditions_tree_empty_clicked(position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	_show_condition_selector()


func _on_actions_tree_empty_clicked(position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	_show_action_selector()


## Обработчик GUI ввода для дерева условий
func _on_conditions_tree_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	
	var mouse_event = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return
	
	var item = conditions_tree.get_item_at_position(mouse_event.position)
	if item == null or current_event == null:
		return
	
	var index = item.get_metadata(0)
	if index == null or index >= current_event.conditions.size():
		return
	
	var condition = current_event.conditions[index]
	
	var menu = PopupMenu.new()
	add_child(menu)
	
	menu.add_item("Инвертировать (NOT)", 0)
	menu.add_separator()
	menu.add_item("Удалить", 1)
	menu.add_item("Дублировать", 2)
	
	menu.id_pressed.connect(func(id: int):
		_save_to_history()
		
		match id:
			0:
				condition.inverted = !condition.inverted
				_refresh_conditions_tree()
				_save_json()
			1:
				current_event.conditions.remove_at(index)
				_refresh_conditions_tree()
				_save_json()
			2:
				var new_condition = EventSheetData.Condition.new()
				new_condition.condition_name = condition.condition_name
				new_condition.target_object = condition.target_object
				new_condition.parameters = condition.parameters.duplicate()
				new_condition.inverted = condition.inverted
				current_event.conditions.insert(index + 1, new_condition)
				_refresh_conditions_tree()
				_save_json()
		menu.queue_free()
	)
	
	menu.popup_centered()


## Обработчик GUI ввода для дерева действий
func _on_actions_tree_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	
	var mouse_event = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return
	
	var item = actions_tree.get_item_at_position(mouse_event.position)
	if item == null or current_event == null:
		return
	
	var index = item.get_metadata(0)
	if index == null or index >= current_event.actions.size():
		return
	
	var action = current_event.actions[index]
	
	var menu = PopupMenu.new()
	add_child(menu)
	
	menu.add_item("Удалить", 0)
	menu.add_item("Дублировать", 1)
	menu.add_item("Переместить вверх", 2)
	menu.add_item("Переместить вниз", 3)
	
	menu.id_pressed.connect(func(id: int):
		_save_to_history()
		
		match id:
			0:
				current_event.actions.remove_at(index)
				_refresh_actions_tree()
				_save_json()
			1:
				var new_action = EventSheetData.Action.new()
				new_action.action_name = action.action_name
				new_action.target_object = action.target_object
				new_action.parameters = action.parameters.duplicate()
				current_event.actions.insert(index + 1, new_action)
				_refresh_actions_tree()
				_save_json()
			2:
				if index > 0:
					var temp = current_event.actions[index]
					current_event.actions[index] = current_event.actions[index - 1]
					current_event.actions[index - 1] = temp
					_refresh_actions_tree()
					_save_json()
			3:
				if index < current_event.actions.size() - 1:
					var temp = current_event.actions[index]
					current_event.actions[index] = current_event.actions[index + 1]
					current_event.actions[index + 1] = temp
					_refresh_actions_tree()
					_save_json()
		menu.queue_free()
	)
	
	menu.popup_centered()


# ============ ВЫБОР УСЛОВИЙ И ДЕЙСТВИЙ ============

func _show_condition_selector() -> void:
	if current_event == null:
		_show_error("Выберите событие")
		return
	
	var menu = PopupMenu.new()
	add_child(menu)
	
	menu.add_item("System > Start of layout", hash("Start of layout"))
	menu.add_item("System > Every tick", hash("Every tick"))
	menu.add_item("System > Compare variable", hash("Compare variable"))
	menu.add_separator()
	menu.add_item("Input > Key pressed", hash("Key pressed"))
	menu.add_item("Input > Mouse button down", hash("Mouse button down"))
	menu.add_separator()
	menu.add_item("Object > Is on floor", hash("Is on floor"))
	menu.add_item("Object > On collision", hash("On collision"))
	
	menu.id_pressed.connect(func(id: int):
		var conditions_map = {
			hash("Start of layout"): "Start of layout",
			hash("Every tick"): "Every tick",
			hash("Compare variable"): "Compare variable",
			hash("Key pressed"): "Key pressed",
			hash("Mouse button down"): "Mouse button down",
			hash("Is on floor"): "Is on floor",
			hash("On collision"): "On collision",
		}
		
		if id in conditions_map:
			_save_to_history()
			
			var new_condition = EventSheetData.Condition.new()
			new_condition.condition_name = conditions_map[id]
			current_event.conditions.append(new_condition)
			_refresh_conditions_tree()
			_save_json()
			menu.queue_free()
	)
	
	menu.popup_centered()


func _show_action_selector() -> void:
	if current_event == null:
		_show_error("Выберите событие")
		return
	
	var menu = PopupMenu.new()
	add_child(menu)
	
	menu.add_item("System > Set variable", hash("Set variable"))
	menu.add_item("System > Wait", hash("Wait"))
	menu.add_separator()
	menu.add_item("Object > Create object", hash("Create object"))
	menu.add_item("Object > Destroy", hash("Destroy"))
	menu.add_item("Object > Set position", hash("Set position"))
	menu.add_item("Object > Move at angle", hash("Move at angle"))
	menu.add_separator()
	menu.add_item("Audio > Play sound", hash("Play sound"))
	
	menu.id_pressed.connect(func(id: int):
		var actions_map = {
			hash("Set variable"): "Set variable",
			hash("Wait"): "Wait",
			hash("Create object"): "Create object",
			hash("Destroy"): "Destroy",
			hash("Set position"): "Set position",
			hash("Move at angle"): "Move at angle",
			hash("Play sound"): "Play sound",
		}
		
		if id in actions_map:
			_save_to_history()
			
			var new_action = EventSheetData.Action.new()
			new_action.action_name = actions_map[id]
			current_event.actions.append(new_action)
			_refresh_actions_tree()
			_save_json()
			menu.queue_free()
	)
	
	menu.popup_centered()


# ============ ДИАЛОГИ РЕДАКТИРОВАНИЯ ============

func _show_rename_dialog(event: EventSheetData.Event) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Переименовать событие"
	dialog.size = Vector2i(300, 150)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Новое имя:"
	vbox.add_child(label)
	
	var text_edit = LineEdit.new()
	text_edit.text = event.event_name
	text_edit.custom_minimum_size = Vector2(280, 30)
	vbox.add_child(text_edit)
	
	dialog.confirmed.connect(func():
		_save_to_history()
		
		event.event_name = text_edit.text
		_refresh_events_list()
		_save_json()
		dialog.queue_free()
	)
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	text_edit.grab_focus()


func _show_condition_params_dialog(condition: EventSheetData.Condition) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Параметры условия: %s" % condition.condition_name
	dialog.size = Vector2i(400, 300)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Объект:"
	vbox.add_child(label)
	
	var obj_edit = LineEdit.new()
	obj_edit.text = condition.target_object
	obj_edit.custom_minimum_size = Vector2(380, 30)
	vbox.add_child(obj_edit)
	
	for param_name in condition.parameters.keys():
		var param_label = Label.new()
		param_label.text = param_name + ":"
		vbox.add_child(param_label)
		
		var param_edit = LineEdit.new()
		param_edit.text = str(condition.parameters[param_name])
		param_edit.custom_minimum_size = Vector2(380, 30)
		vbox.add_child(param_edit)
	
	var add_param_button = Button.new()
	add_param_button.text = "+ Добавить параметр"
	vbox.add_child(add_param_button)
	
	dialog.confirmed.connect(func():
		_save_to_history()
		
		condition.target_object = obj_edit.text
		_save_json()
		dialog.queue_free()
	)
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()


func _show_action_params_dialog(action: EventSheetData.Action) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Параметры действия: %s" % action.action_name
	dialog.size = Vector2i(400, 300)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Объект:"
	vbox.add_child(label)
	
	var obj_edit = LineEdit.new()
	obj_edit.text = action.target_object
	obj_edit.custom_minimum_size = Vector2(380, 30)
	vbox.add_child(obj_edit)
	
	for param_name in action.parameters.keys():
		var param_label = Label.new()
		param_label.text = param_name + ":"
		vbox.add_child(param_label)
		
		var param_edit = LineEdit.new()
		param_edit.text = str(action.parameters[param_name])
		param_edit.custom_minimum_size = Vector2(380, 30)
		vbox.add_child(param_edit)
	
	var add_param_button = Button.new()
	add_param_button.text = "+ Добавить параметр"
	vbox.add_child(add_param_button)
	
	dialog.confirmed.connect(func():
		_save_to_history()
		
		action.target_object = obj_edit.text
		_save_json()
		dialog.queue_free()
	)
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()


# ============ UNDO/REDO СИСТЕМА ============

func _save_to_history() -> void:
	if current_container == null:
		return
	
	undo_redo.save_state(current_container)


## Обработчик горячих клавиш (Ctrl+Z, Ctrl+Y)
func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		return
	
	if not event is InputEventKey or not event.pressed:
		return
	
	var key_event = event as InputEventKey
	
	# Ctrl+Z - Undo
	if key_event.keycode == KEY_Z and key_event.ctrl_pressed:
		if undo_redo.undo(current_container):
			_refresh_events_list()
			if current_container.events.size() > 0:
				_on_events_list_item_selected(0)
				events_list.select(0)
			print("Undo!")
		# УДАЛИ ЭТУ СТРОКУ:
		# get_tree().set_input_as_handled()
	
	# Ctrl+Y - Redo
	elif key_event.keycode == KEY_Y and key_event.ctrl_pressed:
		if undo_redo.redo(current_container):
			_refresh_events_list()
			if current_container.events.size() > 0:
				_on_events_list_item_selected(0)
				events_list.select(0)
			print("Redo!")
		# УДАЛИ ЭТУ СТРОКУ:
		# get_tree().set_input_as_handled()


# ============ ПОИСК И ФИЛЬТРАЦИЯ ============

func _on_search_field_changed(text: String) -> void:
	_refresh_filtered_events_list(text)


# ============ СОХРАНЕНИЕ ============

func _save_json() -> void:
	if current_container == null or current_json_path.is_empty():
		return
	
	EventSheetData.FileManager.save_to_file(current_container, current_json_path)


# ============ ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ============

func _show_error(message: String) -> void:
	push_error("EventSheetUI: %s" % message)


func _show_info(message: String) -> void:
	if debug_mode:
		print("INFO: %s" % message)

