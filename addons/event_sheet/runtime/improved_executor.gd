extends Node
class_name ImprovedEventExecutor

@export var event_sheet_path: String = ""
@export var debug_mode: bool = false

var event_sheet: ImprovedEventData.EventSheet = null
var connected_signals: Dictionary = {}
var signal_triggers: Dictionary = {}

func _ready():
	if event_sheet_path.is_empty():
		push_error("ImprovedEventExecutor: event_sheet_path не задан!")
		return
	
	load_event_sheet()
	if event_sheet:
		_connect_node_signals()
		_execute_scene_ready_events()

func load_event_sheet():
	event_sheet = ImprovedEventData.FileManager.load_from_file(event_sheet_path)
	
	if event_sheet == null:
		push_error("ImprovedEventExecutor: Не удалось загрузить %s" % event_sheet_path)
		return
	
	if debug_mode:
		print("ImprovedEventExecutor: Загружено %d блоков событий" % event_sheet.get_blocks_count())

func _connect_node_signals():
	"""Подключаем сигналы узлов для событийных условий"""
	for block in event_sheet.blocks:
		if not block.enabled or block.condition == null:
			continue
		
		var node = block.get_target_node()
		if node == null:
			if debug_mode:
				print("Узел не найден: %s" % block.target_object)
			continue
		
		var condition = block.condition
		
		match condition.condition_type:
			"button_pressed":
				if node.has_signal("pressed"):
					_connect_signal_safely(node, "pressed", _on_button_pressed.bind(block))
			
			"collision_entered":
				if node.has_signal("body_entered"):
					_connect_signal_safely(node, "body_entered", _on_collision_entered.bind(block))
				elif node.has_signal("area_entered"):
					_connect_signal_safely(node, "area_entered", _on_area_entered.bind(block))
			
			"animation_finished":
				if node.has_signal("animation_finished"):
					_connect_signal_safely(node, "animation_finished", _on_animation_finished.bind(block))
			
			"mouse_entered":
				if node.has_signal("mouse_entered"):
					_connect_signal_safely(node, "mouse_entered", _on_mouse_entered.bind(block))
			
			"timer_timeout":
				if node.has_signal("timeout"):
					_connect_signal_safely(node, "timeout", _on_timer_timeout.bind(block))
			
			# Добавляем другие сигналы по мере необходимости

func _connect_signal_safely(node: Node, signal_name: String, callback: Callable):
	"""Безопасное подключение сигнала (избегаем дублирования)"""
	var signal_key = str(node.get_instance_id()) + "::" + signal_name
	
	if signal_key in connected_signals:
		return
	
	if node.has_signal(signal_name):
		node.connect(signal_name, callback)
		connected_signals[signal_key] = true
		
		if debug_mode:
			print("Подключен сигнал %s::%s" % [node.name, signal_name])

func _execute_scene_ready_events():
	"""Выполняем события 'scene_ready' сразу после загрузки"""
	for block in event_sheet.blocks:
		if not block.enabled or block.condition == null:
			continue
		
		if block.condition.condition_type == "scene_ready":
			var node = block.get_target_node()
			if node and node.is_node_ready():
				_execute_block_actions(block)

func _process(_delta):
	"""Обрабатываем блоки событий каждый кадр"""
	if event_sheet == null:
		return
	
	for block in event_sheet.blocks:
		if not block.enabled or block.condition == null:
			continue
		
		var node = block.get_target_node()
		if node == null:
			continue
		
		var condition = block.condition
		
		# Проверяем условия которые нужно проверять каждый кадр
		match condition.condition_type:
			"every_frame":
				_execute_block_actions(block)
			
			"key_pressed":
				var key = condition.parameters.get("key", "")
				if key != "" and Input.is_action_pressed(key):
					_execute_block_actions(block)
			
			"is_on_floor":
				if node is CharacterBody2D and node.is_on_floor():
					_execute_block_actions(block)
				elif node is CharacterBody3D and node.is_on_floor():
					_execute_block_actions(block)
			
			"is_on_wall":
				if node is CharacterBody2D and node.is_on_wall():
					_execute_block_actions(block)
				elif node is CharacterBody3D and node.is_on_wall():
					_execute_block_actions(block)
			
			"variable_compare":
				if condition.evaluate(node):
					_execute_block_actions(block)

