@tool
extends Panel

@onready var blank_body_items: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var popup_menu: PopupMenu = $PopupMenu

@onready var window_add: Window = $AddWindow
@onready var window_add_event_or_action: Window = $AddEventOrAction
@onready var window_set_parametr: Window = $SetParameter
@onready var properties_box: PropertiesBox

var shortcut: Shortcut = EditorInterface.get_editor_settings().get_setting("plugins/event_sheet/shortcut")
var current_menu: String = "general"
var popup_menus: Dictionary = {
	"general": ["Add Blank Event"],
	"blank_body": ["Add Event", "Add Action", "", "Add Comment", "", "Duplicate Blank Event", "", "Delete Blank Event"],
	"event": ["Edit Event", "Toggle Event", "Duplicate Event", "Add Event", "", "Delete Event"],
	"action": ["Edit Action", "Toggle Action", "Duplicate Action", "Add Action", "", "Delete Action"],
	"condition": ["Edit Condition", "Toggle Condition", "", "Delete Condition"],
	"comment": ["Edit Comment", "", "Delete Comment"]
}
var is_mouse_focused: bool = false
var event_sheet_data: Dictionary = {}

@onready var current_scene = load("res://demo_project/demo_scene.tscn").instantiate()
var current_blank_body
var current_event
var current_action
var current_comment
var animation_delay_counter: float = 0.0

func _ready() -> void:
	load_event_sheet()
	add_to_group("event_sheet")

	# Создаем PropertiesBox программно, если он не найден в сцене
	if properties_box == null:
		var scroll_container = $SetParameter/Panel/MarginContainer/VBoxContainer/ScrollContainer
		if scroll_container:
			properties_box = load("res://addons/tnowe_extra_controls/elements/properties_box.gd").new()
			properties_box.name = "PropertiesBox"
			properties_box.unique_name_in_owner = true
			properties_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			properties_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_container.add_child(properties_box)
			print("PropertiesBox created programmatically")
		else:
			push_warning("ScrollContainer not found! Cannot create PropertiesBox.")
	else:
		print("PropertiesBox initialized successfully")

func _process(delta: float) -> void:
	pass

func _shortcut_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if shortcut.matches_event(event):
		save_event_sheet()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click and is_mouse_focused:
			show_add_window("event")
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and is_mouse_focused:
			show_popup_menu()

func save_event_sheet():
	var rescan_filesystem = false
	var dirs = [
		"res://event_sheet"
	]
	
	event_sheet_data.clear()
	for i in blank_body_items.get_child_count():
		var event = blank_body_items.get_child(i)
		event_sheet_data[i] = event._save()
	
	for dir in dirs:
		if !DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_absolute(dir)
			rescan_filesystem = true
	
	var files_count: int = DirAccess.get_files_at(dirs[0]).size()
	var file_name = "{0}/event_sheet.json".format([dirs[0]])
	var file = FileAccess.open(file_name, FileAccess.WRITE)
	if event_sheet_data.size() > 0:
		file.store_line(JSON.stringify(event_sheet_data))
	else:
		file.store_line(JSON.stringify({}))
	rescan_filesystem = true
	file.close()
	
	if rescan_filesystem: EditorInterface.get_resource_filesystem().scan()

func load_event_sheet():
	var file_path = FileAccess.open("res://event_sheet/event_sheet.json", FileAccess.READ)

	var json_string = file_path.get_line()
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result == OK:
		var bodies = json.data

		if bodies.size() > 0:
			for b in bodies:
				var blank_body = add_blank_body()

				var events: Dictionary = bodies[b]["events"]
				var actions: Dictionary = bodies[b]["actions"]
				var comments: Dictionary = bodies[b].get("comments", {})

				if events.size() > 0:
					for e in events:
						var event = events[e]
						var group_resource: WGroup = ResourceLoader.load(event["group_resource_path"])
						var event_resource: WEvent = ResourceLoader.load(event["resource_path"])
						var parameters: Dictionary = event["new_parametrs"]
						add_event(group_resource, event_resource, false, parameters, blank_body)

				if actions.size() > 0:
					for a in actions:
						var action = actions[a]
						var group_resource: WGroup = ResourceLoader.load(action["group_resource_path"])
						var action_resource: WAction = ResourceLoader.load(action["resource_path"])
						var parameters: Dictionary = action["new_parametrs"]
						add_action(group_resource, action_resource, false, parameters, blank_body)

				if comments.size() > 0:
					for c in comments:
						var comment = comments[c]
						var comment_text: String = comment["text"]
						add_comment_with_text(blank_body, comment_text)

