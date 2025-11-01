@tool
extends Node

# Текущая активная сцена
var current_scene = null

# Загруженные данные event sheet
var body_items: Dictionary = {}

# Зарегистрированные обработчики событий
var event_handlers: Dictionary = {}

# Кэши для оптимизации производительности
var event_cache: Dictionary = {}  # event_type -> Array[events]
var action_cache: Dictionary = {}  # action_id -> Callable
var condition_cache: Dictionary = {}  # condition_id -> Callable

# Объекты, отслеживаемые системой событий
var tracked_objects: Dictionary = {}

# Глобальные переменные
var global_variables: Dictionary = {}

# Таймеры
var active_timers: Dictionary = {}  # timer_name -> {"time_left": float, "loop": bool, "total_time": float}

# Флаги оптимизации
var caches_built: bool = false

# Профилировщик производительности
var performance_stats: Dictionary = {
	"events_processed": 0,
	"actions_executed": 0,
	"cache_hits": 0,
	"average_frame_time": 0.0,
	"last_frame_time": 0.0
}

# Ленивая загрузка ресурсов
var resource_load_queue: Array = []
var loaded_resources: Dictionary = {}  # path -> Resource
var loading_progress: Dictionary = {}  # path -> status

func _build_caches():
	"""Строит кэши для оптимизации производительности"""
	if caches_built:
		return

	event_cache.clear()
	action_cache.clear()
	condition_cache.clear()

	# Строим кэш событий
	for body_id in body_items:
		var body = body_items[body_id]
		var events: Dictionary = body.get("events", {})

		for event_id in events:
			var event_data = events[event_id]
			var event_resource: WEvent = ResourceLoader.load(event_data["resource_path"])

			if not event_cache.has(event_resource.id):
				event_cache[event_resource.id] = []
			event_cache[event_resource.id].append({
				"body_id": body_id,
				"event_data": event_data,
				"event_resource": event_resource,
				"actions": body.get("actions", {})
			})

	# Строим кэш действий
	action_cache = {
		"create_object": "_action_create_object",
		"destroy_object": "_action_destroy_object",
		"set_position": "_action_set_position",
		"set_visible": "_action_set_visible",
		"move_at_angle": "_action_move_at_angle",
		"set_velocity": "_action_set_velocity",
		"set_angle": "_action_set_angle",
		"set_scale": "_action_set_scale",
		"play_sound": "_action_play_sound",
		"stop_sound": "_action_stop_sound",
		"set_variable": "_action_set_variable",
		"start_timer": "_action_start_timer"
	}

	# Строим кэш условий
	condition_cache = {
		"compare_values": "_condition_compare_values"
	}

	caches_built = true
	print("EventSheet: Caches built - ", event_cache.size(), " event types cached")

func _ready() -> void:
	if !Engine.is_editor_hint():
		var root = get_tree().root
		current_scene = root.get_child(root.get_child_count() - 1)
		_parse_event_sheet()
		_build_caches()
		_setup_event_system()
		_setup_collision_detection()
		_process_start_events()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Обрабатываем асинхронную загрузку ресурсов
	_process_async_loading()

	# Обновляем движение объектов
	_update_object_movement(delta)

	# Здесь будут обрабатываться события каждого кадра
	_process_frame_events_optimized(delta)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	
	# Обработка событий ввода
	_process_input_events(event)

# ============================================
# ЗАГРУЗКА И ПАРСИНГ EVENT SHEET
# ============================================

func _parse_event_sheet():
	"""Загружает event sheet из JSON файла"""
	if !FileAccess.file_exists("res://event_sheet/event_sheet.json"):
		print("EventSheet: event_sheet.json not found")
		return
	
	var file_path = FileAccess.open("res://event_sheet/event_sheet.json", FileAccess.READ)
	var json_string = file_path.get_line()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result == OK:
		body_items = json.data
		print("EventSheet: Loaded ", body_items.size(), " event blocks")
	else:
		print("EventSheet: Failed to parse JSON")

# ============================================
# НАСТРОЙКА СИСТЕМЫ СОБЫТИЙ
# ============================================

func _setup_event_system():
	"""Настраивает систему обработки событий"""
	# Регистрируем обработчики для различных типов событий
	_register_event_handlers()

func _setup_collision_detection():
	"""Настраивает систему обнаружения столкновений"""
	if current_scene:
		# Подключаемся к сигналам столкновений для всех объектов с Area2D или CollisionShape2D
		_setup_collision_signals(current_scene)

