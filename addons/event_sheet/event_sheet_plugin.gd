@tool
extends EditorPlugin

# Переменная для хранения экземпляра UI док-панели
var event_sheet_dock: Control = null

# Флаг для отладки
var debug_mode: bool = false

func _enter_tree() -> void:
	"""Вызывается при загрузке плагина в редактор"""
	print("EventSheet Plugin загружен успешно!")
	
	# Загружаем сцену с интерфейсом
	var ui_scene = preload("res://addons/event_sheet/ui/event_sheet_ui.tscn")
	
	# Создаём экземпляр UI сцены
	event_sheet_dock = ui_scene.instantiate()
	
	# Добавляем UI как док-панель в левую часть редактора
	add_control_to_dock(DOCK_SLOT_LEFT_UL, event_sheet_dock)
	
	print("EventSheet UI док-панель добавлена в редактор")


func _exit_tree() -> void:
	"""Вызывается при выгрузке плагина из редактора"""
	# Если док-панель была создана, удаляем её
	if event_sheet_dock != null:
		remove_control_from_docks(event_sheet_dock)
		event_sheet_dock.queue_free()
		event_sheet_dock = null
	
	print("EventSheet Plugin выгружен!")


func _handles(object: Object) -> bool:
	"""Определяет, может ли плагин редактировать данный объект"""
	# Только JSON файлы с расширением .json
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
			
			# Загружаем JSON в редактор
			if event_sheet_dock and event_sheet_dock.has_method("load_json"):
				event_sheet_dock.load_json(file_path)


func _make_visible(visible: bool) -> void:
	"""Вызывается при показе/скрытии плагина"""
	if event_sheet_dock:
		event_sheet_dock.visible = visible