func add_blank_body():
	var blank_body = load("res://addons/event_sheet/elements/Blank Body/blank_body.tscn").instantiate()
	blank_body.add_action_button.connect(_on_add_action_button_clicked)
	blank_body.bb_popup_button.connect(_on_blank_body_clicked)
	blank_body_items.add_child(blank_body)
	#save_event_sheet()
	return blank_body

func add_event(group_res: WGroup, event_res: WEvent, change_selected_body: bool, new_data: Dictionary, body = null):
	var new_blank_body
	if !change_selected_body:
		if !body:
			new_blank_body = load("res://addons/event_sheet/elements/Blank Body/blank_body.tscn").instantiate()
			new_blank_body.add_action_button.connect(_on_add_action_button_clicked)
			new_blank_body.bb_popup_button.connect(_on_blank_body_clicked)
			blank_body_items.add_child(new_blank_body)
			# Анимация появления нового блока (удалена)
		else:
			new_blank_body = body

		var new_event = load("res://addons/event_sheet/elements/Event/event.tscn").instantiate()
		if new_data.size() > 0: new_event.new_data = new_data
		new_event.event_clicked.connect(_on_event_clicked)
		new_event.blank_body = new_blank_body
		# Присваиваем ресурсы после инициализации
		await get_tree().process_frame
		new_event.event_resource = event_res
		new_event.group_resource = group_res

		new_blank_body.blank_body_tree.add_child(new_event)
		new_blank_body.events.append(new_event)
		# Анимация появления события с задержкой (удалена)
	else:
		if current_blank_body:
			var new_event = load("res://addons/event_sheet/elements/Event/event.tscn").instantiate()
			if new_data.size() > 0: new_event.new_data = new_data
			new_event.event_clicked.connect(_on_event_clicked)
			new_event.blank_body = current_blank_body
			# Присваиваем ресурсы после инициализации
			await get_tree().process_frame
			new_event.event_resource = event_res
			new_event.group_resource = group_res

			current_blank_body.blank_body_tree.add_child(new_event)
			current_blank_body.events.append(new_event)
			# Анимация появления события (удалена)
		else:
			add_event(group_res, event_res, false, new_data)

func add_action(group_res: WGroup, action_res: WAction, change_selected_body: bool, new_data: Dictionary, body = null):
	var new_blank_body
	if !change_selected_body:
		if !body:
			new_blank_body = load("res://addons/event_sheet/elements/Blank Body/blank_body.tscn").instantiate()
			new_blank_body.add_action_button.connect(_on_add_action_button_clicked)
			new_blank_body.bb_popup_button.connect(_on_blank_body_clicked)
			blank_body_items.add_child(new_blank_body)
		else:
			new_blank_body = body
		
		var new_action = load("res://addons/event_sheet/elements/Action/action.tscn").instantiate()
		if new_data.size() > 0: new_action.new_data = new_data
		new_action.action_clicked.connect(_on_action_clicked)
		new_action.blank_body = new_blank_body
		# Присваиваем ресурсы после инициализации
		await get_tree().process_frame
		new_action.action_resource = action_res
		new_action.group_resource = group_res
		
		new_blank_body.actions_tree.add_child(new_action)
		new_blank_body.actions_tree.move_child(new_action, new_blank_body.actions_tree.get_child_count() - 2)
		new_blank_body.actions.append(new_action)
		# Анимация появления действия с задержкой (удалена)
	else:
		if current_blank_body:
			var new_action = load("res://addons/event_sheet/elements/Action/action.tscn").instantiate()
			if new_data.size() > 0: new_action.new_data = new_data
			new_action.action_clicked.connect(_on_action_clicked)
			new_action.blank_body = current_blank_body
			# Присваиваем ресурсы после инициализации
			await get_tree().process_frame
			new_action.action_resource = action_res
			new_action.group_resource = group_res

			current_blank_body.actions_tree.add_child(new_action)
			current_blank_body.actions_tree.move_child(new_action, current_blank_body.actions_tree.get_child_count() - 2)
			current_blank_body.actions.append(new_action)
			# Анимация появления действия (удалена)
		else:
			add_action(group_res, action_res, false, new_data)

func delete_blank_body(blank_body):
	blank_body.actions.clear()
	blank_body.events.clear()
	blank_body.comments.clear()
	current_blank_body = null
	blank_body.queue_free()

func delete_event(blank_body, event):
	blank_body.events.erase(event)
	current_event = null
	event.queue_free()

func delete_action(blank_body, action):
	blank_body.actions.erase(action)
	current_action = null
	action.queue_free()