func _setup_collision_signals(node: Node):
	"""Рекурсивно настраивает сигналы столкновений для всех дочерних узлов"""
	for child in node.get_children():
		if child is Area2D:
			# Подключаем сигналы столкновений для Area2D
			if not child.body_entered.is_connected(_on_body_entered):
				child.body_entered.connect(_on_body_entered.bind(child))
			if not child.body_exited.is_connected(_on_body_exited):
				child.body_exited.connect(_on_body_exited.bind(child))
			if not child.area_entered.is_connected(_on_area_entered):
				child.area_entered.connect(_on_area_entered.bind(child))
			if not child.area_exited.is_connected(_on_area_exited):
				child.area_exited.connect(_on_area_exited.bind(child))

		elif child is RigidBody2D or child is StaticBody2D or child is CharacterBody2D:
			# Для физических тел подключаем сигналы через Area2D дочерние узлы
			for grandchild in child.get_children():
				if grandchild is Area2D:
					if not grandchild.body_entered.is_connected(_on_body_entered):
						grandchild.body_entered.connect(_on_body_entered.bind(grandchild))
					if not grandchild.body_exited.is_connected(_on_body_exited):
						grandchild.body_exited.connect(_on_body_exited.bind(grandchild))
					if not grandchild.area_entered.is_connected(_on_area_entered):
						grandchild.area_entered.connect(_on_area_entered.bind(grandchild))
					if not grandchild.area_exited.is_connected(_on_area_exited):
						grandchild.area_exited.connect(_on_area_exited.bind(grandchild))

		# Рекурсивно обрабатываем дочерние узлы
		_setup_collision_signals(child)

func _register_event_handlers():
	"""Регистрирует все доступные обработчики событий"""
	event_handlers = {
		# Start & End events
		"on_start_of_layout": "_handle_on_start_of_layout",

		# Keyboard events (будут добавлены позже)
		"on_key_pressed": "_handle_on_key_pressed",
		"on_key_released": "_handle_on_key_released",

		# Mouse events (будут добавлены позже)
		"on_mouse_clicked": "_handle_on_mouse_clicked",

		# Collision events (будут добавлены позже)
		"on_collision": "_handle_on_collision",

		# Timer events
		"on_timer": "_handle_on_timer",
	}

# ============================================
# ОБРАБОТКА СОБЫТИЙ
# ============================================

func _process_start_events():
	"""Обрабатывает события запуска"""
	for body_id in body_items:
		var body = body_items[body_id]
		var events: Dictionary = body.get("events", {})
		var actions: Dictionary = body.get("actions", {})
		
		# Проверяем события
		for event_id in events:
			var event_data = events[event_id]
			var event_resource: WEvent = ResourceLoader.load(event_data["resource_path"])
			
			if event_resource.id == "on_start_of_layout":
				# Выполняем все действия для этого события
				_execute_actions(actions, event_data)

func _process_frame_events(delta: float):
	"""Обрабатывает события каждого кадра"""
	# Обработка таймеров
	_update_timers(delta)

func _process_frame_events_optimized(delta: float):
	"""Оптимизированная обработка событий каждого кадра"""
	# Группировка таймеров по времени срабатывания для пакетной обработки
	var timers_by_time = {}  # time_left -> [timer_names]

	for timer_name in active_timers:
		var timer_data = active_timers[timer_name]
		var time_key = "%.3f" % timer_data["time_left"]  # Группируем по времени с точностью до 0.001

		if not timers_by_time.has(time_key):
			timers_by_time[time_key] = []
		timers_by_time[time_key].append(timer_name)

	# Обновляем все таймеры за один проход
	var timers_to_trigger = []
	for time_key in timers_by_time:
		var timer_names = timers_by_time[time_key]
		var time_left = float(time_key)

		time_left -= delta

		if time_left <= 0:
			timers_to_trigger.append_array(timer_names)

			# Обновляем таймеры
			for timer_name in timer_names:
				if active_timers.has(timer_name):
					var timer_data = active_timers[timer_name]
					if timer_data["loop"]:
						timer_data["time_left"] = timer_data["total_time"]
					else:
						active_timers.erase(timer_name)
		else:
			# Обновляем время для оставшихся таймеров
			for timer_name in timer_names:
				if active_timers.has(timer_name):
					active_timers[timer_name]["time_left"] = time_left

	# Запускаем события таймеров пакетно
	for timer_name in timers_to_trigger:
		_trigger_event("on_timer", {"timer_name": timer_name})

