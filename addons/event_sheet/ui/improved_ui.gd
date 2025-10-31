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
var refresh_button: Button

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
var BLOCK_COLOR = Color(0.3, 0.5, 0.8, 1.0)
var CONDITION_COLOR = Color(0.8, 0.5, 0.2, 1.0) 
var ACTION_COLOR = Color(0.3, 0.8, 0.3, 1.0)
var DISABLED_COLOR = Color(0.4, 0.4, 0.4, 1.0)

func _ready():
	if not Engine.is_editor_hint():
		return
	
	event_sheet = ImprovedEventData.EventSheet.new()
	_setup_ui()
	_scan_scene_nodes()
	
	# Подключаем сигнал изменения сцены
	if EditorInterface:
		EditorInterface.get_selection().selection_changed.connect(_on_scene_changed)

func _setup_ui():
	"""Создаем основной интерфейс"""
	# Очищаем существующие дочерние элементы
	for child in get_children():
		child.queue_free()
	
	# Основной контейнер
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# Панель инструментов
	var toolbar = HBoxContainer.new()
	main_vbox.add_child(toolbar)
	
	add_block_button = Button.new()
	add_block_button.text = "➕"
	add_block_button.tooltip_text = "Добавить блок события"
	add_block_button.pressed.connect(_on_add_block_pressed)
	toolbar.add_child(add_block_button)
	
	save_button = Button.new()
	save_button.text = "💾"
	save_button.tooltip_text = "Сохранить таблицу событий"
	save_button.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_button)
	
	load_button = Button.new()
	load_button.text = "📁"
	load_button.tooltip_text = "Загрузить таблицу событий"
	load_button.pressed.connect(_on_load_pressed)
	toolbar.add_child(load_button)
	
	refresh_button = Button.new()
	refresh_button.text = "🔄"
	refresh_button.tooltip_text = "Обновить список узлов сцены"
	refresh_button.pressed.connect(_on_refresh_pressed)
	toolbar.add_child(refresh_button)
	
	debug_button = Button.new()
	debug_button.text = "🐛"
	debug_button.tooltip_text = "Показать отладочную информацию"
	debug_button.pressed.connect(_on_debug_pressed)
	toolbar.add_child(debug_button)
	
	# Заголовок
	var title_label = Label.new()
	title_label.text = "Event Blocks"
	title_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(title_label)
	
	var subtitle_label = Label.new()
	subtitle_label.text = "Объект → Условие → Действие"
	subtitle_label.add_theme_font_size_override("font_size", 10)
	subtitle_label.modulate = Color.GRAY
	main_vbox.add_child(subtitle_label)
	
	# Скролл контейнер для блоков
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	blocks_container = VBoxContainer.new()
	blocks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(blocks_container)
	
	# Статус бар
	var status_bar = HBoxContainer.new()
	main_vbox.add_child(status_bar)
	
	var file_label = Label.new()
	file_label.text = "Файл: не выбран"
	file_label.add_theme_font_size_override("font_size", 10)
	file_label.modulate = Color.GRAY
	status_bar.add_child(file_label)

func _scan_scene_nodes():
	"""Сканируем все узлы в текущей сцене"""
	scene_nodes.clear()
	
	if not Engine.is_editor_hint():
		return
	
	var edited_scene = EditorInterface.get_edited_scene_root()
	if edited_scene:
		_collect_nodes_recursive(edited_scene)
		if scene_nodes.size() > 0:
			print("🔍 Найдено узлов в сцене: %d" % scene_nodes.size())

func _collect_nodes_recursive(node: Node):
	"""Рекурсивно собираем все узлы"""
	scene_nodes.append(node)
	for child in node.get_children():
		_collect_nodes_recursive(child)

func _on_scene_changed():
	"""Обновляем список узлов при изменении сцены"""
	_scan_scene_nodes()

# Обработчики кнопок

func _on_add_block_pressed():
	"""Начинаем создание нового блока"""
	if scene_nodes.is_empty():
		_scan_scene_nodes()
		if scene_nodes.is_empty():
			_show_error("Нет узлов в текущей сцене. Откройте сцену для редактирования.")
			return
	
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

func _on_refresh_pressed():
	"""Обновляем список узлов сцены"""
	_scan_scene_nodes()

func _on_debug_pressed():
	"""Показываем отладочную информацию"""
	print("=== 🐛 Отладочная информация EventSheet UI ===")
	print("Текущий файл: %s" % current_file_path)
	print("Блоков в таблице: %d" % event_sheet.get_blocks_count())
	print("Узлов в сцене: %d" % scene_nodes.size())
	print("UI элементов: %d" % blocks_container.get_child_count())
	
	for i in range(event_sheet.blocks.size()):
		var block = event_sheet.blocks[i]
		var status = "✅" if block.enabled else "❌"
		print("Блок %d: %s %s" % [i + 1, status, block.get_display_text()])
	print("=============================================")