func show_popup_menu(menu: String = "general"):
	current_menu = menu
	var mouse_pos = Vector2i(get_viewport().get_mouse_position()) + get_window().position
	popup_menu.clear()
	for item in popup_menus[menu]:
		if item == "": popup_menu.add_separator()
		else: popup_menu.add_item(item)
	popup_menu.set_size(Vector2(0, 0))
	popup_menu.set_position(mouse_pos)
	popup_menu.show()

func select_blank_body():
	if current_blank_body:
		for blank_body in blank_body_items.get_children():
			blank_body.set_selected(false)
		current_blank_body.set_selected(true)

func _on_mouse_entered() -> void: is_mouse_focused = true

func _on_mouse_exited() -> void: is_mouse_focused = false

func _on_add_action_button_clicked(blank_body) -> void:
	current_blank_body = blank_body
	select_blank_body()
	show_add_window("action", true)

func _on_event_clicked(blank_body, event, index: int, button: int) -> void:
	match button:
		MOUSE_BUTTON_RIGHT:
			show_popup_menu("event")
			current_blank_body = blank_body
			current_event = event
			select_blank_body()
		MOUSE_BUTTON_LEFT:
			current_blank_body = blank_body
			current_event = event
			select_blank_body()

func _on_action_clicked(blank_body, action, index: int, button: int) -> void:
	match button:
		MOUSE_BUTTON_RIGHT:
			show_popup_menu("action")
			current_blank_body = blank_body
			current_action = action
			select_blank_body()
		MOUSE_BUTTON_LEFT:
			current_blank_body = blank_body
			current_action = action
			select_blank_body()

func _on_comment_clicked(blank_body, comment, index: int, button: int) -> void:
	match button:
		MOUSE_BUTTON_RIGHT:
			show_popup_menu("comment")
			current_blank_body = blank_body
			current_comment = comment
			select_blank_body()
		MOUSE_BUTTON_LEFT:
			current_blank_body = blank_body
			current_comment = comment
			select_blank_body()

func _on_blank_body_clicked(blank_body, index: int, button: int) -> void:
	match button:
		MOUSE_BUTTON_RIGHT:
			show_popup_menu("blank_body")
			current_blank_body = blank_body
			select_blank_body()
		MOUSE_BUTTON_LEFT:
			current_blank_body = blank_body
			select_blank_body()

func _on_popup_menu_index_pressed(index: int) -> void:
	if current_menu == "general":
		match index:
			0: add_blank_body()
	elif current_menu == "blank_body" and current_blank_body:
		match index:
			0: show_add_window("event", true)
			1: show_add_window("action", true)
			3: add_comment(current_blank_body)
			5: duplicate_blank_body(current_blank_body)
			7: delete_blank_body(current_blank_body)
	elif current_menu == "event" and current_blank_body and current_event:
		match index:
			0: edit_event(current_event)
			1: toggle_event(current_event)
			2: duplicate_event(current_event)
			3: show_add_window("event", true)
			5: delete_event(current_blank_body, current_event)
	elif current_menu == "action" and current_blank_body and current_action:
		match index:
			0: edit_action(current_action)
			1: toggle_action(current_action)
			2: duplicate_action(current_action)
			3: show_add_window("action", true)
			5: delete_action(current_blank_body, current_action)
	elif current_menu == "comment" and current_blank_body and current_comment:
		match index:
			0: edit_comment(current_comment)
			2: delete_comment(current_blank_body, current_comment)

# # # # # # # # # # #
# Add Event Window #
# # # # # # # # # #
func _on_add_window_close_requested() -> void:
	window_add.hide()

func _on_add_event_or_action_close_requested() -> void:
	window_add_event_or_action.hide()

func _on_set_parameter_close_requested() -> void:
	window_set_parametr.hide()