func _process_input_events(event: InputEvent):
	"""Обрабатывает события ввода"""
	# Обработка клавиатуры
	if event is InputEventKey:
		if event.pressed and !event.echo:
			_trigger_event("on_key_pressed", {"key": event.keycode, "pressed": true})
		elif !event.pressed:
			_trigger_event("on_key_released", {"key": event.keycode, "pressed": false})

	# Обработка мыши
	elif event is InputEventMouseButton:
		if event.pressed:
			_trigger_event("on_mouse_clicked", {"button": event.button_index, "position": event.position})

func _trigger_event(event_type: String, event_context: Dictionary):
	"""Запускает событие определенного типа с использованием кэшей"""
	if not event_cache.has(event_type):
		return

	# Используем кэш для быстрого доступа к событиям
	for cached_event in event_cache[event_type]:
		var event_resource: WEvent = cached_event.event_resource
		var event_data = cached_event.event_data

		# Проверяем, включено ли событие
		if not event_resource.enabled:
			continue

		# Проверяем параметры события и условия
		if _check_event_parameters(event_resource, event_data, event_context) and _check_conditions(event_data, event_context):
			# Выполняем действия
			_execute_actions(cached_event.actions, event_data, event_context)

func _check_event_parameters(event_resource: WEvent, event_data: Dictionary, context: Dictionary) -> bool:
	"""Проверяет параметры события"""
	var event_params: Dictionary = event_data.get("new_parametrs", {})
	var event_type = event_resource.id

	match event_type:
		"on_key_pressed", "on_key_released":
			# Проверяем клавишу
			var expected_key = event_params.get("Key", "")
			var actual_key = context.get("key", 0)
			if expected_key != "":
				# Преобразуем строку в keycode для сравнения
				var expected_keycode = _string_to_keycode(expected_key)
				if expected_keycode != actual_key:
					return false

		"on_mouse_clicked":
			# Проверяем кнопку мыши
			var expected_button = event_params.get("Button", "")
			var actual_button = context.get("button", 0)
			var button_name = _get_mouse_button_name(actual_button)
			if expected_button != "" and expected_button != button_name:
				return false

		"on_collision":
			# Проверяем параметры столкновения
			var expected_object = event_params.get("Object", "")
			var expected_tag = event_params.get("Tag", "")
			var actual_collider = context.get("collider", "")
			var actual_tag = context.get("tag", "")

			# Проверяем объект
			if expected_object != "" and expected_object != actual_collider:
				return false

			# Проверяем тег (если указан)
			if expected_tag != "" and expected_tag != actual_tag:
				return false

		# Для других событий параметры пока не проверяем
		_:
			pass

	return true

func _check_conditions(event_data: Dictionary, context: Dictionary) -> bool:
	"""Проверяет условия события"""
	var conditions: Array = event_data.get("conditions", [])

	# Если условий нет, возвращаем true
	if conditions.size() == 0:
		return true

	# Проверяем все условия
	for condition_data in conditions:
		var condition_resource: WCondition = ResourceLoader.load(condition_data["resource_path"])

		# Проверяем, включено ли условие
		if condition_resource.enabled:
			var condition_params: Dictionary = condition_data.get("new_parametrs", {})

			if not _check_condition(condition_resource, condition_params, context):
				return false

	return true

func _check_condition(condition_resource: WCondition, params: Dictionary, context: Dictionary) -> bool:
	"""Проверяет конкретное условие"""
	var condition_id = condition_resource.id

	match condition_id:
		"compare_values":
			return _condition_compare_values(params, context)
		_:
			print("EventSheet: Unknown condition: ", condition_id)
			return false

func _condition_compare_values(params: Dictionary, context: Dictionary) -> bool:
	"""Условие сравнения значений"""
	var value1 = _evaluate_expression(params.get("Value1", ""))
	var comparison = params.get("Comparison", "Equal")
	var value2 = _evaluate_expression(params.get("Value2", ""))

	match comparison:
		"Equal":
			return value1 == value2
		"Not Equal":
			return value1 != value2
		"Less":
			return float(value1) < float(value2)
		"Less or Equal":
			return float(value1) <= float(value2)
		"Greater":
			return float(value1) > float(value2)
		"Greater or Equal":
			return float(value1) >= float(value2)
		_:
			print("EventSheet: Unknown comparison: ", comparison)
			return false

