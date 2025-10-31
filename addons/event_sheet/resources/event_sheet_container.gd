@tool
class_name EventSheetContainer
extends Resource

## Массив всех событий в таблице
@export var events: Array[EventResource] = []

## Название таблицы событий
@export var sheet_name: String = "Event Sheet"

## Описание таблицы событий
@export var description: String = ""

## Глобальные переменные, которые инициализируются при запуске
@export var global_variables: Dictionary = {}

## Получить количество событий
func get_events_count() -> int:
	return events.size()

## Получить события первого уровня (без подсобытий)
func get_root_events() -> Array[EventResource]:
	var root_events: Array[EventResource] = []
	for event in events:
		# Добавляем только события, которые не являются подсобытиями
		root_events.append(event)
	return root_events

## Получить все события, включая подсобытия (рекурсивно)
func get_all_events_recursive() -> Array[EventResource]:
	var all_events: Array[EventResource] = []
	
	for event in events:
		all_events.append(event)
		_collect_sub_events(event, all_events)
	
	return all_events

## Вспомогательный метод для рекурсивного сбора подсобытий
func _collect_sub_events(event: EventResource, result: Array[EventResource]) -> void:
	for sub_event in event.sub_events:
		result.append(sub_event)
		_collect_sub_events(sub_event, result)

## Визуальное представление контейнера
func get_display_text() -> String:
	return "%s (%d событий)" % [sheet_name, get_events_count()]

## Добавить событие
func add_event(event: EventResource) -> void:
	events.append(event)

## Удалить событие по индексу
func remove_event(index: int) -> void:
	if index >= 0 and index < events.size():
		events.remove_at(index)

## Вставить событие в определённую позицию
func insert_event(index: int, event: EventResource) -> void:
	if index >= 0 and index <= events.size():
		events.insert(index, event)
