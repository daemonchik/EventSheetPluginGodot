extends Resource
class_name WEvent

@export var id: String
@export var title: String
@export var icon: Texture2D
@export var description: String
@export var parameters: Dictionary
@export var conditions: Array[WCondition]  # Условия, которые должны быть выполнены
@export var group: String
@export var enabled: bool = true  # Включено ли событие