func _execute_block_actions(block: ImprovedEventData.EventBlock):
	"""Выполняем все действия блока"""
	if debug_mode:
		print("Выполняется блок: %s" % block.get_display_text())
	
	var node = block.get_target_node()
	if node == null:
		return
	
	for action in block.actions:
		action.execute(node)
		
		if debug_mode:
			print("  - Действие: %s" % action.get_display_text())

# Обработчики сигналов

func _on_button_pressed(block: ImprovedEventData.EventBlock):
	_execute_block_actions(block)

func _on_collision_entered(body, block: ImprovedEventData.EventBlock):
	# Можем проверить дополнительные условия (например, тип объекта)
	_execute_block_actions(block)

func _on_area_entered(area, block: ImprovedEventData.EventBlock):
	_execute_block_actions(block)

func _on_animation_finished(anim_name, block: ImprovedEventData.EventBlock):
	# Можем проверить имя анимации в параметрах условия
	var expected_anim = block.condition.parameters.get("animation", "")
	if expected_anim == "" or expected_anim == anim_name:
		_execute_block_actions(block)

func _on_mouse_entered(block: ImprovedEventData.EventBlock):
	_execute_block_actions(block)

func _on_timer_timeout(block: ImprovedEventData.EventBlock):
	_execute_block_actions(block)

# Утилиты

func get_node_by_path_or_group(path: String) -> Node:
	"""Ищем узел по пути или по группе"""
	if path.is_empty():
		return null
	
	# Поиск по пути
	var node = get_tree().current_scene.get_node_or_null(path)
	if node != null:
		return node
	
	# Поиск по группе
	var nodes = get_tree().get_nodes_in_group(path)
	if nodes.size() > 0:
		return nodes[0]
	
	return null

func reload_event_sheet():
	"""Перезагружаем таблицу событий (для отладки)"""
	# Отключаем старые сигналы
	for signal_key in connected_signals.keys():
		# TODO: реализовать отключение сигналов
		pass
	
	connected_signals.clear()
	
	# Перезагружаем данные
	load_event_sheet()
	if event_sheet:
		_connect_node_signals()

func add_block_runtime(block: ImprovedEventData.EventBlock):
	"""Добавляем блок во время выполнения"""
	if event_sheet == null:
		return
	
	event_sheet.add_block(block)
	
	# Подключаем сигналы для нового блока
	if block.enabled and block.condition:
		var node = block.get_target_node()
		if node:
			match block.condition.condition_type:
				"button_pressed":
					if node.has_signal("pressed"):
						_connect_signal_safely(node, "pressed", _on_button_pressed.bind(block))
				# Добавляем другие типы условий...

func remove_block_runtime(block: ImprovedEventData.EventBlock):
	"""Удаляем блок во время выполнения"""
	if event_sheet == null:
		return
	
	event_sheet.remove_block(block)
	# TODO: отключить соответствующие сигналы

# Геттеры/Сеттеры для отладки

func get_blocks_count() -> int:
	if event_sheet == null:
		return 0
	return event_sheet.get_blocks_count()

func get_enabled_blocks_count() -> int:
	if event_sheet == null:
		return 0
	
	var count = 0
	for block in event_sheet.blocks:
		if block.enabled:
			count += 1
	return count

func print_debug_info():
	"""Выводим отладочную информацию"""
	if event_sheet == null:
		print("EventSheet не загружен")
		return
	
	print("=== Отладочная информация EventExecutor ===")
	print("Файл: %s" % event_sheet_path)
	print("Всего блоков: %d" % get_blocks_count())
	print("Активных блоков: %d" % get_enabled_blocks_count())
	print("Подключенных сигналов: %d" % connected_signals.size())
	
	print("\n--- Блоки событий ---")
	for i in range(event_sheet.blocks.size()):
		var block = event_sheet.blocks[i]
		var status = "✓" if block.enabled else "✗"
		print("%d. %s %s" % [i + 1, status, block.get_display_text()])
	
	print("============================================")