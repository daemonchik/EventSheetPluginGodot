class_name EventSheetData

## Класс для работы с JSON данными событий

## Структура условия
class Condition:
	var condition_name: String = ""
	var target_object: String = ""
	var parameters: Dictionary = {}
	var inverted: bool = false
	
	func to_dict() -> Dictionary:
		return {
			"condition_name": condition_name,
			"target_object": target_object,
			"parameters": parameters,
			"inverted": inverted
		}
	
	static func from_dict(data: Dictionary) -> Condition:
		var condition = Condition.new()
		condition.condition_name = data.get("condition_name", "")
		condition.target_object = data.get("target_object", "")
		condition.parameters = data.get("parameters", {})
		condition.inverted = data.get("inverted", false)
		return condition
	
	func get_display_text() -> String:
		var text = ""
		if target_object:
			text = "%s: %s" % [target_object, condition_name]
		else:
			text = condition_name
		
		if inverted:
			text = "NOT (%s)" % text
		
		return text


## Структура действия
class Action:
	var action_name: String = ""
	var target_object: String = ""
	var parameters: Dictionary = {}
	
	func to_dict() -> Dictionary:
		return {
			"action_name": action_name,
			"target_object": target_object,
			"parameters": parameters
		}
	
	static func from_dict(data: Dictionary) -> Action:
		var action = Action.new()
		action.action_name = data.get("action_name", "")
		action.target_object = data.get("target_object", "")
		action.parameters = data.get("parameters", {})
		return action
	
	func get_display_text() -> String:
		var text = ""
		if target_object:
			text = "%s: %s" % [target_object, action_name]
		else:
			text = action_name
		
		if not parameters.is_empty():
			var first_param = parameters.values()[0]
			text += " (%s)" % str(first_param)
		
		return text


## Структура события
class Event:
	var event_name: String = "Event"
	var comment: String = ""
	var enabled: bool = true
	var conditions: Array[Condition] = []
	var actions: Array[Action] = []
	var sub_events: Array[Event] = []
	
	func to_dict() -> Dictionary:
		var conditions_array = []
		for condition in conditions:
			conditions_array.append(condition.to_dict())
		
		var actions_array = []
		for action in actions:
			actions_array.append(action.to_dict())
		
		var sub_events_array = []
		for sub_event in sub_events:
			sub_events_array.append(sub_event.to_dict())
		
		return {
			"event_name": event_name,
			"comment": comment,
			"enabled": enabled,
			"conditions": conditions_array,
			"actions": actions_array,
			"sub_events": sub_events_array
		}
	
	static func from_dict(data: Dictionary) -> Event:
		var event = Event.new()
		event.event_name = data.get("event_name", "Event")
		event.comment = data.get("comment", "")
		event.enabled = data.get("enabled", true)
		
		for condition_data in data.get("conditions", []):
			event.conditions.append(Condition.from_dict(condition_data))
		
		for action_data in data.get("actions", []):
			event.actions.append(Action.from_dict(action_data))
		
		for sub_event_data in data.get("sub_events", []):
			event.sub_events.append(Event.from_dict(sub_event_data))
		
		return event
	
	func get_display_text() -> String:
		var text = event_name
		var cond_count = conditions.size()
		var act_count = actions.size()
		
		text += " [Условий: %d | Действий: %d]" % [cond_count, act_count]
		
		if not enabled:
			text = "[ОТКЛЮЧЕНО] " + text
		
		if comment:
			text += " // %s" % comment
		
		return text


## Структура контейнера событий
class EventSheet:
	var sheet_name: String = "Event Sheet"
	var description: String = ""
	var events: Array[Event] = []
	var global_variables: Dictionary = {}
	
	func to_dict() -> Dictionary:
		var events_array = []
		for event in events:
			events_array.append(event.to_dict())
		
		return {
			"sheet_name": sheet_name,
			"description": description,
			"events": events_array,
			"global_variables": global_variables
		}
	
	static func from_dict(data: Dictionary) -> EventSheet:
		var sheet = EventSheet.new()
		sheet.sheet_name = data.get("sheet_name", "Event Sheet")
		sheet.description = data.get("description", "")
		sheet.global_variables = data.get("global_variables", {})
		
		for event_data in data.get("events", []):
			sheet.events.append(Event.from_dict(event_data))
		
		return sheet
	
	func get_events_count() -> int:
		return events.size()
	
	func get_display_text() -> String:
		return "%s (%d событий)" % [sheet_name, get_events_count()]
	
	func add_event(event: Event) -> void:
		events.append(event)
	
	func remove_event(index: int) -> void:
		if index >= 0 and index < events.size():
			events.remove_at(index)
	
	func insert_event(index: int, event: Event) -> void:
		if index >= 0 and index <= events.size():
			events.insert(index, event)


## Методы для работы с JSON файлами
class FileManager:
	
	## Сохранить EventSheet в JSON файл
	static func save_to_file(sheet: EventSheet, file_path: String) -> bool:
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file == null:
			push_error("Не удалось открыть файл: %s" % file_path)
			return false
		
		var json_data = JSON.stringify(sheet.to_dict(), "\t")
		file.store_string(json_data)
		print("EventSheet сохранён: %s" % file_path)
		return true
	
	## Загрузить EventSheet из JSON файла
	static func load_from_file(file_path: String) -> EventSheet:
		if not ResourceLoader.exists(file_path):
			push_error("Файл не найден: %s" % file_path)
			return null
		
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			push_error("Не удалось открыть файл: %s" % file_path)
			return null
		
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		
		if error != OK:
			push_error("Ошибка парсинга JSON: %s" % file_path)
			return null
		
		var data = json.data
		if data == null or data is not Dictionary:
			push_error("Некорректный формат JSON: %s" % file_path)
			return null
		
		print("EventSheet загружен: %s" % file_path)
		return EventSheet.from_dict(data)