func show_add_window(type: String = "event", change_selected_body: bool = true):
	var items: GridContainer = $AddWindow/Panel/MarginContainer/ScrollContainer/Items
	var res_groups_path: String = "res://addons/event_sheet/plugins/groups/"
	var res_groups: Array[WGroup] = []
	var dir := DirAccess.open(res_groups_path)
	
	for item in items.get_children(): item.queue_free()
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# Пропускаем директории
			if dir.current_is_dir() == false:
				var resource_path = res_groups_path + file_name
				if resource_path.ends_with(".tres") or resource_path.ends_with(".res"):
					var resource = ResourceLoader.load(resource_path)
					if resource: res_groups.append(resource)
			file_name = dir.get_next()
		dir.list_dir_end()
	else: print("Failed to open directory: ", res_groups_path)
	
	for res: WGroup in res_groups:
		var id: String = res.id
		var title: String = res.title
		var icon: Texture2D = res.icon
		var events: Array = res.events
		var actions: Array = res.actions
		
		match id:
			"system":
				var button: Button = Button.new()
				button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				button.clip_text = true
				button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
				button.expand_icon = true
				button.custom_minimum_size = Vector2i(96, 96)
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				match type:
					"event":
						window_add.title = "Add Event"
						if events.size() > 0:
							button.text = title
							button.icon = icon
							button.gui_input.connect(_on_add_gui_input.bind(type, events, res, change_selected_body))
							items.add_child(button)
					"action":
						window_add.title = "Add Action"
						if actions.size() > 0:
							button.text = title
							button.icon = icon
							button.gui_input.connect(_on_add_gui_input.bind(type, actions, res, change_selected_body))
							items.add_child(button)
	
	window_add.position = (get_window().size / 2) - (window_add.size / 2)
	window_add.show()

func _on_add_gui_input(event: InputEvent, type: String, items: Array, group_resource: WGroup, change_selected_body: bool) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		window_add.hide()
		
		var items_box: VBoxContainer = $AddEventOrAction/Panel/MarginContainer/ScrollContainer/VBoxContainer
		
		for item in items_box.get_children(): item.queue_free()
		
		var group_name: Label = Label.new()
		group_name.text = "test"
		group_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		group_name.clip_text = true
		group_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
		var group_items: GridContainer = GridContainer.new()
		group_items.columns = 2
		group_items.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var group_separator: HSeparator = HSeparator.new()
		
		match type:
			"event":
				for _event: WEvent in items:
					var id: String = _event.id
					var title: String = _event.title
					var icon: Texture2D = _event.icon
					var description: String = _event.description
					var parameters: Dictionary = _event.parameters
					var group: String = _event.group
					
					var button: Button = Button.new()
					button.alignment = HORIZONTAL_ALIGNMENT_LEFT
					button.clip_text = true
					button.expand_icon = true
					button.custom_minimum_size = Vector2i(243, 40)
					button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					button.gui_input.connect(_on_add_event_or_action_gui_input.bind(_event, group_resource, change_selected_body))
					button.text = _event.title
					button.icon = _event.icon
					
					group_items.add_child(button)
			"action":
				for _action: WAction in items:
					var id: String = _action.id
					var title: String = _action.title
					var icon: Texture2D = _action.icon
					var description: String = _action.description
					var parameters: Dictionary = _action.parameters
					var group: String = _action.group

					var button: Button = Button.new()
					button.alignment = HORIZONTAL_ALIGNMENT_LEFT
					button.clip_text = true
					button.expand_icon = true
					button.custom_minimum_size = Vector2i(243, 40)
					button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					button.gui_input.connect(_on_add_event_or_action_gui_input.bind(_action, group_resource, change_selected_body))
					button.text = title
					button.icon = icon
					
					group_items.add_child(button)
		
		items_box.add_child(group_name)
		items_box.add_child(group_items)
		items_box.add_child(group_separator)

		window_add_event_or_action.position = (get_window().size / 2) - (window_add_event_or_action.size / 2)
		window_add_event_or_action.show()

