@tool
extends EditorPlugin

# Переменная для хранения экземпляра UI док-панели
var improved_event_dock: Control = null

# Флаг для отладки
var debug_mode: bool = true

func _enter_tree() -> void:
	"""Вызывается при загрузке плагина в редактор"""
	print("🚀 Improved EventSheet Plugin загружен успешно!")
	
	# Создаём UI
	_create_ui()
	
	if improved_event_dock:
		# Добавляем UI как док-панель в левую часть редактора
		add_control_to_dock(DOCK_SLOT_LEFT_UL, improved_event_dock)
		print("✅ Improved EventSheet UI док-панель добавлена в редактор")
	else:
		push_error("❌ Не удалось создать UI для плагина")

func _create_ui():
	"""Создаём UI с проверками на ошибки"""
	# Пробуем загрузить сцену
	var ui_scene_path = "res://addons/event_sheet/ui/improved_event_ui.tscn"
	
	if FileAccess.file_exists(ui_scene_path):
		var ui_scene = load(ui_scene_path)
		if ui_scene:
			improved_event_dock = ui_scene.instantiate()
			if debug_mode:
				print("📄 UI загружен из сцены: %s" % ui_scene_path)
		else:
			push_error("Не удалось загрузить сцену: %s" % ui_scene_path)
			_create_ui_programmatically()
	else:
		if debug_mode:
			print("⚠️ Сцена UI не найдена, создаем программно")
		_create_ui_programmatically()

func _create_ui_programmatically():
	"""Создаем UI программно если сцена не найдена"""
	var ui_script_path = "res://addons/event_sheet/ui/improved_ui.gd"
	
	if FileAccess.file_exists(ui_script_path):
		var ui_script = load(ui_script_path)
		if ui_script:
			improved_event_dock = ui_script.new()
			improved_event_dock.name = "ImprovedEventSheetUI"
			if debug_mode:
				print("🔧 UI создан программно")
		else:
			push_error("Не удалось загрузить скрипт UI: %s" % ui_script_path)
	else:
		push_error("Скрипт UI не найден: %s" % ui_script_path)

func _exit_tree() -> void:
	"""Вызывается при выгрузке плагина из редактора"""
	# Если док-панель была создана, удаляем её
	if improved_event_dock != null:
		remove_control_from_docks(improved_event_dock)
		improved_event_dock.queue_free()
		improved_event_dock = null
	
	print("👋 Improved EventSheet Plugin выгружен!")

func _handles(object: Object) -> bool:
	"""Определяет, может ли плагин редактировать данный объект"""
	if object is Resource:
		var resource = object as Resource
		var path = resource.resource_path
		
		# JSON файлы с расширением .json
		if path.ends_with(".json"):
			if debug_mode:
				print("🎯 Может редактировать: %s" % path)
			return true
	
	return false

func _edit(object: Object) -> void:
	"""Вызывается при выборе объекта для редактирования"""
	if not object is Resource:
		return
	
	var resource = object as Resource
	var file_path = resource.resource_path
	
	if not file_path.ends_with(".json"):
		return
	
	if debug_mode:
		print("📝 Редактируем JSON: %s" % file_path)
	
	# Загружаем JSON в улучшенный редактор
	if improved_event_dock and improved_event_dock.has_method("load_json"):
		improved_event_dock.load_json(file_path)
		if debug_mode:
			print("✅ JSON загружен в редактор")
	else:
		push_error("UI не готов или не имеет метода load_json")

func _make_visible(visible: bool) -> void:
	"""Вызывается при показе/скрытии плагина"""
	if improved_event_dock:
		improved_event_dock.visible = visible

# Дополнительные методы для интеграции

func get_dock_ui() -> Control:
	"""Возвращает UI док-панели для внешнего доступа"""
	return improved_event_dock

func create_executor_for_scene() -> Node:
	"""Создает исполнитель событий для текущей сцены"""
	var executor_script_path = "res://addons/event_sheet/runtime/improved_executor.gd"
	
	if not FileAccess.file_exists(executor_script_path):
		push_error("Скрипт исполнителя не найден: %s" % executor_script_path)
		return null
	
	var executor_script = load(executor_script_path)
	if not executor_script:
		push_error("Не удалось загрузить скрипт исполнителя")
		return null
	
	var executor = executor_script.new()
	executor.name = "EventExecutor"
	
	# Автоматически устанавливаем путь к JSON файлу если он есть
	if improved_event_dock and improved_event_dock.has_method("get_current_file_path"):
		var current_file = improved_event_dock.call("get_current_file_path")
		if current_file and not current_file.is_empty():
			executor.event_sheet_path = current_file
	
	return executor

func add_executor_to_scene():
	"""Добавляет исполнитель событий к текущей сцене"""
	var edited_scene = EditorInterface.get_edited_scene_root()
	if edited_scene == null:
		print("⚠️ Нет редактируемой сцены")
		return
	
	# Проверяем есть ли уже исполнитель
	var existing_executor = edited_scene.get_node_or_null("EventExecutor")
	if existing_executor:
		print("ℹ️ EventExecutor уже добавлен к сцене")
		return
	
	# Создаем и добавляем исполнитель
	var executor = create_executor_for_scene()
	if executor:
		edited_scene.add_child(executor)
		executor.owner = edited_scene
		print("✅ EventExecutor добавлен к сцене: %s" % edited_scene.name)
	else:
		push_error("Не удалось создать исполнитель")

# Методы отладки

func print_debug_info():
	"""Выводит отладочную информацию о плагине"""
	print("=== DEBUG INFO: Improved EventSheet Plugin ===")
	print("UI создан: %s" % ("✅" if improved_event_dock != null else "❌"))
	print("Debug режим: %s" % ("🔧" if debug_mode else "🚫"))
	
	if improved_event_dock:
		print("UI класс: %s" % improved_event_dock.get_class())
		print("UI имя: %s" % improved_event_dock.name)
	
	var edited_scene = EditorInterface.get_edited_scene_root()
	if edited_scene:
		print("Текущая сцена: %s" % edited_scene.name)
		var executor = edited_scene.get_node_or_null("EventExecutor")
		print("Исполнитель в сцене: %s" % ("✅" if executor != null else "❌"))
	else:
		print("Текущая сцена: отсутствует")
	
	print("===============================================")