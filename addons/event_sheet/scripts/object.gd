extends Button
class_name WObject

@export var group_resource: WGroup
@export var new_data: Dictionary = {}
var blank_body

func init_object(resource, icon_texture: TextureRect, group_label: Label, label: Label) -> void:
	if group_resource and resource:
		icon_texture.texture = group_resource.icon
		group_label.text = group_resource.title
		if resource.parameters.size() > 0:
			label.text = "{0}: ".format([resource.title])
			var i = 1
			for key in resource.parameters:
				var param_info = _get_parameter_info(resource.parameters, key)
				var default_value = param_info.default
				var new_value = new_data.get(key, default_value)  # Используем get() с правильным дефолтным значением

				label.text += "{0} - {1}".format([str(key), str(new_value)])

				if i < resource.parameters.size():
					label.text += ", "
				i += 1
		else:
			label.text = "{0}".format([resource.title])

func _get_parameter_info(parameters: Dictionary, key: String) -> Dictionary:
	"""Получает информацию о параметре (тип, значение по умолчанию, описание)"""
	var param_value = parameters[key]

	# Новый формат: {"type": TYPE_INT, "default": 5, "description": "Count"}
	if param_value is Dictionary:
		return {
			"type": param_value.get("type", TYPE_STRING),
			"default": param_value.get("default", ""),
			"description": param_value.get("description", ""),
			"min": param_value.get("min"),
			"max": param_value.get("max"),
			"step": param_value.get("step", 1.0)
		}
	# Старый формат: "default_value"
	else:
		var param_type = TYPE_STRING
		if param_value is int:
			param_type = TYPE_INT
		elif param_value is float:
			param_type = TYPE_FLOAT
		elif param_value is bool:
			param_type = TYPE_BOOL

		return {
			"type": param_type,
			"default": param_value,
			"description": "",
			"min": null,
			"max": null,
			"step": 1.0
		}

func _save(resource: Resource) -> Dictionary:
	var data: Dictionary = {
		"group_resource_path": group_resource.resource_path,
		"resource_path": resource.resource_path,
		"new_parametrs": new_data
	}
	return data

func _apply_theme(theme: Dictionary) -> void:
	"""Применяет тему к элементу"""
	if not theme:
		return

	# Применяем цвета к кнопке
	var normal_style = get_theme_stylebox("normal").duplicate()
	if normal_style is StyleBoxFlat:
		normal_style.bg_color = theme.get("element_normal", Color(0.25, 0.28, 0.32, 1))
	add_theme_stylebox_override("normal", normal_style)

	var hover_style = get_theme_stylebox("hover").duplicate()
	if hover_style is StyleBoxFlat:
		hover_style.bg_color = theme.get("element_hover", Color(0.3, 0.33, 0.38, 1))
	add_theme_stylebox_override("hover", hover_style)

	var pressed_style = get_theme_stylebox("pressed").duplicate()
	if pressed_style is StyleBoxFlat:
		pressed_style.bg_color = theme.get("element_pressed", Color(0.2, 0.23, 0.27, 1))
	add_theme_stylebox_override("pressed", pressed_style)

	# Применяем цвета к дочерним элементам
	_apply_theme_to_children(self, theme)

func _apply_theme_to_children(node: Node, theme: Dictionary) -> void:
	"""Рекурсивно применяет тему ко всем дочерним элементам"""
	for child in node.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", theme.get("text_color", Color(0.9, 0.9, 0.9, 1)))
		elif child is TextureRect:
			# Иконки оставляем без изменений
			pass
		elif child is ColorRect:
			# Индикаторы включения/отключения
			if child.name == "EnabledIndicator":
				if child.color.a > 0.5:  # Зеленый (включен)
					child.color = theme.get("success_color", Color(0.2, 0.8, 0.2, 1))
				else:  # Красный (отключен)
					child.color = theme.get("error_color", Color(0.9, 0.3, 0.3, 1))
		elif child is TextEdit:
			child.add_theme_color_override("font_color", theme.get("text_color", Color(0.9, 0.9, 0.9, 1)))
			var text_bg = StyleBoxFlat.new()
			text_bg.bg_color = theme.get("comment_color", Color(0.25, 0.28, 0.35, 1))
			child.add_theme_stylebox_override("normal", text_bg)

		# Рекурсивно применяем к дочерним элементам
		_apply_theme_to_children(child, theme)

func _on_mouse_entered() -> void:
	"""Обработчик наведения курсора - добавляет hover анимацию"""
	# Анимация hover удалена

func _on_mouse_exited() -> void:
	"""Обработчик ухода курсора - убирает hover анимацию"""
	# Анимация hover удалена

func _ready() -> void:
	# Подключаем сигналы для hover эффектов
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)

	# Анимация появления при создании (удалена)