func _evaluate_expression(expression: String):
	"""Вычисляет выражение с поддержкой переменных и математических операций"""
	if expression.strip_edges() == "":
		return ""

	# Проверяем, является ли выражение именем переменной
	var var_value = get_global_variable(expression)
	if var_value != null:
		return var_value

	# Проверяем, является ли выражение числом
	if expression.is_valid_float():
		return float(expression)
	elif expression.is_valid_int():
		return int(expression)

	# Проверяем, является ли выражение строкой в кавычках
	if expression.begins_with('"') and expression.ends_with('"'):
		return expression.substr(1, expression.length() - 2)
	elif expression.begins_with("'") and expression.ends_with("'"):
		return expression.substr(1, expression.length() - 2)

	# Простые математические выражения (без скобок для начала)
	var operators = ["+", "-", "*", "/", "%"]
	var result = _parse_math_expression(expression)

	if result != null:
		return result

	# Если ничего не подошло, возвращаем как строку
	return expression

func _parse_math_expression(expression: String):
	"""Парсит простые математические выражения"""
	expression = expression.strip_edges()

	# Ищем операторы в порядке приоритета
	var operators = [
		["*", "/", "%"],  # Высокий приоритет
		["+", "-"]        # Низкий приоритет
	]

	for op_group in operators:
		for op in op_group:
			if expression.contains(op):
				var parts = expression.split(op, false, 1)
				if parts.size() == 2:
					var left = _evaluate_expression(parts[0].strip_edges())
					var right = _evaluate_expression(parts[1].strip_edges())

					# Преобразуем в числа если возможно
					var left_num = _to_number(left)
					var right_num = _to_number(right)

					if left_num != null and right_num != null:
						match op:
							"+": return left_num + right_num
							"-": return left_num - right_num
							"*": return left_num * right_num
							"/":
								if right_num != 0:
									return left_num / right_num
								else:
									print("EventSheet: Division by zero in expression: ", expression)
									return 0
							"%": return int(left_num) % int(right_num)

	return null

func _to_number(value):
	"""Преобразует значение в число если возможно"""
	if value is float or value is int:
		return value
	elif value is String:
		if value.is_valid_float():
			return float(value)
		elif value.is_valid_int():
			return int(value)
	return null

func _string_to_keycode(key_string: String) -> int:
	"""Преобразует строку клавиши в keycode"""
	match key_string.to_upper():
		"SPACE":
			return KEY_SPACE
		"A":
			return KEY_A
		"B":
			return KEY_B
		"C":
			return KEY_C
		"D":
			return KEY_D
		"E":
			return KEY_E
		"F":
			return KEY_F
		"G":
			return KEY_G
		"H":
			return KEY_H
		"I":
			return KEY_I
		"J":
			return KEY_J
		"K":
			return KEY_K
		"L":
			return KEY_L
		"M":
			return KEY_M
		"N":
			return KEY_N
		"O":
			return KEY_O
		"P":
			return KEY_P
		"Q":
			return KEY_Q
		"R":
			return KEY_R
		"S":
			return KEY_S
		"T":
			return KEY_T
		"U":
			return KEY_U
		"V":
			return KEY_V
		"W":
			return KEY_W
		"X":
			return KEY_X
		"Y":
			return KEY_Y
		"Z":
			return KEY_Z
		"ENTER":
			return KEY_ENTER
		"ESCAPE":
			return KEY_ESCAPE
		"TAB":
			return KEY_TAB
		"SHIFT":
			return KEY_SHIFT
		"CTRL":
			return KEY_CTRL
		"ALT":
			return KEY_ALT
		_:
			print("EventSheet: Unknown key: ", key_string)
			return 0

func _get_mouse_button_name(button_index: int) -> String:
	"""Получает имя кнопки мыши по индексу"""
	match button_index:
		MOUSE_BUTTON_LEFT:
			return "Left"
		MOUSE_BUTTON_RIGHT:
			return "Right"
		MOUSE_BUTTON_MIDDLE:
			return "Middle"
		MOUSE_BUTTON_WHEEL_UP:
			return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Wheel Down"
		MOUSE_BUTTON_WHEEL_LEFT:
			return "Wheel Left"
		MOUSE_BUTTON_WHEEL_RIGHT:
			return "Wheel Right"
		_:
			return "Unknown"

# ============================================
# ВЫПОЛНЕНИЕ ДЕЙСТВИЙ
# ============================================

func _execute_actions(actions: Dictionary, event_data: Dictionary, context: Dictionary = {}):
	"""Выполняет все действия для события"""
	for action_id in actions:
		var action_data = actions[action_id]
		var action_resource: WAction = ResourceLoader.load(action_data["resource_path"])

		# Проверяем, включено ли действие
		if action_resource.enabled:
			var parameters: Dictionary = action_data.get("new_parametrs", {})

			# Вызываем соответствующий обработчик действия
			_execute_action(action_resource.id, parameters, context)

