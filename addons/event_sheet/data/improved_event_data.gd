@tool
class_name ImprovedEventData

## Основной блок события: Объект → Условие → Действие
class EventBlock:
	var target_object: String = ""  # Путь к узлу или имя группы
	var object_type: String = ""    # Тип объекта для фильтрации
	var condition: EventCondition = null
	var actions: Array[EventAction] = []
	var enabled: bool = true
	var comment: String = ""
	var block_id: String = ""  # Уникальный ID блока
	
	func get_target_node() -> Node:
		if target_object.is_empty():
			return null
		
		var scene_tree = Engine.get_main_loop() as SceneTree
		if scene_tree == null or scene_tree.current_scene == null:
			return null
		
		# Поиск по пути
		var node = scene_tree.current_scene.get_node_or_null(target_object)
		if node != null:
			return node
		
		# Поиск по группе
		var nodes = scene_tree.get_nodes_in_group(target_object)
		if nodes.size() > 0:
			return nodes[0]
		
		return null
	
	func to_dict() -> Dictionary:
		var actions_array = []
		for action in actions:
			actions_array.append(action.to_dict())
		
		return {
			"target_object": target_object,
			"object_type": object_type,
			"condition": condition.to_dict() if condition else {},
			"actions": actions_array,
			"enabled": enabled,
			"comment": comment,
			"block_id": block_id
		}
	
	static func from_dict(data: Dictionary) -> EventBlock:
		var block = EventBlock.new()
		block.target_object = data.get("target_object", "")
		block.object_type = data.get("object_type", "")
		block.enabled = data.get("enabled", true)
		block.comment = data.get("comment", "")
		block.block_id = data.get("block_id", "")
		
		var condition_data = data.get("condition", {})
		if not condition_data.is_empty():
			block.condition = EventCondition.from_dict(condition_data)
		
		for action_data in data.get("actions", []):
			block.actions.append(EventAction.from_dict(action_data))
		
		return block
	
	func get_display_text() -> String:
		var text = "%s" % target_object.get_file()
		if condition:
			text += " → %s" % condition.get_display_text()
		if actions.size() > 0:
			text += " → %s" % actions[0].get_display_text()
		if actions.size() > 1:
			text += " (+%d)" % (actions.size() - 1)
		return text


## Условие привязанное к конкретному узлу
class EventCondition:
	var condition_type: String = ""
	var parameters: Dictionary = {}
	var inverted: bool = false
	
	func evaluate(target_node: Node) -> bool:
		if target_node == null:
			return false
		
		var result = false
		
		match condition_type:
			"scene_ready":
				result = target_node.is_node_ready()
			
			"every_frame":
				result = true
			
			"key_pressed":
				var key = parameters.get("key", "")
				if key.is_empty():
					result = false
				else:
					result = Input.is_action_pressed(key)
			
			"button_pressed":
				if target_node is BaseButton:
					result = target_node.button_pressed
			
			"animation_finished":
				if target_node is AnimationPlayer:
					result = not target_node.is_playing()
			
			"collision_entered":
				# Подключается через сигналы
				result = target_node.has_meta("collision_detected")
			
			"is_on_floor":
				if target_node is CharacterBody2D:
					result = target_node.is_on_floor()
				elif target_node is CharacterBody3D:
					result = target_node.is_on_floor()
			
			"is_on_wall":
				if target_node is CharacterBody2D:
					result = target_node.is_on_wall()
				elif target_node is CharacterBody3D:
					result = target_node.is_on_wall()
			
			"mouse_entered":
				if target_node is Control:
					result = target_node.has_meta("mouse_entered")
			
			"variable_compare":
				var var_name = parameters.get("variable", "")
				var value = parameters.get("value", 0)
				var operation = parameters.get("operation", "==")
				
				if var_name.is_empty():
					result = false
				elif target_node.has_method("get") and var_name in target_node:
					var current_value = target_node.get(var_name)
					match operation:
						"==": result = current_value == value
						"!=": result = current_value != value
						">": result = current_value > value
						"<": result = current_value < value
						">=": result = current_value >= value
						"<=": result = current_value <= value
				else:
					result = false
			
			"timer_timeout":
				if target_node is Timer:
					result = target_node.is_stopped()
		
		return result if not inverted else not result
	
	func to_dict() -> Dictionary:
		return {
			"condition_type": condition_type,
			"parameters": parameters,
			"inverted": inverted
		}
	
	static func from_dict(data: Dictionary) -> EventCondition:
		var condition = EventCondition.new()
		condition.condition_type = data.get("condition_type", "")
		condition.parameters = data.get("parameters", {})
		condition.inverted = data.get("inverted", false)
		return condition
	
	func get_display_text() -> String:
		var text = ""
		match condition_type:
			"scene_ready": text = "Сцена готова"
			"every_frame": text = "Каждый кадр"
			"key_pressed": text = "Клавиша '%s' нажата" % parameters.get("key", "")
			"button_pressed": text = "Кнопка нажата"
			"animation_finished": text = "Анимация завершена"
			"collision_entered": text = "Столкновение"
			"is_on_floor": text = "На полу"
			"is_on_wall": text = "У стены"
			"mouse_entered": text = "Курсор вошел"
			"variable_compare": text = "Переменная %s %s %s" % [
				parameters.get("variable", ""),
				parameters.get("operation", "=="),
				parameters.get("value", 0)
			]
			"timer_timeout": text = "Таймер истек"
			_: text = condition_type
		
		if inverted:
			text = "НЕ (%s)" % text
		
		return text


