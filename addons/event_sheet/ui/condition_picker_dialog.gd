@tool
extends ConfirmationDialog

class_name ConditionPickerDialog

## Сигнал, который испускается при выборе условия
signal condition_selected(condition_name: String, target_object: String)

## Дерево для выбора условий
var conditions_tree: Tree
var root_item: TreeItem

## Список доступных условий по категориям
var conditions_data = {
	"System": [
		{"name": "Start of layout", "object": ""},
		{"name": "Every tick", "object": ""},
		{"name": "Compare variable", "object": ""},
		{"name": "Trigger once while true", "object": ""},
	],
	"Input": [
		{"name": "Key pressed", "object": ""},
		{"name": "Mouse button down", "object": ""},
		{"name": "On tap", "object": ""},
	],
	"Object": [
		{"name": "Is on floor", "object": "Player"},
		{"name": "On collision", "object": "Player"},
		{"name": "Out of bounds", "object": ""},
	],
	"Physics": [
		{"name": "Is overlapping", "object": ""},
		{"name": "Distance to object", "object": ""},
	],
}

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	
	title = "Select Condition"
	size = Vector2i(400, 400)
	ok_button_text = "Add"
	cancel_button_text = "Cancel"
	
	# Создаём дерево для выбора
	conditions_tree = Tree.new()
	conditions_tree.hide_root = false
	conditions_tree.allow_rmb_select = true
	add_child(conditions_tree)
	
	# Подключаем сигнал
	confirmed.connect(_on_confirmed)
	
	# Заполняем дерево условиями
	_populate_conditions_tree()


func _populate_conditions_tree() -> void:
	conditions_tree.clear()
	root_item = conditions_tree.create_item()
	root_item.set_text(0, "Available Conditions")
	
	# Проходим по всем категориям
	for category in conditions_data.keys():
		var category_item = conditions_tree.create_item(root_item)
		category_item.set_text(0, category)
		category_item.set_custom_color(0, Color.LIGHT_BLUE)
		
		# Добавляем условия в категорию
		for condition in conditions_data[category]:
			var condition_item = conditions_tree.create_item(category_item)
			condition_item.set_text(0, condition["name"])
			condition_item.set_metadata(0, condition)


func _on_confirmed() -> void:
	var selected = conditions_tree.get_selected()
	
	if selected == null:
		push_error("No condition selected")
		return
	
	var condition_data = selected.get_metadata(0)
	
	if condition_data is Dictionary:
		var condition_name = condition_data.get("name", "")
		var target_object = condition_data.get("object", "")
		
		condition_selected.emit(condition_name, target_object)


func show_dialog() -> void:
	popup_centered()