func _execute_action(action_id: String, parameters: Dictionary, context: Dictionary):
	"""Выполняет конкретное действие"""
	match action_id:
		"create_object":
			_action_create_object(parameters, context)
		"destroy_object":
			_action_destroy_object(parameters, context)
		"set_position":
			_action_set_position(parameters, context)
		"set_visible":
			_action_set_visible(parameters, context)
		"move_at_angle":
			_action_move_at_angle(parameters, context)
		"set_velocity":
			_action_set_velocity(parameters, context)
		"set_angle":
			_action_set_angle(parameters, context)
		"set_scale":
			_action_set_scale(parameters, context)
		"play_sound":
			_action_play_sound(parameters, context)
		"stop_sound":
			_action_stop_sound(parameters, context)
		"set_variable":
			_action_set_variable(parameters, context)
		"start_timer":
			_action_start_timer(parameters, context)
		_:
			print("EventSheet: Unknown action: ", action_id)

# ============================================
# ОБРАБОТЧИКИ ДЕЙСТВИЙ
# ============================================

func _action_create_object(params: Dictionary, context: Dictionary):
	"""Создает новый объект с типизированными параметрами"""
	if !current_scene:
		print("EventSheet: No current scene for object creation")
		return

	# Типизированные параметры
	var object_path: String = _get_typed_param(params, "Object", TYPE_STRING, "")
	if object_path == "":
		print("EventSheet: No object path specified")
		return

	var obj_name: String = _get_typed_param(params, "Name", TYPE_STRING, "")
	var x: float = _get_typed_param(params, "X", TYPE_FLOAT, 0.0)
	var y: float = _get_typed_param(params, "Y", TYPE_FLOAT, 0.0)

	var new_object = load(object_path).instantiate()

	# Устанавливаем имя
	if obj_name != "":
		new_object.name = obj_name

	# Устанавливаем позицию
	new_object.position = Vector2(x, y)

	# Добавляем в сцену
	current_scene.add_child(new_object)

	print("EventSheet: Created object ", obj_name, " at ", new_object.position)

func _action_destroy_object(params: Dictionary, context: Dictionary):
	"""Уничтожает объект"""
	var obj_name = params.get("Name", "")
	if obj_name != "":
		var obj = current_scene.get_node_or_null(obj_name)
		if obj:
			obj.queue_free()
			print("EventSheet: Destroyed object ", obj_name)

func _action_set_position(params: Dictionary, context: Dictionary):
	"""Устанавливает позицию объекта"""
	var obj_name = params.get("Name", "")
	if obj_name != "":
		var obj = current_scene.get_node_or_null(obj_name)
		if obj:
			var x = float(params.get("X", obj.position.x))
			var y = float(params.get("Y", obj.position.y))
			obj.position = Vector2(x, y)

func _action_set_visible(params: Dictionary, context: Dictionary):
	"""Устанавливает видимость объекта"""
	var obj_name = params.get("Name", "")
	var visible = params.get("Visible", true)
	if obj_name != "":
		var obj = current_scene.get_node_or_null(obj_name)
		if obj and obj.has_method("set_visible"):
			obj.visible = visible

func _action_move_at_angle(params: Dictionary, context: Dictionary):
	"""Двигает объект под углом со скоростью"""
	var obj_name = params.get("Name", "")
	if obj_name != "":
		var obj = current_scene.get_node_or_null(obj_name)
		if obj:
			var angle = float(params.get("Angle", 0))
			var speed = float(params.get("Speed", 100))

			# Проверяем, нажата ли клавиша (из контекста события)
			var pressed = context.get("pressed", true)

			if pressed:
				# Клавиша нажата - устанавливаем скорость в метаданные объекта
				var radians = deg_to_rad(angle)
				var velocity = Vector2(cos(radians), sin(radians)) * speed
				obj.set_meta("eventsheet_velocity", velocity)
			else:
				# Клавиша отпущена - убираем скорость
				obj.set_meta("eventsheet_velocity", Vector2.ZERO)

func _action_set_velocity(params: Dictionary, context: Dictionary):
	"""Устанавливает скорость объекта"""
	var obj_name = params.get("Name", "")
	if obj_name != "":
		var obj = current_scene.get_node_or_null(obj_name)
		if obj:
			var x = float(params.get("X", 0))
			var y = float(params.get("Y", 0))
			var velocity = Vector2(x, y)
			if obj.has_method("set_velocity"):
				obj.set_velocity(velocity)
			else:
				print("EventSheet: Object ", obj_name, " doesn't have set_velocity method")

