extends RefCounted

class_name EventSheetUndoRedo

## История действий для Undo/Redo
var history: Array = []
var history_index: int = -1
var max_history: int = 100

## Сохранить состояние в историю
func save_state(container: EventSheetData.EventSheet) -> void:
	# Удаляем все действия после текущей позиции (если были откаты)
	if history_index < history.size() - 1:
		history.resize(history_index + 1)
	
	# Сохраняем копию состояния
	var state = container.to_dict()
	history.append(state)
	history_index = history.size() - 1
	
	# Ограничиваем размер истории
	if history.size() > max_history:
		history.pop_front()
		history_index -= 1
	
	print("State saved. History size: %d" % history.size())


## Отменить последнее действие
func undo(container: EventSheetData.EventSheet) -> bool:
	if history_index > 0:
		history_index -= 1
		var state = history[history_index]
		_restore_state(container, state)
		return true
	return false


## Повторить отменённое действие
func redo(container: EventSheetData.EventSheet) -> bool:
	if history_index < history.size() - 1:
		history_index += 1
		var state = history[history_index]
		_restore_state(container, state)
		return true
	return false


## Проверить можно ли отменить
func can_undo() -> bool:
	return history_index > 0


## Проверить можно ли повторить
func can_redo() -> bool:
	return history_index < history.size() - 1


## Восстановить состояние из снимка
func _restore_state(container: EventSheetData.EventSheet, state: Dictionary) -> void:
	var restored = EventSheetData.EventSheet.from_dict(state)
	container.sheet_name = restored.sheet_name
	container.description = restored.description
	container.events = restored.events
	container.global_variables = restored.global_variables