# Диалоги выбора

func _show_node_picker_dialog():
	"""Показываем диалог выбора узла"""
	if node_picker_dialog:
		node_picker_dialog.queue_free()
	
	node_picker_dialog = AcceptDialog.new()
	node_picker_dialog.title = "Выберите объект"
	node_picker_dialog.size = Vector2i(500, 600)
	
	var vbox = VBoxContainer.new()
	node_picker_dialog.add_child(vbox)
	
	# Информация
	var info_label = Label.new()
	info_label.text = "Выберите узел сцены для привязки события:"
	vbox.add_child(info_label)
	
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
		if selected and selected.get_metadata(0):
			var node = selected.get_metadata(0)
			temp_block.target_object = str(node.get_path())
			temp_block.object_type = node.get_class()
			_show_condition_picker_dialog(node)
		else:
			_show_error("Выберите узел из списка")
		node_picker_dialog.queue_free()
		node_picker_dialog = null
	)
	
	node_picker_dialog.canceled.connect(func():
		temp_block = null
		node_picker_dialog.queue_free()
		node_picker_dialog = null
	)
	
	get_tree().root.add_child(node_picker_dialog)
	node_picker_dialog.popup_centered()

func _populate_node_tree(tree: Tree, filter: String = ""):
	"""Заполняем дерево узлами сцены"""
	tree.clear()
	
	if scene_nodes.is_empty():
		var item = tree.create_item()
		item.set_text(0, "Нет узлов в сцене")
		return
	
	var root = tree.create_item()
	root.set_text(0, "Узлы сцены (%d)" % scene_nodes.size())
	
	for node in scene_nodes:
		if not is_instance_valid(node):
			continue
			
		var node_text = "%s (%s)" % [node.name, node.get_class()]
		
		# Применяем фильтр
		if not filter.is_empty():
			if not node_text.to_lower().contains(filter.to_lower()):
				continue
		
		var item = tree.create_item(root)
		item.set_text(0, node_text)
		item.set_metadata(0, node)
		
		# Цветовое кодирование по типу узла
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
			"AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D":
				item.set_custom_color(0, Color.ORANGE)
			"Timer":
				item.set_custom_color(0, Color.LIGHT_BLUE)
			_:
				item.set_custom_color(0, Color.WHITE)

func _show_condition_picker_dialog(target_node: Node):
	"""Показываем диалог выбора условия"""
	if condition_picker_dialog:
		condition_picker_dialog.queue_free()
	
	condition_picker_dialog = AcceptDialog.new()
	condition_picker_dialog.title = "Условие для: " + target_node.name
	condition_picker_dialog.size = Vector2i(450, 500)
	
	var vbox = VBoxContainer.new()
	condition_picker_dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Выберите условие для %s (%s):" % [target_node.name, target_node.get_class()]
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
		else:
			_show_error("Выберите условие из списка")
		condition_picker_dialog.queue_free()
		condition_picker_dialog = null
	)
	
	condition_picker_dialog.canceled.connect(func():
		temp_block = null
		condition_picker_dialog.queue_free()
		condition_picker_dialog = null
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
	
	if node is CharacterBody2D or node is CharacterBody3D:
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
	
	if node is Area2D or node is Area3D:
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
	if action_picker_dialog:
		action_picker_dialog.queue_free()
	
	action_picker_dialog = AcceptDialog.new()
	action_picker_dialog.title = "Действие для: " + target_node.name
	action_picker_dialog.size = Vector2i(450, 500)
	
	var vbox = VBoxContainer.new()
	action_picker_dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Выберите действие для %s (%s):" % [target_node.name, target_node.get_class()]
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
		else:
			_show_error("Выберите действие из списка")
		action_picker_dialog.queue_free()
		action_picker_dialog = null
	)
	
	action_picker_dialog.canceled.connect(func():
		temp_block = null
		action_picker_dialog.queue_free()
		action_picker_dialog = null
	)
	
	get_tree().root.add_child(action_picker_dialog)
	action_picker_dialog.popup_centered()