func _action_set_angle(params: Dictionary, context: Dictionary):
	"""Устанавливает угол поворота объекта"""
	var obj_name = params.get("Name", "")
	if obj_name != "":
		var obj = current_scene.get_node_or_null(obj_name)
		if obj:
			var angle = float(params.get("Angle", 0))
			obj.rotation_degrees = angle

func _action_set_scale(params: Dictionary, context: Dictionary):
	"""Устанавливает масштаб объекта"""
	var obj_name = params.get("Name", "")
	if obj_name != "":
		var obj = current_scene.get_node_or_null(obj_name)
		if obj:
			var scale_x = float(params.get("ScaleX", 1.0))
			var scale_y = float(params.get("ScaleY", 1.0))
			obj.scale = Vector2(scale_x, scale_y)

func _action_play_sound(params: Dictionary, context: Dictionary):
	"""Воспроизводит звук"""
	var sound_path = params.get("Sound", "")
	var volume = float(params.get("Volume", 1.0))
	var loop = params.get("Loop", false)
	
	if sound_path != "":
		var audio_stream = load(sound_path)
		if audio_stream:
			var audio_player = AudioStreamPlayer.new()
			audio_player.stream = audio_stream
			audio_player.volume_db = linear_to_db(volume)
			audio_player.autoplay = true
			if loop:
				audio_player.stream.loop = true
			current_scene.add_child(audio_player)
			audio_player.play()
		else:
			print("EventSheet: Failed to load sound: ", sound_path)

func _action_stop_sound(params: Dictionary, context: Dictionary):
	"""Останавливает звук"""
	var sound_path = params.get("Sound", "")
	if sound_path != "":
		# Ищем AudioStreamPlayer с соответствующим звуком
		for child in current_scene.get_children():
			if child is AudioStreamPlayer and child.stream.resource_path == sound_path:
				child.stop()
				child.queue_free()
				break

func _action_set_variable(params: Dictionary, context: Dictionary):
	"""Устанавливает значение переменной"""
	var var_name = params.get("Variable", "")
	var value = params.get("Value", "")
	if var_name != "":
		set_global_variable(var_name, value)
		print("EventSheet: Set variable ", var_name, " = ", value)

func _action_start_timer(params: Dictionary, context: Dictionary):
	"""Запускает таймер"""
	var timer_name = params.get("TimerName", "")
	var time = float(params.get("Time", 1.0))
	var loop = params.get("Loop", false)
	
	if timer_name != "":
		active_timers[timer_name] = {
			"time_left": time,
			"loop": loop,
			"total_time": time
		}
		print("EventSheet: Started timer ", timer_name, " for ", time, " seconds")

func _update_object_movement(delta: float):
	"""Обновляет движение объектов каждый кадр"""
	if !current_scene:
		return

	# Проходим по всем объектам в сцене
	for child in current_scene.get_children():
		if child.has_meta("eventsheet_velocity"):
			var velocity = child.get_meta("eventsheet_velocity", Vector2.ZERO)
			if velocity != Vector2.ZERO:
				child.position += velocity * delta

func _update_timers(delta: float):
	"""Обновляет состояние таймеров"""
	var timers_to_trigger = []

	for timer_name in active_timers:
		var timer_data = active_timers[timer_name]
		timer_data["time_left"] -= delta

		if timer_data["time_left"] <= 0:
			timers_to_trigger.append(timer_name)

			if timer_data["loop"]:
				timer_data["time_left"] = timer_data["total_time"]
			else:
				active_timers.erase(timer_name)

	# Запускаем события таймеров
	for timer_name in timers_to_trigger:
		_trigger_event("on_timer", {"timer_name": timer_name})

# ============================================
# ОБРАБОТЧИКИ СОБЫТИЙ (ЗАГЛУШКИ)
# ============================================

func _handle_on_start_of_layout(context: Dictionary):
	"""Обработчик события начала уровня"""
	pass

func _handle_on_key_pressed(context: Dictionary):
	"""Обработчик нажатия клавиши"""
	pass

func _handle_on_key_released(context: Dictionary):
	"""Обработчик отпускания клавиши"""
	pass

func _handle_on_mouse_clicked(context: Dictionary):
	"""Обработчик клика мыши"""
	pass

func _handle_on_collision(context: Dictionary):
	"""Обработчик столкновения"""
	pass