## Действие выполняемое над конкретным узлом
class EventAction:
	var action_type: String = ""
	var parameters: Dictionary = {}
	var delay: float = 0.0
	
	func execute(target_node: Node) -> void:
		if target_node == null:
			push_warning("EventAction: target_node is null for action: %s" % action_type)
			return
		
		# Задержка если нужна
		if delay > 0.0:
			await target_node.get_tree().create_timer(delay).timeout
		
		match action_type:
			"set_position":
				if target_node is Node2D:
					var pos_data = parameters.get("position", {"x": 0, "y": 0})
					var pos = Vector2(pos_data.get("x", 0), pos_data.get("y", 0))
					target_node.position = pos
				elif target_node is Node3D:
					var pos_data = parameters.get("position", {"x": 0, "y": 0, "z": 0})
					var pos = Vector3(pos_data.get("x", 0), pos_data.get("y", 0), pos_data.get("z", 0))
					target_node.position = pos
			
			"move_by":
				if target_node is Node2D:
					var offset_data = parameters.get("offset", {"x": 0, "y": 0})
					var offset = Vector2(offset_data.get("x", 0), offset_data.get("y", 0))
					target_node.position += offset
				elif target_node is Node3D:
					var offset_data = parameters.get("offset", {"x": 0, "y": 0, "z": 0})
					var offset = Vector3(offset_data.get("x", 0), offset_data.get("y", 0), offset_data.get("z", 0))
					target_node.position += offset
			
			"set_rotation":
				if target_node is Node2D:
					var rot = parameters.get("rotation", 0.0)
					target_node.rotation = rot
				elif target_node is Node3D:
					var rot_data = parameters.get("rotation", {"x": 0, "y": 0, "z": 0})
					var rot = Vector3(rot_data.get("x", 0), rot_data.get("y", 0), rot_data.get("z", 0))
					target_node.rotation = rot
			
			"set_scale":
				if target_node is Node2D:
					var scale_data = parameters.get("scale", {"x": 1, "y": 1})
					var scale_val = Vector2(scale_data.get("x", 1), scale_data.get("y", 1))
					target_node.scale = scale_val
				elif target_node is Node3D:
					var scale_data = parameters.get("scale", {"x": 1, "y": 1, "z": 1})
					var scale_val = Vector3(scale_data.get("x", 1), scale_data.get("y", 1), scale_data.get("z", 1))
					target_node.scale = scale_val
			
			"play_animation":
				if target_node is AnimationPlayer:
					var anim_name = parameters.get("animation", "")
					if anim_name.is_empty() or not target_node.has_animation(anim_name):
						push_warning("Animation '%s' not found in %s" % [anim_name, target_node.name])
					else:
						target_node.play(anim_name)
			
			"stop_animation":
				if target_node is AnimationPlayer:
					target_node.stop()
			
			"set_text":
				var text_value = parameters.get("text", "")
				if target_node is Label:
					target_node.text = text_value
				elif target_node is Button:
					target_node.text = text_value
				elif target_node is LineEdit:
					target_node.text = text_value
			
			"set_visible":
				var visible = parameters.get("visible", true)
				target_node.visible = visible
			
			"play_sound":
				if target_node is AudioStreamPlayer:
					target_node.play()
				elif target_node is AudioStreamPlayer2D:
					target_node.play()
				elif target_node is AudioStreamPlayer3D:
					target_node.play()
			
			"stop_sound":
				if target_node is AudioStreamPlayer:
					target_node.stop()
				elif target_node is AudioStreamPlayer2D:
					target_node.stop()
				elif target_node is AudioStreamPlayer3D:
					target_node.stop()
			
			"set_volume":
				var volume = parameters.get("volume", 0.0)
				if target_node is AudioStreamPlayer:
					target_node.volume_db = volume
				elif target_node is AudioStreamPlayer2D:
					target_node.volume_db = volume
				elif target_node is AudioStreamPlayer3D:
					target_node.volume_db = volume
			
			"set_property":
				var prop_name = parameters.get("property", "")
				var value = parameters.get("value", null)
				if prop_name.is_empty():
					push_warning("Property name is empty for set_property action")
				elif target_node.has_method("set") and prop_name in target_node:
					target_node.set(prop_name, value)
				else:
					push_warning("Property '%s' not found in %s" % [prop_name, target_node.name])
			
			"call_method":
				var method_name = parameters.get("method", "")
				var args = parameters.get("args", [])
				if method_name.is_empty():
					push_warning("Method name is empty for call_method action")
				elif target_node.has_method(method_name):
					target_node.callv(method_name, args)
				else:
					push_warning("Method '%s' not found in %s" % [method_name, target_node.name])
			
			"emit_signal":
				var signal_name = parameters.get("signal", "")
				var args = parameters.get("args", [])
				if signal_name.is_empty():
					push_warning("Signal name is empty for emit_signal action")
				elif target_node.has_signal(signal_name):
					target_node.emit_signal(signal_name, args)
				else:
					push_warning("Signal '%s' not found in %s" % [signal_name, target_node.name])
			
			"apply_impulse":
				if target_node is RigidBody2D:
					var impulse_data = parameters.get("impulse", {"x": 0, "y": 0})
					var impulse = Vector2(impulse_data.get("x", 0), impulse_data.get("y", 0))
					target_node.apply_central_impulse(impulse)
				elif target_node is RigidBody3D:
					var impulse_data = parameters.get("impulse", {"x": 0, "y": 0, "z": 0})
					var impulse = Vector3(impulse_data.get("x", 0), impulse_data.get("y", 0), impulse_data.get("z", 0))
					target_node.apply_central_impulse(impulse)
			
			"set_velocity":
				if target_node is CharacterBody2D:
					var vel_data = parameters.get("velocity", {"x": 0, "y": 0})
					var velocity = Vector2(vel_data.get("x", 0), vel_data.get("y", 0))
					target_node.velocity = velocity
				elif target_node is CharacterBody3D:
					var vel_data = parameters.get("velocity", {"x": 0, "y": 0, "z": 0})
					var velocity = Vector3(vel_data.get("x", 0), vel_data.get("y", 0), vel_data.get("z", 0))
					target_node.velocity = velocity
			
			"destroy":
				target_node.queue_free()
			
			"instance_scene":
				var scene_path = parameters.get("scene", "")
				if scene_path.is_empty():
					push_warning("Scene path is empty for instance_scene action")
				elif not FileAccess.file_exists(scene_path):
					push_warning("Scene file not found: %s" % scene_path)
				else:
					var scene_resource = load(scene_path)
					if scene_resource:
						var instance = scene_resource.instantiate()
						var parent = target_node.get_parent() if target_node.get_parent() else target_node
						parent.add_child(instance)
			
			"change_scene":
				var scene_path = parameters.get("scene", "")
				if scene_path.is_empty():
					push_warning("Scene path is empty for change_scene action")
				elif not FileAccess.file_exists(scene_path):
					push_warning("Scene file not found: %s" % scene_path)
				else:
					target_node.get_tree().change_scene_to_file(scene_path)
			
			"print_message":
				var message = parameters.get("message", "")
				print("EventAction: %s" % message)
			
			"start_timer":
				if target_node is Timer:
					var time = parameters.get("time", 1.0)
					target_node.wait_time = time
					target_node.start()
			
			"stop_timer":
				if target_node is Timer:
					target_node.stop()
			
			_:
				push_warning("Unknown action type: %s" % action_type)
	
	func to_dict() -> Dictionary:
		return {
			"action_type": action_type,
			"parameters": parameters,
			"delay": delay
		}
	
	static func from_dict(data: Dictionary) -> EventAction:
		var action = EventAction.new()
		action.action_type = data.get("action_type", "")
		action.parameters = data.get("parameters", {})
		action.delay = data.get("delay", 0.0)
		return action
	
	func get_display_text() -> String:
		var text = ""
		match action_type:
			"set_position": 
				var pos = parameters.get("position", {})
				text = "Установить позицию (%s, %s)" % [pos.get("x", 0), pos.get("y", 0)]
			"move_by": 
				var offset = parameters.get("offset", {})
				text = "Сместить на (%s, %s)" % [offset.get("x", 0), offset.get("y", 0)]
			"set_rotation": text = "Повернуть на %s" % parameters.get("rotation", "")
			"set_scale": 
				var scale = parameters.get("scale", {})
				text = "Масштабировать (%s, %s)" % [scale.get("x", 1), scale.get("y", 1)]
			"play_animation": text = "Проиграть анимацию '%s'" % parameters.get("animation", "")
			"stop_animation": text = "Остановить анимацию"
			"set_text": text = "Установить текст '%s'" % parameters.get("text", "")
			"set_visible": text = "Видимость: %s" % parameters.get("visible", true)
			"play_sound": text = "Проиграть звук"
			"stop_sound": text = "Остановить звук"
			"set_volume": text = "Громкость: %s дБ" % parameters.get("volume", 0)
			"set_property": text = "Свойство '%s' = %s" % [
				parameters.get("property", ""),
				parameters.get("value", "")
			]
			"call_method": text = "Вызвать метод '%s'" % parameters.get("method", "")
			"emit_signal": text = "Послать сигнал '%s'" % parameters.get("signal", "")
			"apply_impulse": 
				var impulse = parameters.get("impulse", {})
				text = "Импульс (%s, %s)" % [impulse.get("x", 0), impulse.get("y", 0)]
			"set_velocity": 
				var velocity = parameters.get("velocity", {})
				text = "Скорость (%s, %s)" % [velocity.get("x", 0), velocity.get("y", 0)]
			"destroy": text = "Уничтожить"
			"instance_scene": text = "Создать сцену '%s'" % parameters.get("scene", "")
			"change_scene": text = "Перейти к сцене '%s'" % parameters.get("scene", "")
			"print_message": text = "Вывести '%s'" % parameters.get("message", "")
			"start_timer": text = "Запустить таймер (%ss)" % parameters.get("time", 1.0)
			"stop_timer": text = "Остановить таймер"
			_: text = action_type
		
		if delay > 0.0:
			text += " (задержка: %ss)" % delay
		
		return text


