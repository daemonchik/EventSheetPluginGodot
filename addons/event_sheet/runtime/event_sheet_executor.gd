extends Node

class_name EventSheetExecutor

## Путь к JSON файлу с таблицей событий
@export var event_sheet_path: String = ""

## Загруженный контейнер событий
var event_sheet: EventSheetData.EventSheet = null

## Кэш переменных
var instance_variables: Dictionary = {}
var global_variables: Dictionary = {}
var trigger_state: Dictionary = {}
var layout_started: bool = false
var debug_mode: bool = false

func _ready() -> void:
	"""Инициализация при загрузке узла"""
	if event_sheet_path.is_empty():
		push_error("EventSheetExecutor: event_sheet_path не установлен!")
		return
	
	# Загружаем JSON файл
	event_sheet = EventSheetData.FileManager.load_from_file(event_sheet_path)
	
	if event_sheet == null:
		push_error("EventSheetExecutor: Не удалось загрузить %s" % event_sheet_path)
		return
	
	_initialize_variables()
	
	if debug_mode:
		print("EventSheetExecutor инициализирован с: %s" % event_sheet_path)


func _process(delta: float) -> void:
	"""Обработка событий каждый кадр"""
	if event_sheet == null:
		return
	
	_execute_events(event_sheet.events, delta)


## Инициализация переменных
func _initialize_variables() -> void:
	global_variables = event_sheet.global_variables.duplicate()
	if debug_mode:
		print("Инициализированы переменные: %s" % global_variables)


## Главный метод выполнения событий
func _execute_events(events: Array[EventSheetData.Event], delta: float) -> void:
	for event in events:
		if not event.enabled:
			continue
		
		if _check_conditions(event.conditions):
			_execute_actions(event.actions)
			
			if not event.sub_events.is_empty():
				_execute_events(event.sub_events, delta)


## Проверка условий
func _check_conditions(conditions: Array[EventSheetData.Condition]) -> bool:
	if conditions.is_empty():
		return true
	
	for condition in conditions:
		var result = _evaluate_condition(condition)
		
		if condition.inverted:
			result = not result
		
		if not result:
			return false
	
	return true


## Оценка одного условия
func _evaluate_condition(condition: EventSheetData.Condition) -> bool:
	match condition.condition_name:
		"Start of layout":
			if not layout_started:
				layout_started = true
				return true
			return false
		
		"Every tick":
			return true
		
		"Key pressed":
			var key_name = condition.parameters.get("key", "SPACE")
			var key_map = {
				"SPACE": KEY_SPACE,
				"ENTER": KEY_ENTER,
				"ESC": KEY_ESCAPE,
				"LEFT": KEY_LEFT,
				"RIGHT": KEY_RIGHT,
				"UP": KEY_UP,
				"DOWN": KEY_DOWN,
			}
			var key = key_map.get(key_name, KEY_SPACE)
			return Input.is_key_pressed(key)
		
		_:
			return false


## Выполнение действий
func _execute_actions(actions: Array[EventSheetData.Action]) -> void:
	for action in actions:
		_execute_action(action)


## Выполнение одного действия
func _execute_action(action: EventSheetData.Action) -> void:
	match action.action_name:
		"Set variable":
			var var_name = action.parameters.get("variable", "")
			var value = action.parameters.get("value", 0)
			var operation = action.parameters.get("operation", "set")
			
			match operation:
				"set":
					global_variables[var_name] = value
				"add":
					global_variables[var_name] = global_variables.get(var_name, 0) + value
				"subtract":
					global_variables[var_name] = global_variables.get(var_name, 0) - value
			
			if debug_mode:
				print("Переменная '%s' = %s" % [var_name, global_variables[var_name]])
		
		_:
			if debug_mode:
				print("Неизвестное действие: %s" % action.action_name)


## Получить переменную
func get_variable(var_name: String) -> Variant:
	return global_variables.get(var_name, null)


## Установить переменную
func set_variable(var_name: String, value: Variant) -> void:
	global_variables[var_name] = value
