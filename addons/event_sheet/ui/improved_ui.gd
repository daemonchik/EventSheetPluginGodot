@tool
extends Control
class_name ImprovedEventUI

signal blocks_changed()

# UI элементы
var blocks_container: VBoxContainer
var add_block_button: Button
var save_button: Button
var load_button: Button
var debug_button: Button

# Диалоги
var node_picker_dialog: AcceptDialog
var condition_picker_dialog: AcceptDialog
var action_picker_dialog: AcceptDialog
var parameter_dialog: AcceptDialog

# Данные
var event_sheet: ImprovedEventData.EventSheet
var current_file_path: String = ""
var scene_nodes: Array[Node] = []
var temp_block: ImprovedEventData.EventBlock = null

# Цвета для UI
var BLOCK_COLOR = Color.LIGHT_BLUE
var CONDITION_COLOR = Color.ORANGE  
var ACTION_COLOR = Color.LIGHT_GREEN
var DISABLED_COLOR = Color.GRAY

func _ready():
	if not Engine.is_editor_hint():
		return
	
	event_sheet = ImprovedEventData.EventSheet.new()
	_setup_ui()
	_scan_scene_nodes()

func _setup_ui():
	"""Создаем основной интерфейс"""
	# Основной контейнер
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# Панель инструментов
	var toolbar = HBoxContainer.new()
	main_vbox.add_child(toolbar)
	
	add_block_button = Button.new()
	add_block_button.text = "➕ Добавить блок"
	add_block_button.pressed.connect(_on_add_block_pressed)
	toolbar.add_child(add_block_button)
	
	save_button = Button.new()
	save_button.text = "💾 Сохранить"
	save_button.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_button)
	
	load_button = Button.new()
	load_button.text = "📁 Загрузить"
	load_button.pressed.connect(_on_load_pressed)
	toolbar.add_child(load_button)
	
	debug_button = Button.new()
	debug_button.text = "🐛 Отладка"
	debug_button.pressed.connect(_on_debug_pressed)
	toolbar.add_child(debug_button)
	
	toolbar.add_child(HSeparator.new())
	
	# Заголовок
	var title_label = Label.new()
	title_label.text = "Event Blocks (Объект → Условие → Действие)"
	title_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(title_label)
	
	# Скролл контейнер для блоков
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	blocks_container = VBoxContainer.new()
	scroll.add_child(blocks_container)

func _scan_scene_nodes():
	"""Сканируем все узлы в текущей сцене"""
	scene_nodes.clear()
	
	if not Engine.is_editor_hint():
		return
	
	var edited_scene = EditorInterface.get_edited_scene_root()
	if edited_scene:
		_collect_nodes_recursive(edited_scene)
		print("Найдено узлов в сцене: %d" % scene_nodes.size())

func _collect_nodes_recursive(node: Node):
	"""Рекурсивно собираем все узлы"""
	scene_nodes.append(node)
	for child in node.get_children():
		_collect_nodes_recursive(child)

# Обработчики кнопок

func _on_add_block_pressed():
	"""Начинаем создание нового блока"""
	temp_block = ImprovedEventData.EventBlock.new()
	temp_block.block_id = "block_" + str(randi())
	_show_node_picker_dialog()

func _on_save_pressed():
	"""Сохраняем таблицу событий"""
	if current_file_path.is_empty():
		_show_save_file_dialog()
	else:
		_save_to_file(current_file_path)

func _on_load_pressed():
	"""Загружаем таблицу событий"""
	_show_load_file_dialog()

func _on_debug_pressed():
	"""Показываем отладочную информацию"""
	print("=== Отладочная информация UI ===")
	print("Текущий файл: %s" % current_file_path)
	print("Блоков в таблице: %d" % event_sheet.get_blocks_count())
	print("Узлов в сцене: %d" % scene_nodes.size())

# Диалоги выбора