## Контейнер для блоков событий
class EventSheet:
	var sheet_name: String = "Event Sheet"
	var description: String = ""
	var blocks: Array[EventBlock] = []
	var global_variables: Dictionary = {}
	
	func to_dict() -> Dictionary:
		var blocks_array = []
		for block in blocks:
			blocks_array.append(block.to_dict())
		
		return {
			"sheet_name": sheet_name,
			"description": description,
			"blocks": blocks_array,
			"global_variables": global_variables
		}
	
	static func from_dict(data: Dictionary) -> EventSheet:
		var sheet = EventSheet.new()
		sheet.sheet_name = data.get("sheet_name", "Event Sheet")
		sheet.description = data.get("description", "")
		sheet.global_variables = data.get("global_variables", {})
		
		for block_data in data.get("blocks", []):
			sheet.blocks.append(EventBlock.from_dict(block_data))
		
		return sheet
	
	func add_block(block: EventBlock) -> void:
		blocks.append(block)
	
	func remove_block(block: EventBlock) -> void:
		blocks.erase(block)
	
	func get_blocks_count() -> int:
		return blocks.size()


## Менеджер для работы с файлами
class FileManager:
	static func save_to_file(sheet: EventSheet, file_path: String) -> bool:
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file == null:
			push_error("Не удалось открыть файл для записи: %s (error: %s)" % [file_path, FileAccess.get_open_error()])
			return false
		
		var json_data = JSON.stringify(sheet.to_dict(), "\t")
		file.store_string(json_data)
		file.close()
		print("EventSheet сохранен: %s" % file_path)
		return true
	
	static func load_from_file(file_path: String) -> EventSheet:
		# Исправляем проверку файла
		if not FileAccess.file_exists(file_path):
			push_error("Файл не найден: %s" % file_path)
			return null
		
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			push_error("Не удалось открыть файл для чтения: %s (error: %s)" % [file_path, FileAccess.get_open_error()])
			return null
		
		var json_string = file.get_as_text()
		file.close()
		
		if json_string.is_empty():
			push_error("JSON файл пустой: %s" % file_path)
			return null
		
		var json = JSON.new()
		var error = json.parse(json_string)
		
		if error != OK:
			push_error("Ошибка парсинга JSON в строке %d: %s" % [json.get_error_line(), json.get_error_message()])
			return null
		
		var data = json.data
		if data == null or not data is Dictionary:
			push_error("Некорректный формат JSON: %s" % file_path)
			return null
		
		print("EventSheet загружен: %s" % file_path)
		return EventSheet.from_dict(data)