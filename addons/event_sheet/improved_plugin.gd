@tool
extends EditorPlugin

# Переменная для хранения экземпляра UI док-панели
var improved_event_dock: Control = null

# Флаг для отладки
var debug_mode: bool = false

func _enter_tree() -> void:
	"""Вызывается при загрузке плагина в редактор"""
	print("Improved EventSheet Plugin загружен успешно!")
	
	# Загружаем сцену с улучшенным интерфейсом
	var ui_scene = preload("res://addons/event_sheet/ui/improved_event_ui.tscn")
	
	# Создаём экземпляр UI сцены
	if ui_scene == null:
		# Если сцена не найдена, создаем UI программно
		_create_ui_programmatically()
	else:
		improved_event_dock = ui_scene.instantiate()
	
	# Добавляем UI как док-панель в левую часть редактора
	add_control_to_dock(DOCK_SLOT_LEFT_UL, improved_event_dock)
	
	print("Improved EventSheet UI док-панель добавлена в редактор")

func _create_ui_programmatically():
	"""Создаем UI программно если сцена не найдена"""
	improved_event_dock = preload("res://addons/event_sheet/ui/improved_ui.gd").new()
	improved_event_dock.name = "ImprovedEventSheetUI"

func _exit_tree() -> void:
	"""Вызывается при выгрузке плагина из редактора"""
	# Если док-панель была создана, удаляем её
	if improved_event_dock != null:
		remove_control_from_docks(improved_event_dock)
		improved_event_dock.queue_free()
		improved_event_dock = null
	
	print("Improved EventSheet Plugin выгружен!")

func _handles(object: Object) -> bool:
	"""Определяет, может ли плагин редактировать данный объект"""
	# JSON файлы с расширением .json
	if object is Resource:
		var resource = object as Resource
		var path = resource.resource_path
		
		# Проверяем расширение файла
		if path.ends_with(".json"):
			return true
	
	return false

func _edit(object: Object) -> void:
	"""Вызывается при выборе объекта для редактирования"""
	if object is Resource:
		var resource = object as Resource
		var file_path = resource.resource_path
		
		if file_path.ends_with(".json"):
			if debug_mode:
				print("Редактируем JSON: %s" % file_path)
			
			# Загружаем JSON в улучшенный редактор
			if improved_event_dock and improved_event_dock.has_method("load_json"):
				improved_event_dock.load_json(file_path)

func _make_visible(visible: bool) -> void:
	"""Вызывается при показе/скрытии плагина"""
	if improved_event_dock:
		improved_event_dock.visible = visible

# Дополнительные методы для интеграции

func get_dock_ui() -> Control:
	"""Возвращает UI док-панели для внешнего доступа"""
	return improved_event_dock

func create_executor_for_scene() -> ImprovedEventExecutor:
	"""Создает исполнитель событий для текущей сцены"""
	var executor = preload("res://addons/event_sheet/runtime/improved_executor.gd").new()
	executor.name = "EventExecutor"
	
	# Автоматически устанавливаем путь к JSON файлу если он есть
	if improved_event_dock and improved_event_dock.has_method("get_current_file"):
		var current_file = improved_event_dock.current_file_path
		if not current_file.is_empty():
			executor.event_sheet_path = current_file
	
	return executor

func add_executor_to_scene():
	"""Добавляет исполнитель событий к текущей сцене"""
	var edited_scene = EditorInterface.get_edited_scene_root()
	if edited_scene == null:
		print("Нет редактируемой сцены")
		return
	
	# Проверяем есть ли уже исполнитель
	var existing_executor = edited_scene.get_node_or_null("EventExecutor")
	if existing_executor:
		print("EventExecutor уже добавлен к сцене")
		return
	
	# Создаем и добавляем исполнитель
	var executor = create_executor_for_scene()
	edited_scene.add_child(executor)
	executor.owner = edited_scene
	
	print("EventExecutor добавлен к сцене: %s" % edited_scene.name)