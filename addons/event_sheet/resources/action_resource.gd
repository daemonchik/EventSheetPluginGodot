@tool
class_name ActionResource
extends Resource

## Название действия (например: "Create object", "Set position")
@export var action_name: String = ""

## Тип объекта, на который будет воздействовать действие
@export var target_object: String = ""

## Параметры действия в виде словаря (ключ-значение)
## Например: {"x": 100, "y": 200} для "Set position"
@export var parameters: Dictionary = {}

## Визуальное представление действия в редакторе
func get_display_text() -> String:
	var text = ""
	if target_object:
		text = "%s: %s" % [target_object, action_name]
	else:
		text = action_name
	
	# Добавляем первый параметр, если он есть
	if not parameters.is_empty():
		var first_param = parameters.values()[0]
		text += " (%s)" % str(first_param)
	
	return text