func _on_add_event_or_action_gui_input(event: InputEvent, object_resource, group_resource: WGroup, change_selected_body: bool) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		window_add_event_or_action.hide()
		
		var description_label: Label = $SetParameter/Panel/MarginContainer/VBoxContainer/Description
		var parameters_box: VBoxContainer = $SetParameter/Panel/MarginContainer/VBoxContainer/ScrollContainer/Parameters
		var back_button: Button = $SetParameter/Panel/MarginContainer/VBoxContainer/Buttons/Back
		var finish_button: Button = $SetParameter/Panel/MarginContainer/VBoxContainer/Buttons/Finish
		
		# Отключаем все существующие соединения
		if back_button.button_up.is_connected(_on_back_button_up):
			back_button.button_up.disconnect(_on_back_button_up)
		if back_button.button_up.is_connected(_on_edit_finish_button_up):
			back_button.button_up.disconnect(_on_edit_finish_button_up)
		if finish_button.button_up.is_connected(_on_finish_button_up):
			finish_button.button_up.disconnect(_on_finish_button_up)
		if finish_button.button_up.is_connected(_on_edit_finish_button_up):
			finish_button.button_up.disconnect(_on_edit_finish_button_up)

		if object_resource is WEvent:
			var event_resource: WEvent = object_resource
			if event_resource.parameters.size() > 0:
				if properties_box:
					properties_box.clear()

					description_label.text = "{0}: {1}".format([event_resource.title, event_resource.description])

					# Используем PropertiesBox для создания полей
					for key in event_resource.parameters:
						var param_info = _get_parameter_info(event_resource.parameters, key)
						var value = param_info.default

						# Отладка: выводим информацию о параметре
						print("DEBUG: Adding parameter '%s' with type %d and value: %s (type: %s)" % [key, param_info.type, str(value), type_string(typeof(value))])

						match param_info.type:
							TYPE_BOOL:
								properties_box.add_bool(key, value if value is bool else false)
							TYPE_INT:
								if param_info.min != null and param_info.max != null:
									properties_box.add_int(key, value if value is int else 0, param_info.min, param_info.max)
								else:
									properties_box.add_int(key, value if value is int else 0)
							TYPE_FLOAT:
								if param_info.min != null and param_info.max != null:
									properties_box.add_float(key, value if value is float else 0.0, param_info.min, param_info.max, param_info.step)
								else:
									properties_box.add_float(key, value if value is float else 0.0)
							TYPE_STRING:
								properties_box.add_string(key, value if value is String else str(value))
							_:
								properties_box.add_string(key, value if value is String else str(value))

					# Подключаем обработчики для добавления
					back_button.button_up.connect(_on_back_button_up)
					finish_button.button_up.connect(_on_properties_finish_button_up.bind("event", group_resource, event_resource, change_selected_body))
					window_set_parametr.position = (get_window().size / 2) - (window_set_parametr.size / 2)
					window_set_parametr.show()
			else:
				var new_data = {}
				add_event(group_resource, event_resource, change_selected_body, new_data)
		elif object_resource is WAction:
			var action_resource: WAction = object_resource
			if action_resource.parameters.size() > 0:
				properties_box.clear()

				description_label.text = "{0}: {1}".format([action_resource.title, action_resource.description])

				# Используем PropertiesBox для создания полей
				for key in action_resource.parameters:
					var param_info = _get_parameter_info(action_resource.parameters, key)
					var value = param_info.default

					match param_info.type:
						TYPE_BOOL:
							properties_box.add_bool(key, value if value is bool else false)
						TYPE_INT:
							if param_info.min != null and param_info.max != null:
								properties_box.add_int(key, value if value is int else 0, param_info.min, param_info.max)
							else:
								properties_box.add_int(key, value if value is int else 0)
						TYPE_FLOAT:
							if param_info.min != null and param_info.max != null:
								properties_box.add_float(key, value if value is float else 0.0, param_info.min, param_info.max, param_info.step)
							else:
								properties_box.add_float(key, value if value is float else 0.0)
						TYPE_STRING:
							properties_box.add_string(key, value if value is String else str(value))
						_:
							properties_box.add_string(key, value if value is String else str(value))

				# Подключаем обработчики для добавления
				back_button.button_up.connect(_on_back_button_up)
				finish_button.button_up.connect(_on_properties_finish_button_up.bind("action", group_resource, action_resource, change_selected_body))
				window_set_parametr.position = (get_window().size / 2) - (window_set_parametr.size / 2)
				window_set_parametr.show()
			else:
				var new_data = {}
				add_action(group_resource, action_resource, change_selected_body, new_data)

func _on_properties_finish_button_up(type: String, group_resource: WGroup, resource, change_selected_body: bool) -> void:
	"""Завершает добавление с использованием PropertiesBox"""
	var new_data: Dictionary = properties_box.get_all()

	# Сбрасываем счетчик задержки перед добавлением новых элементов
	animation_delay_counter = 0.0

	match type:
		"event":
			add_event(group_resource, resource, change_selected_body, new_data)
		"action":
			add_action(group_resource, resource, change_selected_body, new_data)

	window_set_parametr.hide()

func _on_finish_button_up(type: String, parameters_box: VBoxContainer, group_resource: WGroup, resource, change_selected_body: bool) -> void:

	var new_data: Dictionary = {}

	for param: HBoxContainer in parameters_box.get_children():
		var p_name: Label = param.get_child(0)
		var p_value = param.get_child(1)
		new_data[p_name.text] = _get_control_value(p_value)

	# Сбрасываем счетчик задержки перед добавлением новых элементов
	animation_delay_counter = 0.0

	match type:
		"event":
			add_event(group_resource, resource, change_selected_body, new_data)
		"action":
			add_action(group_resource, resource, change_selected_body, new_data)

	window_set_parametr.hide()

func _on_back_button_up() -> void:
	window_set_parametr.hide()
	window_add_event_or_action.show()

