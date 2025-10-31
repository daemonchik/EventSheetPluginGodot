@tool
class_name EventResource
extends Resource

## Список условий для данного события
## Все условия должны быть истинными для выполнения событий
@export var conditions: Array[ConditionResource] = []

## Список действий, которые выполняются если все условия истинны
@export var actions: Array[ActionResource] = []

## Название события (для удобства организации)
@export var event_name: String = "Event"

## Комментарий к событию
@export var comment: String = ""

## Флаг для отключения события
@export var enabled: bool = true

## Вложенные события (подсобытия)
@export var sub_events: Array[EventResource] = []

## Получить статус события в виде текста
func get_status_text() -> String:
	if not enabled:
		return "[DISABLED]"
	return ""

## Подсчитать количество условий
func get_conditions_count() -> int:
	return conditions.size()

## Подсчитать количество действий
func get_actions_count() -> int:
	return actions.size()

## Визуальное представление события
func get_display_text() -> String:
	var text = event_name
	var cond_count = get_conditions_count()
	var act_count = get_actions_count()
	
	text += " [Условий: %d | Действий: %d]" % [cond_count, act_count]
	
	if not enabled:
		text = "[ОТКЛЮЧЕНО] " + text
	
	if comment:
		text += " // %s" % comment
	
	return text