func _populate_actions_for_node(list: ItemList, node: Node):
	"""Заполняем список действий для конкретного типа узла"""
	# Универсальные действия
	list.add_item("🔧 Установить свойство")
	list.set_item_metadata(list.get_item_count() - 1, {
		"type": "set_property",
		"default_params": {"property": "modulate", "value": {"r": 1.0, "g": 0.0, "b": 0.0, "a": 1.0}}
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
		"default_params": {"message": "Hello from EventSheet!"}
	})
	
	list.add_item("💀 Уничтожить")
	list.set_item_metadata(list.get_item_count() - 1, {"type": "destroy"})
	
	# Действия для Node2D/Node3D
	if node is Node2D or node is Node3D:
		list.add_item("📍 Установить позицию")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "set_position",
			"default_params": {"position": {"x": 100, "y": 100, "z": 0} if node is Node3D else {"x": 100, "y": 100}}
		})
		
		list.add_item("🔄 Повернуть")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "set_rotation", 
			"default_params": {"rotation": {"x": 0, "y": 0, "z": 45} if node is Node3D else 45.0}
		})
		
		list.add_item("📏 Масштабировать")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "set_scale",
			"default_params": {"scale": {"x": 1.5, "y": 1.5, "z": 1.5} if node is Node3D else {"x": 1.5, "y": 1.5}}
		})
		
		list.add_item("➡️ Сместить")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "move_by",
			"default_params": {"offset": {"x": 50, "y": 0, "z": 0} if node is Node3D else {"x": 50, "y": 0}}
		})
	
	# Действия для текстовых элементов
	if node is Label or node is Button or node is LineEdit:
		list.add_item("📝 Установить текст")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "set_text",
			"default_params": {"text": "Новый текст"}
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
	
	# Действия для физических тел
	if node is RigidBody2D or node is RigidBody3D:
		list.add_item("💨 Импульс")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "apply_impulse",
			"default_params": {"impulse": {"x": 0, "y": -500, "z": 0} if node is RigidBody3D else {"x": 0, "y": -500}}
		})
	
	if node is CharacterBody2D or node is CharacterBody3D:
		list.add_item("🏃 Скорость")
		list.set_item_metadata(list.get_item_count() - 1, {
			"type": "set_velocity", 
			"default_params": {"velocity": {"x": 200, "y": 0, "z": 0} if node is CharacterBody3D else {"x": 200, "y": 0}}
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
	print("✅ Блок событий создан")

func _create_block_ui(block: ImprovedEventData.EventBlock):
	"""Создаем UI элемент для блока"""
	var block_panel = Panel.new()
	block_panel.custom_minimum_size = Vector2(0, 120)
	
	# Стиль панели
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
	style_box.border_color = Color.WHITE if block.enabled else Color.GRAY
	block_panel.add_theme_stylebox_override("panel", style_box)
	
	var main_vbox = VBoxContainer.new()
	block_panel.add_child(main_vbox)
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	
	# Заголовок блока
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_label = Label.new()
	title_label.text = "Блок #%s" % block.block_id.substr(-4)
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	header_hbox.add_child(title_label)
	
	# Спейсер
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	
	# Кнопка включения/отключения
	var toggle_button = Button.new()
	toggle_button.text = "✓" if block.enabled else "✗"
	toggle_button.custom_minimum_size = Vector2(25, 25)
	toggle_button.tooltip_text = "Включить/отключить блок"
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
	delete_button.custom_minimum_size = Vector2(25, 25)
	delete_button.tooltip_text = "Удалить блок"
	delete_button.pressed.connect(func():
		event_sheet.remove_block(block)
		block_panel.queue_free()
		blocks_changed.emit()
		print("🗑️ Блок событий удален")
	)
	header_hbox.add_child(delete_button)
	
	# Основной контент блока
	var content_label = Label.new()
	content_label.text = block.get_display_text()
	content_label.add_theme_font_size_override("font_size", 11)
	content_label.add_theme_color_override("font_color", Color.WHITE)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(content_label)
	
	blocks_container.add_child(block_panel)

func _refresh_block_ui(block_panel: Panel, block: ImprovedEventData.EventBlock):
	"""Обновляем UI блока"""
	var style_box = block_panel.get_theme_stylebox("panel")
	if style_box is StyleBoxFlat:
		var new_style = style_box.duplicate()
		new_style.bg_color = BLOCK_COLOR if block.enabled else DISABLED_COLOR
		new_style.border_color = Color.WHITE if block.enabled else Color.GRAY
		block_panel.add_theme_stylebox_override("panel", new_style)

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
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
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
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
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
		print("💾 Таблица событий сохранена: %s" % path)
		_update_status_bar()
	else:
		_show_error("Ошибка сохранения: %s" % path)

func _load_from_file(path: String):
	"""Загружаем из файла"""
	var loaded_sheet = ImprovedEventData.FileManager.load_from_file(path)
	if loaded_sheet:
		event_sheet = loaded_sheet
		current_file_path = path
		_refresh_all_blocks()
		print("📁 Таблица событий загружена: %s" % path)
		_update_status_bar()
		blocks_changed.emit()
	else:
		_show_error("Ошибка загрузки: %s" % path)

func _update_status_bar():
	"""Обновляем статус бар"""
	var status_bar = find_child("*status*", false, false)
	if status_bar:
		var file_label = status_bar.get_child(0) as Label
		if file_label:
			var filename = current_file_path.get_file() if not current_file_path.is_empty() else "не выбран"
			file_label.text = "Файл: %s" % filename

func _show_error(message: String):
	"""Показываем ошибку пользователю"""
	push_error(message)
	print("❌ ОШИБКА: %s" % message)

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

func get_current_file_path() -> String:
	"""Возвращает текущий путь к файлу"""
	return current_file_path