# # # # # # # # # # #
# Edit Functions   #
# # # # # # # # # #

func edit_event(event):
	"""Редактирует параметры существующего события"""
	if event and event.event_resource:
		if event.event_resource.parameters.size() > 0:
			show_edit_window("event", event)
		# Если параметров нет, ничего не делаем - редактировать нечего

func edit_action(action):
	"""Редактирует параметры существующего действия"""
	if action and action.action_resource:
		if action.action_resource.parameters.size() > 0:
			show_edit_window("action", action)
		# Если параметров нет, ничего не делаем - редактировать нечего

func toggle_event(event):
	"""Переключает включение/отключение события"""
	event.event_resource.enabled = !event.event_resource.enabled
	event.update_visual()
	save_event_sheet()

func toggle_action(action):
	"""Переключает включение/отключение действия"""
	action.action_resource.enabled = !action.action_resource.enabled
	action.update_visual()
	save_event_sheet()

func show_edit_window(type: String, element):
	"""Показывает окно редактирования параметров с использованием PropertiesBox"""
	var description_label: Label = $SetParameter/Panel/MarginContainer/VBoxContainer/Description
	var back_button: Button = $SetParameter/Panel/MarginContainer/VBoxContainer/Buttons/Back
	var finish_button: Button = $SetParameter/Panel/MarginContainer/VBoxContainer/Buttons/Finish

	# Очищаем PropertiesBox
	properties_box.clear()

	# Отключаем все существующие соединения
	if back_button.button_up.is_connected(_on_back_button_up):
		back_button.button_up.disconnect(_on_back_button_up)
	if back_button.button_up.is_connected(_on_edit_properties_finish_button_up):
		back_button.button_up.disconnect(_on_edit_properties_finish_button_up)
	if finish_button.button_up.is_connected(_on_properties_finish_button_up):
		finish_button.button_up.disconnect(_on_properties_finish_button_up)
	if finish_button.button_up.is_connected(_on_edit_properties_finish_button_up):
		finish_button.button_up.disconnect(_on_edit_properties_finish_button_up)

	match type:
		"event":
			var event_resource: WEvent = element.event_resource
			description_label.text = "Edit {0}: {1}".format([event_resource.title, event_resource.description])

			# Заполняем существующие параметры в PropertiesBox
			for key in event_resource.parameters:
				var param_info = _get_parameter_info(event_resource.parameters, key)
				var value = element.new_data.get(key, param_info.default)

				match param_info.type:
					TYPE_BOOL:
						properties_box.add_bool(key, value if value is bool else false)
					TYPE_INT:
						if param_info.min != null and param_info.max != null:
							properties_box.add_int(key, value if value is int else 0, param_info.min, param_info.max)
						else:
							properties_box.add_int(key, value if value is int else 0)
					TYPE_FLOAT:
						if param_info.min != null and param_info.max != null:
							properties_box.add_float(key, value if value is float else 0.0, param_info.min, param_info.max, param_info.step)
						else:
							properties_box.add_float(key, value if value is float else 0.0)
					TYPE_STRING:
						properties_box.add_string(key, value if value is String else str(value))
					_:
						properties_box.add_string(key, value if value is String else str(value))

			# Подключаем обработчики для редактирования
			back_button.button_up.connect(_on_back_button_up)
			finish_button.button_up.connect(_on_edit_properties_finish_button_up.bind("event", element))

		"action":
			var action_resource: WAction = element.action_resource
			description_label.text = "Edit {0}: {1}".format([action_resource.title, action_resource.description])

			# Заполняем существующие параметры в PropertiesBox
			for key in action_resource.parameters:
				var param_info = _get_parameter_info(action_resource.parameters, key)
				var value = element.new_data.get(key, param_info.default)

				match param_info.type:
					TYPE_BOOL:
						properties_box.add_bool(key, value if value is bool else false)
					TYPE_INT:
						if param_info.min != null and param_info.max != null:
							properties_box.add_int(key, value if value is int else 0, param_info.min, param_info.max)
						else:
							properties_box.add_int(key, value if value is int else 0)
					TYPE_FLOAT:
						if param_info.min != null and param_info.max != null:
							properties_box.add_float(key, value if value is float else 0.0, param_info.min, param_info.max, param_info.step)
						else:
							properties_box.add_float(key, value if value is float else 0.0)
					TYPE_STRING:
						properties_box.add_string(key, value if value is String else str(value))
					_:
						properties_box.add_string(key, value if value is String else str(value))

			# Подключаем обработчики для редактирования
			back_button.button_up.connect(_on_back_button_up)
			finish_button.button_up.connect(_on_edit_properties_finish_button_up.bind("action", element))

	window_set_parametr.position = (get_window().size / 2) - (window_set_parametr.size / 2)
	window_set_parametr.show()