func _handle_on_timer(context: Dictionary):
	"""Обработчик события таймера"""
	var timer_name = context.get("timer_name", "")
	print("EventSheet: Timer ", timer_name, " triggered")

# ============================================
# ОБРАБОТЧИКИ СИГНАЛОВ СТОЛКНОВЕНИЙ
# ============================================

func _on_body_entered(body: Node2D, area: Area2D):
	"""Обработчик входа физического тела в область"""
	var collider_name = body.name if body else "Unknown"
	var area_name = area.get_parent().name if area.get_parent() else area.name

	# Получаем тег из метаданных или имени
	var tag = _get_object_tag(body)

	_trigger_event("on_collision", {
		"collider": collider_name,
		"area": area_name,
		"tag": tag,
		"type": "body_entered"
	})

func _on_body_exited(body: Node2D, area: Area2D):
	"""Обработчик выхода физического тела из области"""
	var collider_name = body.name if body else "Unknown"
	var area_name = area.get_parent().name if area.get_parent() else area.name

	# Получаем тег из метаданных или имени
	var tag = _get_object_tag(body)

	_trigger_event("on_collision", {
		"collider": collider_name,
		"area": area_name,
		"tag": tag,
		"type": "body_exited"
	})

func _on_area_entered(area: Area2D, source_area: Area2D):
	"""Обработчик входа области в другую область"""
	var collider_name = area.get_parent().name if area.get_parent() else area.name
	var source_name = source_area.get_parent().name if source_area.get_parent() else source_area.name

	# Получаем тег из метаданных или имени
	var tag = _get_object_tag(area.get_parent() if area.get_parent() else area)

	_trigger_event("on_collision", {
		"collider": collider_name,
		"area": source_name,
		"tag": tag,
		"type": "area_entered"
	})

func _on_area_exited(area: Area2D, source_area: Area2D):
	"""Обработчик выхода области из другой области"""
	var collider_name = area.get_parent().name if area.get_parent() else area.name
	var source_name = source_area.get_parent().name if source_area.get_parent() else source_area.name

	# Получаем тег из метаданных или имени
	var tag = _get_object_tag(area.get_parent() if area.get_parent() else area)

	_trigger_event("on_collision", {
		"collider": collider_name,
		"area": source_name,
		"tag": tag,
		"type": "area_exited"
	})

func _get_object_tag(obj: Node) -> String:
	"""Получает тег объекта из метаданных или имени"""
	if obj and obj.has_meta("tag"):
		return obj.get_meta("tag")

	# Если метаданные нет, пробуем извлечь из имени (формат: Name_Tag)
	if obj and obj.name.contains("_"):
		var parts = obj.name.split("_", false, 1)
		if parts.size() > 1:
			return parts[1]

	return ""

# ============================================
# УТИЛИТЫ
# ============================================

func get_object_by_name(obj_name: String) -> Node:
	"""Получает объект по имени"""
	if current_scene:
		return current_scene.get_node_or_null(obj_name)
	return null

func set_global_variable(var_name: String, value):
	"""Устанавливает глобальную переменную"""
	global_variables[var_name] = value

func get_global_variable(var_name: String, default_value = null):
	"""Получает глобальную переменную"""
	return global_variables.get(var_name, default_value)

func _get_typed_param(params: Dictionary, param_name: String, expected_type: int, default_value):
	"""Получает параметр с правильной типизацией"""
	var raw_value = params.get(param_name, default_value)

	# Если значение уже правильного типа, возвращаем его
	if typeof(raw_value) == expected_type:
		return raw_value

	# Преобразуем в зависимости от ожидаемого типа
	match expected_type:
		TYPE_STRING:
			return str(raw_value)
		TYPE_INT:
			if raw_value is String:
				return raw_value.to_int() if raw_value.is_valid_int() else int(default_value)
			return int(raw_value)
		TYPE_FLOAT:
			if raw_value is String:
				return raw_value.to_float() if raw_value.is_valid_float() else float(default_value)
			return float(raw_value)
		TYPE_BOOL:
			if raw_value is String:
				return raw_value.to_lower() == "true"
			return bool(raw_value)
		_:
			return raw_value

