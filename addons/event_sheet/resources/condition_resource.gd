@tool
class_name ConditionResource
extends Resource

## Название условия (например: "Is on floor", "Key pressed")
@export var condition_name: String = ""

## Тип объекта, к которому применяется условие (например: "Player", "Enemy")
@export var target_object: String = ""

## Параметры условия в виде словаря (ключ-значение)
## Например: {"key": "SPACE"} для "Key pressed"
@export var parameters: Dictionary = {}

## Флаг для инвертирования условия (NOT)
@export var inverted: bool = false

## Визуальное представление условия в редакторе
func get_display_text() -> String:
	var text = ""
	if target_object:
		text = "%s: %s" % [target_object, condition_name]
	else:
		text = condition_name
	
	if inverted:
		text = "NOT (%s)" % text
	
	return text
