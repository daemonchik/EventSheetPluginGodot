@tool
extends ConfirmationDialog

class_name ActionPickerDialog

## Сигнал, который испускается при выборе действия
signal action_selected(action_name: String, target_object: String)

## Дерево для выбора действий
var actions_tree: Tree
var root_item: TreeItem

## Список доступных действий по категориям
var actions_data = {
	"System": [
		{"name": "Set variable", "object": ""},
		{"name": "Wait", "object": ""},
		{"name": "Go to layout", "object": ""},
		{"name": "Restart layout", "object": ""},
	],
	"Object": [
		{"name": "Create object", "object": ""},
		{"name": "Destroy", "object": ""},
		{"name": "Set position", "object": ""},
		{"name": "Move at angle", "object": ""},
		{"name": "Set animation", "object": ""},
	],
	"Physics": [
		{"name": "Apply impulse", "object": ""},
		{"name": "Set velocity", "object": ""},
	],
	"Audio": [
		{"name": "Play sound", "object": ""},
		{"name": "Stop sound", "object": ""},
		{"name": "Set volume", "object": ""},
	],
}

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	
	title = "Select Action"
	size = Vector2i(400, 400)
	ok_button_text = "Add"
	cancel_button_text = "Cancel"
	
	# Создаём дерево для выбора
	actions_tree = Tree.new()
	actions_tree.hide_root = false
	actions_tree.allow_rmb_select = true
	add_child(actions_tree)
	
	# Подключаем сигнал
	confirmed.connect(_on_confirmed)
	
	# Заполняем дерево действиями
	_populate_actions_tree()


func _populate_actions_tree() -> void:
	actions_tree.clear()
	root_item = actions_tree.create_item()
	root_item.set_text(0, "Available Actions")
	
	# Проходим по всем категориям
	for category in actions_data.keys():
		var category_item = actions_tree.create_item(root_item)
		category_item.set_text(0, category)
		category_item.set_custom_color(0, Color.LIGHT_GREEN)
		
		# Добавляем действия в категорию
		for action in actions_data[category]:
			var action_item = actions_tree.create_item(category_item)
			action_item.set_text(0, action["name"])
			action_item.set_metadata(0, action)


func _on_confirmed() -> void:
	var selected = actions_tree.get_selected()
	
	if selected == null:
		push_error("No action selected")
		return
	
	var action_data = selected.get_metadata(0)
	
	if action_data is Dictionary:
		var action_name = action_data.get("name", "")
		var target_object = action_data.get("object", "")
		
		action_selected.emit(action_name, target_object)


func show_dialog() -> void:
	popup_centered()