func _on_edit_properties_finish_button_up(type: String, element) -> void:
	"""Завершает редактирование с использованием PropertiesBox и обновляет элемент"""
	var new_data: Dictionary = properties_box.get_all()

	match type:
		"event":
			element.new_data = new_data
			element.update_visual()
		"action":
			element.new_data = new_data
			element.update_visual()

	window_set_parametr.hide()
	save_event_sheet()

func _on_edit_finish_button_up(type: String, parameters_box: VBoxContainer, element) -> void:
	"""Завершает редактирование и обновляет элемент"""
	var new_data: Dictionary = {}

	for param: HBoxContainer in parameters_box.get_children():
		var p_name: Label = param.get_child(0)
		var p_value = param.get_child(1)
		new_data[p_name.text] = _get_control_value(p_value)

	match type:
		"event":
			element.new_data = new_data
			element.update_visual()
		"action":
			element.new_data = new_data
			element.update_visual()

	window_set_parametr.hide()
	save_event_sheet()

# # # # # # # # # # #
# Duplicate Functions #
# # # # # # # # # #

func duplicate_event(event):
	"""Дублирует событие"""
	if current_blank_body and event:
		var duplicated_data = event.new_data.duplicate()
		add_event(event.group_resource, event.event_resource, true, duplicated_data)

func duplicate_action(action):
	"""Дублирует действие"""
	if current_blank_body and action:
		var duplicated_data = action.new_data.duplicate()
		add_action(action.group_resource, action.action_resource, true, duplicated_data)

func duplicate_blank_body(blank_body):
	"""Дублирует весь блок событий"""
	if blank_body:
		var new_blank_body = add_blank_body()

		# Копируем все события
		for event in blank_body.events:
			var event_data = event.new_data.duplicate()
			add_event(event.group_resource, event.event_resource, false, event_data, new_blank_body)

		# Копируем все действия
		for action in blank_body.actions:
			var action_data = action.new_data.duplicate()
			add_action(action.group_resource, action.action_resource, false, action_data, new_blank_body)

		# Копируем все комментарии
		for comment in blank_body.comments:
			var comment_text = comment.comment_text_data
			add_comment_with_text(new_blank_body, comment_text)

		save_event_sheet()

# # # # # # # # # # #
# Comment Functions #
# # # # # # # # # #

func add_comment(blank_body):
	"""Добавляет комментарий к блоку"""
	if blank_body:
		var comment = load("res://addons/event_sheet/elements/Comment/comment.tscn").instantiate()
		comment.comment_clicked.connect(_on_comment_clicked)
		comment.blank_body = blank_body

		# Добавляем комментарий в дерево событий (перед действиями)
		blank_body.blank_body_tree.add_child(comment)
		blank_body.blank_body_tree.move_child(comment, blank_body.blank_body_tree.get_child_count() - 2)
		blank_body.comments.append(comment)

		# Анимация появления комментария (удалена)

		save_event_sheet()

func edit_comment(comment):
	"""Редактирует комментарий"""
	if comment:
		# Комментарий редактируется прямо в TextEdit, поэтому просто фокусируем его
		comment.comment_text.grab_focus()
		comment.comment_text.select_all()

func delete_comment(blank_body, comment):
	"""Удаляет комментарий"""
	if blank_body and comment:
		blank_body.comments.erase(comment)
		current_comment = null
		comment.queue_free()
		save_event_sheet()

func add_comment_with_text(blank_body, text: String):
	"""Добавляет комментарий с заданным текстом (для загрузки)"""
	if blank_body:
		var comment = load("res://addons/event_sheet/elements/Comment/comment.tscn").instantiate()
		comment.comment_clicked.connect(_on_comment_clicked)
		comment.blank_body = blank_body
		comment.comment_text_data = text

		# Добавляем комментарий в дерево событий (перед действиями)
		blank_body.blank_body_tree.add_child(comment)
		blank_body.blank_body_tree.move_child(comment, blank_body.blank_body_tree.get_child_count() - 2)
		blank_body.comments.append(comment)

# # # # # # # # # # #
# Parameter Functions #
# # # # # # # # # #