func validate_event_sheet() -> Array:
	"""Валидирует event sheet и возвращает массив ошибок"""
	var errors = []

	for body_id in body_items:
		var body = body_items[body_id]

		# Проверяем события
		var events: Dictionary = body.get("events", {})
		for event_id in events:
			var event_data = events[event_id]
			var event_resource_path = event_data.get("resource_path", "")

			# Проверяем существование ресурса события
			if not ResourceLoader.exists(event_resource_path):
				errors.append("Event resource not found: %s in body %s" % [event_resource_path, body_id])
			else:
				var event_resource: WEvent = ResourceLoader.load(event_resource_path)
				if not event_resource:
					errors.append("Failed to load event resource: %s" % event_resource_path)

		# Проверяем действия
		var actions: Dictionary = body.get("actions", {})
		for action_id in actions:
			var action_data = actions[action_id]
			var action_resource_path = action_data.get("resource_path", "")

			# Проверяем существование ресурса действия
			if not ResourceLoader.exists(action_resource_path):
				errors.append("Action resource not found: %s in body %s" % [action_resource_path, body_id])
			else:
				var action_resource: WAction = ResourceLoader.load(action_resource_path)
				if not action_resource:
					errors.append("Failed to load action resource: %s" % action_resource_path)

		# Проверяем комментарии
		var comments: Dictionary = body.get("comments", {})
		for comment_id in comments:
			var comment_data = comments[comment_id]
			if not comment_data.has("text") or comment_data["text"].strip_edges() == "":
				errors.append("Empty comment found in body %s" % body_id)

	return errors

func rebuild_caches():
	"""Перестраивает кэши (вызывается при изменении event sheet)"""
	caches_built = false
	_build_caches()

func preload_resources_async():
	"""Асинхронная предзагрузка ресурсов"""
	var resource_paths = _collect_all_resource_paths()

	for path in resource_paths:
		if not loaded_resources.has(path) and not loading_progress.has(path):
			loading_progress[path] = "pending"
			resource_load_queue.append(path)

	# Начинаем загрузку первых ресурсов
	_start_async_loading()

func _collect_all_resource_paths() -> Array:
	"""Собирает все пути к ресурсам из event sheet"""
	var paths = []

	for body_id in body_items:
		var body = body_items[body_id]

		# Собираем пути из событий
		var events: Dictionary = body.get("events", {})
		for event_id in events:
			var event_data = events[event_id]
			var event_path = event_data.get("resource_path", "")
			if event_path != "" and not paths.has(event_path):
				paths.append(event_path)

		# Собираем пути из действий
		var actions: Dictionary = body.get("actions", {})
		for action_id in actions:
			var action_data = actions[action_id]
			var action_path = action_data.get("resource_path", "")
			if action_path != "" and not paths.has(action_path):
				paths.append(action_path)

			# Собираем пути из параметров действий (например, пути к сценам, звукам)
			var params = action_data.get("new_parametrs", {})
			for param_key in params:
				var param_value = params[param_key]
				if param_value is String and param_value.begins_with("res://"):
					if not paths.has(param_value):
						paths.append(param_value)

	return paths

func _start_async_loading():
	"""Начинает асинхронную загрузку ресурсов"""
	var max_concurrent_loads = 3  # Максимум одновременных загрузок

	for i in range(min(max_concurrent_loads, resource_load_queue.size())):
		var path = resource_load_queue.pop_front()
		if path and not loaded_resources.has(path):
			loading_progress[path] = "loading"
			ResourceLoader.load_threaded_request(path, "", true)

func _process_async_loading():
	"""Обрабатывает завершение асинхронной загрузки в _process"""
	if resource_load_queue.is_empty() and loading_progress.is_empty():
		return

	var completed_paths = []

	for path in loading_progress:
		var status = ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			ResourceLoader.THREAD_LOAD_LOADED:
				var resource = ResourceLoader.load_threaded_get(path)
				if resource:
					loaded_resources[path] = resource
					completed_paths.append(path)
					print("EventSheet: Loaded resource: ", path)
				else:
					print("EventSheet: Failed to load resource: ", path)
					completed_paths.append(path)
			ResourceLoader.THREAD_LOAD_FAILED:
				print("EventSheet: Failed to load resource: ", path)
				completed_paths.append(path)

	# Удаляем завершенные загрузки
	for path in completed_paths:
		loading_progress.erase(path)

	# Начинаем загрузку следующих ресурсов
	if not resource_load_queue.is_empty():
		_start_async_loading()

func get_cached_resource(path: String):
	"""Получает ресурс из кэша или загружает синхронно"""
	if loaded_resources.has(path):
		return loaded_resources[path]

	# Если ресурс не загружен, загружаем синхронно
	if ResourceLoader.exists(path):
		var resource = ResourceLoader.load(path)
		if resource:
			loaded_resources[path] = resource
		return resource

	return null