func _show_node_picker_dialog():
	"""Показываем диалог выбора узла"""
	node_picker_dialog = AcceptDialog.new()
	node_picker_dialog.title = "Выберите объект"
	node_picker_dialog.size = Vector2i(500, 600)
	
	var vbox = VBoxContainer.new()
	node_picker_dialog.add_child(vbox)
	
	# Поле поиска
	var search_field = LineEdit.new()
	search_field.placeholder_text = "Поиск узла..."
	vbox.add_child(search_field)
	
	# Дерево узлов
	var tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.hide_root = false
	vbox.add_child(tree)
	
	_populate_node_tree(tree)
	
	# Фильтрация по поиску
	search_field.text_changed.connect(func(text: String):
		_populate_node_tree(tree, text)
	)
	
	node_picker_dialog.confirmed.connect(func():
		var selected = tree.get_selected()
		if selected:
			var node = selected.get_metadata(0)
			temp_block.target_object = node.get_path()
			temp_block.object_type = node.get_class()
			_show_condition_picker_dialog(node)
		node_picker_dialog.queue_free()
	)
	
	get_tree().root.add_child(node_picker_dialog)
	node_picker_dialog.popup_centered()

func _populate_node_tree(tree: Tree, filter: String = ""):
	"""Заполняем дерево узлами сцены"""
	tree.clear()
	
	if scene_nodes.is_empty():
		_scan_scene_nodes()
	
	var root = tree.create_item()
	root.set_text(0, "Узлы сцены")
	
	for node in scene_nodes:
		if not filter.is_empty():
			var node_text = "%s (%s)" % [node.name, node.get_class()]
			if not node_text.to_lower().contains(filter.to_lower()):
				continue
		
		var item = tree.create_item(root)
		item.set_text(0, "%s (%s)" % [node.name, node.get_class()])
		item.set_metadata(0, node)
		
		# Добавляем иконку по типу узла
		match node.get_class():
			"Button", "CheckBox", "OptionButton":
				item.set_custom_color(0, Color.CYAN)
			"Label", "RichTextLabel":
				item.set_custom_color(0, Color.YELLOW)
			"CharacterBody2D", "RigidBody2D":
				item.set_custom_color(0, Color.RED)
			"Area2D":
				item.set_custom_color(0, Color.GREEN)
			"AnimationPlayer":
				item.set_custom_color(0, Color.MAGENTA)
			"AudioStreamPlayer", "AudioStreamPlayer2D":
				item.set_custom_color(0, Color.ORANGE)
			_:
				item.set_custom_color(0, Color.WHITE)

func _show_condition_picker_dialog(target_node: Node):
	"""Показываем диалог выбора условия"""
	condition_picker_dialog = AcceptDialog.new()
	condition_picker_dialog.title = "Выберите условие для: " + target_node.name
	condition_picker_dialog.size = Vector2i(400, 500)
	
	var vbox = VBoxContainer.new()
	condition_picker_dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Доступные условия для %s:" % target_node.get_class()
	vbox.add_child(label)
	
	var list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(list)
	
	_populate_conditions_for_node(list, target_node)
	
	condition_picker_dialog.confirmed.connect(func():
		var selected_idx = list.get_selected_items()
		if selected_idx.size() > 0:
			var condition_data = list.get_item_metadata(selected_idx[0])
			var condition = ImprovedEventData.EventCondition.new()
			condition.condition_type = condition_data["type"]
			condition.parameters = condition_data.get("default_params", {})
			temp_block.condition = condition
			_show_action_picker_dialog(target_node)
		condition_picker_dialog.queue_free()
	)
	
	get_tree().root.add_child(condition_picker_dialog)
	condition_picker_dialog.popup_centered()

func _populate_conditions_for_node(list: ItemList, node: Node):
	"""Заполняем список условий для конкретного типа узла"""
	# Универсальные условия
	list.add_item("🔄 Сцена готова")
	list.set_item_metadata(list.get_item_count() - 1, {"type": "scene_ready"})
	
	list.add_item("⚡ Каждый кадр")
	list.set_item_metadata(list.get_item_count() - 1, {"type": "every_frame"})
	
	list.add_item("⌨️ Клавиша нажата")
	list.set_item_metadata(list.get_item_count() - 1, {
		"type": "key_pressed",
		"default_params": {"key": "ui_accept"}
	})
	
	list.add_item("🔢 Сравнить переменную")
	list.set_item_metadata(list.get_item_count() - 1, {
		"type": "variable_compare",
		"default_params": {"variable": "health", "operation": "<=", "value": 0}
	})
	
	# Условия для конкретных типов узлов
	if node is BaseButton:
		list.add_item("🖱️ Кнопка нажата")
		list.set_item_metadata(list.get_item_count() - 1, {"type": "button_pressed"})
	
	if node is CharacterBody2D:
		list.add_item("🏠 На полу")
		list.set_item_metadata(list.get_item_count() - 1, {"type": "is_on_floor"})
		
		list.add_item("🧱 У стены")
		list.set_item_metadata(list.get_item_count() - 1, {"type": "is_on_wall"})
	
	if node is AnimationPlayer:
		list.add_item("🎬 Анимация завершена")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "animation_finished",
			"default_params": {"animation": ""}
		})
	
	if node is Area2D:
		list.add_item("💥 Столкновение")
		list.set_item_metadata(list.get_item_count() - 1, {"type": "collision_entered"})
	
	if node is Control:
		list.add_item("🖱️ Курсор вошел")
		list.set_item_metadata(list.get_item_count() - 1, {"type": "mouse_entered"})
	
	if node is Timer:
		list.add_item("⏰ Таймер истек")
		list.set_item_metadata(list.get_item_count() - 1, {"type": "timer_timeout"})