func _get_parameter_info(parameters: Dictionary, key: String) -> Dictionary:
	"""Получает информацию о параметре (тип, значение по умолчанию, описание)"""
	var param_value = parameters[key]

	# Новый формат: {"type": TYPE_INT, "default": 5, "description": "Count"}
	if param_value is Dictionary:
		var default_value = param_value.get("default", "")
		var param_type = param_value.get("type", TYPE_STRING)

		# Преобразуем default_value в правильный тип
		match param_type:
			TYPE_BOOL:
				default_value = default_value if default_value is bool else false
			TYPE_INT:
				default_value = default_value if default_value is int else 0
			TYPE_FLOAT:
				default_value = default_value if default_value is float else 0.0
			TYPE_STRING:
				default_value = default_value if default_value is String else str(default_value)

		return {
			"type": param_type,
			"default": default_value,
			"description": param_value.get("description", ""),
			"min": param_value.get("min"),
			"max": param_value.get("max"),
			"step": param_value.get("step", 1.0)
		}
	# Старый формат: "default_value"
	else:
		var param_type = TYPE_STRING
		var default_value = param_value

		if param_value is int:
			param_type = TYPE_INT
		elif param_value is float:
			param_type = TYPE_FLOAT
		elif param_value is bool:
			param_type = TYPE_BOOL
		else:
			# Если это строка, попробуем распарсить как число или булево
			if param_value is String:
				if param_value.is_valid_int():
					param_type = TYPE_INT
					default_value = param_value.to_int()
				elif param_value.is_valid_float():
					param_type = TYPE_FLOAT
					default_value = param_value.to_float()
				elif param_value.to_lower() in ["true", "false"]:
					param_type = TYPE_BOOL
					default_value = param_value.to_lower() == "true"

		return {
			"type": param_type,
			"default": default_value,
			"description": "",
			"min": null,
			"max": null,
			"step": 1.0
		}

func _create_parameter_control(param_info: Dictionary, value, key: String = "") -> Control:
	"""Создает подходящий контрол для типа параметра"""
	var param_type = param_info.type

	match param_type:
		TYPE_BOOL:
			var checkbox = CheckBox.new()
			checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			checkbox.button_pressed = bool(value)
			return checkbox

		TYPE_INT:
			var spinbox = SpinBox.new()
			spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spinbox.value = int(value)
			if param_info.min != null:
				spinbox.min_value = param_info.min
			if param_info.max != null:
				spinbox.max_value = param_info.max
			spinbox.step = param_info.step
			return spinbox

		TYPE_FLOAT:
			var spinbox = SpinBox.new()
			spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spinbox.value = float(value)
			if param_info.min != null:
				spinbox.min_value = param_info.min
			if param_info.max != null:
				spinbox.max_value = param_info.max
			# Если min/max не установлены, используем значения по умолчанию
			if param_info.min == null and param_info.max == null:
				# Специальная обработка для угла - диапазон 0-360
				if param_info.get("description", "").to_lower().contains("angle") or key.to_lower().contains("angle"):
					spinbox.min_value = 0
					spinbox.max_value = 360
				else:
					# Значения по умолчанию для других float параметров
					spinbox.min_value = -1000
					spinbox.max_value = 1000
			spinbox.step = param_info.step if param_info.step != null else 0.1
			return spinbox

		TYPE_VECTOR2:
			var line_edit = LineEdit.new()
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if value is Vector2:
				line_edit.text = "%s, %s" % [value.x, value.y]
			else:
				line_edit.text = str(value)
			line_edit.placeholder_text = "x, y"
			return line_edit

		TYPE_VECTOR3:
			var line_edit = LineEdit.new()
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if value is Vector3:
				line_edit.text = "%s, %s, %s" % [value.x, value.y, value.z]
			else:
				line_edit.text = str(value)
			line_edit.placeholder_text = "x, y, z"
			return line_edit

		TYPE_COLOR:
			var color_picker = ColorPickerButton.new()
			color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if value is Color:
				color_picker.color = value
			return color_picker

		TYPE_RECT2:
			var line_edit = LineEdit.new()
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if value is Rect2:
				line_edit.text = "%s, %s, %s, %s" % [value.position.x, value.position.y, value.size.x, value.size.y]
			else:
				line_edit.text = str(value)
			line_edit.placeholder_text = "x, y, w, h"
			return line_edit

		_:
			# Default to LineEdit for strings and unknown types
			var line_edit = LineEdit.new()
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line_edit.text = str(value)
			return line_edit

func _get_control_value(control: Control):
	"""Получает значение из контрола в зависимости от его типа"""
	if control is LineEdit:
		return control.text
	elif control is CheckBox:
		return control.button_pressed
	elif control is SpinBox:
		return control.value
	elif control is ColorPickerButton:
		return control.color
	else:
		return str(control)