func _show_action_picker_dialog(target_node: Node):
	"""Показываем диалог выбора действия"""
	action_picker_dialog = AcceptDialog.new()
	action_picker_dialog.title = "Выберите действие для: " + target_node.name
	action_picker_dialog.size = Vector2i(400, 500)
	
	var vbox = VBoxContainer.new()
	action_picker_dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Доступные действия для %s:" % target_node.get_class()
	vbox.add_child(label)
	
	var list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(list)
	
	_populate_actions_for_node(list, target_node)
	
	action_picker_dialog.confirmed.connect(func():
		var selected_idx = list.get_selected_items()
		if selected_idx.size() > 0:
			var action_data = list.get_item_metadata(selected_idx[0])
			var action = ImprovedEventData.EventAction.new()
			action.action_type = action_data["type"]
			action.parameters = action_data.get("default_params", {})
			temp_block.actions.append(action)
			_finalize_block_creation()
		action_picker_dialog.queue_free()
	)
	
	get_tree().root.add_child(action_picker_dialog)
	action_picker_dialog.popup_centered()

func _populate_actions_for_node(list: ItemList, node: Node):
	"""Заполняем список действий для конкретного типа узла"""
	# Универсальные действия
	list.add_item("🔧 Установить свойство")
	list.set_item_metadata(list.get_item_count() - 1, {
		"type": "set_property",
		"default_params": {"property": "modulate", "value": Color.RED}
	})
	
	list.add_item("📞 Вызвать метод")
	list.set_item_metadata(list.get_item_count() - 1, {
		"type": "call_method",
		"default_params": {"method": "show", "args": []}
	})
	
	list.add_item("📺 Видимость")
	list.set_item_metadata(list.get_item_count() - 1, {
		"type": "set_visible",
		"default_params": {"visible": true}
	})
	
	list.add_item("💬 Вывести сообщение")
	list.set_item_metadata(list.get_item_count() - 1, {
		"type": "print_message",
		"default_params": {"message": "Hello World!"}
	})
	
	list.add_item("💀 Уничтожить")
	list.set_item_metadata(list.get_item_count() - 1, {"type": "destroy"})
	
	# Действия для Node2D/Node3D
	if node is Node2D or node is Node3D:
		list.add_item("📍 Установить позицию")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "set_position",
			"default_params": {"position": Vector2.ZERO if node is Node2D else Vector3.ZERO}
		})
		
		list.add_item("🔄 Повернуть")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "set_rotation", 
			"default_params": {"rotation": 0.0 if node is Node2D else Vector3.ZERO}
		})
		
		list.add_item("📏 Масштабировать")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "set_scale",
			"default_params": {"scale": Vector2.ONE if node is Node2D else Vector3.ONE}
		})
		
		list.add_item("➡️ Сместить")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "move_by",
			"default_params": {"offset": Vector2(100, 0) if node is Node2D else Vector3(100, 0, 0)}
		})
	
	# Действия для Label/Button
	if node is Label or node is Button or node is LineEdit:
		list.add_item("📝 Установить текст")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "set_text",
			"default_params": {"text": "New text"}
		})
	
	# Действия для AnimationPlayer
	if node is AnimationPlayer:
		list.add_item("▶️ Проиграть анимацию")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "play_animation",
			"default_params": {"animation": "default"}
		})
		
		list.add_item("⏹️ Остановить анимацию")
		list.set_item_metadata(list.get_item_count() - 1, {"type": "stop_animation"})
	
	# Действия для AudioStreamPlayer
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		list.add_item("🔊 Проиграть звук")
		list.set_item_metadata(list.get_item_count() - 1, {"type": "play_sound"})
		
		list.add_item("🔇 Остановить звук")
		list.set_item_metadata(list.get_item_count() - 1, {"type": "stop_sound"})
		
		list.add_item("🔉 Громкость")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "set_volume",
			"default_params": {"volume": -10.0}
		})
	
	# Действия для RigidBody
	if node is RigidBody2D or node is RigidBody3D:
		list.add_item("💨 Импульс")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "apply_impulse",
			"default_params": {"impulse": Vector2(0, -500) if node is RigidBody2D else Vector3(0, 500, 0)}
		})
	
	# Действия для CharacterBody
	if node is CharacterBody2D or node is CharacterBody3D:
		list.add_item("🏃 Скорость")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "set_velocity", 
			"default_params": {"velocity": Vector2(200, 0) if node is CharacterBody2D else Vector3(200, 0, 0)}
		})
	
	# Действия для Timer
	if node is Timer:
		list.add_item("▶️ Запустить таймер")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "start_timer",
			"default_params": {"time": 1.0}
		})
		
		list.add_item("⏹️ Остановить таймер")
		list.set_item_metadata(list.get_item_count() - 1, {"type": "stop_timer"})

func _finalize_block_creation():
	"""Завершаем создание блока и добавляем его в таблицу"""
	if temp_block == null:
		return
	
	event_sheet.add_block(temp_block)
	_create_block_ui(temp_block)
	temp_block = null
	blocks_changed.emit()

func _create_block_ui(block: ImprovedEventData.EventBlock):
	"""Создаем UI элемент для блока"""
	var block_panel = Panel.new()
	block_panel.custom_minimum_size = Vector2(0, 100)
	
	# Цвет фона в зависимости от состояния
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = BLOCK_COLOR if block.enabled else DISABLED_COLOR
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.DARK_BLUE
	block_panel.add_theme_stylebox_override("panel", style_box)
	
	var main_vbox = VBoxContainer.new()
	block_panel.add_child(main_vbox)
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 5)
	
	# Заголовок блока
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_label = Label.new()
	title_label.text = "Блок #%s" % block.block_id.substr(-4)
	title_label.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(title_label)
	
	header_hbox.add_child(Control.new()) # Spacer
	header_hbox.get_child(-1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Кнопка включения/отключения
	var toggle_button = Button.new()
	toggle_button.text = "✓" if block.enabled else "✗"
	toggle_button.custom_minimum_size = Vector2(30, 30)
	toggle_button.pressed.connect(func():
		block.enabled = !block.enabled
		toggle_button.text = "✓" if block.enabled else "✗"
		_refresh_block_ui(block_panel, block)
		blocks_changed.emit()
	)
	header_hbox.add_child(toggle_button)
	
	# Кнопка удаления
	var delete_button = Button.new()
	delete_button.text = "🗑️"
	delete_button.custom_minimum_size = Vector2(30, 30)
	delete_button.pressed.connect(func():
		event_sheet.remove_block(block)
		block_panel.queue_free()
		blocks_changed.emit()
	)
	header_hbox.add_child(delete_button)
	
	# Основной контент блока
	var content_hbox = HBoxContainer.new()
	main_vbox.add_child(content_hbox)
	content_hbox.add_theme_constant_override("separation", 10)
	
	# Объект
	var object_vbox = VBoxContainer.new()
	object_vbox.custom_minimum_size = Vector2(150, 0)
	content_hbox.add_child(object_vbox)
	
	var object_header = Label.new()
	object_header.text = "ОБЪЕКТ"
	object_header.add_theme_font_size_override("font_size", 10)
	object_header.add_theme_color_override("font_color", Color.DARK_BLUE)
	object_vbox.add_child(object_header)
	
	var object_label = Label.new()
	object_label.text = block.target_object.get_file()
	object_label.add_theme_font_size_override("font_size", 12)
	object_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	object_vbox.add_child(object_label)
	
	var object_type_label = Label.new()
	object_type_label.text = "(%s)" % block.object_type
	object_type_label.add_theme_font_size_override("font_size", 9)
	object_type_label.add_theme_color_override("font_color", Color.GRAY)
	object_vbox.add_child(object_type_label)
	
	# Стрелка
	var arrow_label = Label.new()
	arrow_label.text = "→"
	arrow_label.add_theme_font_size_override("font_size", 20)
	content_hbox.add_child(arrow_label)
	
	# Условие
	var condition_vbox = VBoxContainer.new()
	condition_vbox.custom_minimum_size = Vector2(150, 0)
	content_hbox.add_child(condition_vbox)
	
	var condition_header = Label.new()
	condition_header.text = "УСЛОВИЕ"
	condition_header.add_theme_font_size_override("font_size", 10)
	condition_header.add_theme_color_override("font_color", Color.DARK_RED)
	condition_vbox.add_child(condition_header)
	
	var condition_label = Label.new()
	condition_label.text = block.condition.get_display_text() if block.condition else "Нет"
	condition_label.add_theme_font_size_override("font_size", 12)
	condition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	condition_vbox.add_child(condition_label)
	
	# Стрелка
	var arrow_label2 = Label.new()
	arrow_label2.text = "→"
	arrow_label2.add_theme_font_size_override("font_size", 20)
	content_hbox.add_child(arrow_label2)
	
	# Действия
	var actions_vbox = VBoxContainer.new()
	actions_vbox.custom_minimum_size = Vector2(200, 0)
	content_hbox.add_child(actions_vbox)
	
	var actions_header = Label.new()
	actions_header.text = "ДЕЙСТВИЯ (%d)" % block.actions.size()
	actions_header.add_theme_font_size_override("font_size", 10)
	actions_header.add_theme_color_override("font_color", Color.DARK_GREEN)
	actions_vbox.add_child(actions_header)
	
	for action in block.actions:
		var action_label = Label.new()
		action_label.text = "• " + action.get_display_text()
		action_label.add_theme_font_size_override("font_size", 11)
		action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		actions_vbox.add_child(action_label)
	
	blocks_container.add_child(block_panel)

func _refresh_block_ui(block_panel: Panel, block: ImprovedEventData.EventBlock):
	"""Обновляем UI блока"""
	var style_box = block_panel.get_theme_stylebox("panel").duplicate()
	style_box.bg_color = BLOCK_COLOR if block.enabled else DISABLED_COLOR
	block_panel.add_theme_stylebox_override("panel", style_box)

func _refresh_all_blocks():
	"""Обновляем все блоки в UI"""
	# Очищаем контейнер
	for child in blocks_container.get_children():
		child.queue_free()
	
	# Создаем UI для всех блоков
	for block in event_sheet.blocks:
		_create_block_ui(block)

# Работа с файлами

func _show_save_file_dialog():
	"""Показываем диалог сохранения файла"""
	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	file_dialog.add_filter("*.json", "Event Sheet Files")
	file_dialog.current_dir = "res://"
	file_dialog.current_file = "events.json"
	
	file_dialog.file_selected.connect(func(path: String):
		_save_to_file(path)
		file_dialog.queue_free()
	)
	
	get_tree().root.add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _show_load_file_dialog():
	"""Показываем диалог загрузки файла"""
	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.json", "Event Sheet Files")
	file_dialog.current_dir = "res://"
	
	file_dialog.file_selected.connect(func(path: String):
		_load_from_file(path)
		file_dialog.queue_free()
	)
	
	get_tree().root.add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

func _save_to_file(path: String):
	"""Сохраняем в файл"""
	if ImprovedEventData.FileManager.save_to_file(event_sheet, path):
		current_file_path = path
		print("Таблица событий сохранена: %s" % path)
	else:
		print("Ошибка сохранения: %s" % path)

func _load_from_file(path: String):
	"""Загружаем из файла"""
	var loaded_sheet = ImprovedEventData.FileManager.load_from_file(path)
	if loaded_sheet:
		event_sheet = loaded_sheet
		current_file_path = path
		_refresh_all_blocks()
		print("Таблица событий загружена: %s" % path)
		blocks_changed.emit()
	else:
		print("Ошибка загрузки: %s" % path)

# Методы для интеграции с плагином

func load_json(file_path: String):
	"""Загружает JSON файл (метод для обратной совместимости)"""
	_load_from_file(file_path)

func get_current_sheet() -> ImprovedEventData.EventSheet:
	"""Возвращает текущую таблицу событий"""
	return event_sheet

func set_current_sheet(sheet: ImprovedEventData.EventSheet):
	"""Устанавливает текущую таблицу событий"""
	event_sheet = sheet
	_refresh_all_blocks()
	blocks_changed.emit()