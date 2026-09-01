extends Node2D
## Stage-C polish: high score, per-ball danger, aim line, merge fade.

const WALL := 10.0
const DROP_Y := 75.0
const DANGER_Y := 115.0
const DROP_COOLDOWN_MS := 650
const DANGER_HOLD_MS := 2500
const SAFE_AFTER_SPAWN_MS := 1200
const MERGE_DELAY_MS := 80
const STILL_SPEED := 18.0
const BOX_W := 360.0
const BOX_H := 640.0

@onready var _fruits: Node2D = $Fruits
@onready var _preview: Polygon2D = $Preview
@onready var _next_preview: Polygon2D = $NextPreview
@onready var _aim: Line2D = $AimLine
@onready var _hud: Label = $UI/HUD
@onready var _overlay: ColorRect = $UI/Overlay
@onready var _over_msg: Label = $UI/Overlay/VBox/Msg
@onready var _retry: Button = $UI/Overlay/VBox/Retry
@onready var _danger: Line2D = $DangerLine
@onready var _float_root: Node2D = $FloatScores

var _score: int = 0
var _next_lv: int = 0
var _current_lv: int = 0
var _drop_locked: bool = false
var _alive: bool = true
var _fruit_scene: PackedScene = preload("res://scenes/fruit.tscn")
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_retry.pressed.connect(_restart)
	_overlay.visible = false
	_overlay.gui_input.connect(_on_overlay_input)
	_build_walls()
	_danger.points = PackedVector2Array([Vector2(WALL, DANGER_Y), Vector2(BOX_W - WALL, DANGER_Y)])
	_danger.default_color = Color(1.0, 0.27, 0.27, 0.55)
	_danger.width = 2.0
	_aim.width = 1.5
	_aim.default_color = Color(1, 1, 1, 0.18)
	_current_lv = FruitData.random_drop_lv()
	_next_lv = FruitData.random_drop_lv()
	_aim_at(BOX_W * 0.5)
	_update_preview()
	_update_hud()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_restart()
	elif event is InputEventScreenTouch and event.pressed:
		_restart()

func _build_walls() -> void:
	_add_static_rect(Vector2(WALL * 0.5, BOX_H * 0.5), Vector2(WALL, BOX_H))
	_add_static_rect(Vector2(BOX_W - WALL * 0.5, BOX_H * 0.5), Vector2(WALL, BOX_H))
	_add_static_rect(Vector2(BOX_W * 0.5, BOX_H - WALL * 0.5), Vector2(BOX_W, WALL))

func _add_static_rect(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.position = pos
	body.add_child(shape)
	var mat := PhysicsMaterial.new()
	mat.friction = 0.4
	mat.bounce = 0.1
	body.physics_material_override = mat
	var vis := ColorRect.new()
	vis.size = size
	vis.position = -size * 0.5
	vis.color = Color(0.24, 0.18, 0.43) # 0x3d2f6e
	body.add_child(vis)
	$Walls.add_child(body)

func _restart() -> void:
	for c in _fruits.get_children():
		c.queue_free()
	for c in _float_root.get_children():
		c.queue_free()
	_score = 0
	_alive = true
	_drop_locked = false
	_overlay.visible = false
	_current_lv = FruitData.random_drop_lv()
	_next_lv = FruitData.random_drop_lv()
	_aim_at(BOX_W * 0.5)
	_update_preview()
	_update_hud()

func _update_preview() -> void:
	var r := FruitData.radius(_current_lv)
	_preview.color = FruitData.color(_current_lv)
	_preview.polygon = _circle_poly(r, 20)
	_preview.visible = _alive and not _drop_locked
	_aim.visible = _preview.visible
	var nr := FruitData.radius(_next_lv) * 0.45
	_next_preview.color = FruitData.color(_next_lv)
	_next_preview.polygon = _circle_poly(nr, 16)
	_next_preview.position = Vector2(BOX_W - 36.0, 36.0)
	_next_preview.visible = _alive

func _circle_poly(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _update_hud() -> void:
	_hud.text = "得分: %d\n最高: %d" % [_score, SaveData.high_score]

func _unhandled_input(event: InputEvent) -> void:
	if not _alive:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_aim_at(_pointer_x(event))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_drop()
	if event is InputEventScreenTouch and event.pressed:
		_aim_at(event.position.x)
		_try_drop()

func _pointer_x(event: InputEvent) -> float:
	if event is InputEventMouse:
		return (event as InputEventMouse).position.x
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position.x
	return _preview.position.x

func _aim_at(x: float) -> void:
	var r := FruitData.radius(_current_lv)
	var min_x := WALL + r
	var max_x := BOX_W - WALL - r
	_preview.position = Vector2(clampf(x, min_x, max_x), DROP_Y)
	_aim.points = PackedVector2Array([
		Vector2(_preview.position.x, DROP_Y + r),
		Vector2(_preview.position.x, BOX_H - WALL),
	])

func _try_drop() -> void:
	if _drop_locked or not _alive:
		return
	_drop_locked = true
	_preview.visible = false
	_aim.visible = false
	var fruit := _spawn_fruit(_current_lv, _preview.position)
	fruit.linear_velocity = Vector2(0, 80)
	get_tree().create_timer(DROP_COOLDOWN_MS / 1000.0).timeout.connect(func() -> void:
		if _alive:
			_current_lv = _next_lv
			_next_lv = FruitData.random_drop_lv()
			_drop_locked = false
			_update_preview()
			_aim_at(_preview.position.x)
			_update_hud()
	)

func _spawn_fruit(lv: int, pos: Vector2) -> Fruit:
	var fruit: Fruit = _fruit_scene.instantiate() as Fruit
	_fruits.add_child(fruit)
	fruit.global_position = pos
	fruit.setup(lv)
	fruit.merge_wanted.connect(_on_merge_wanted)
	return fruit

func _on_merge_wanted(a: RigidBody2D, b: RigidBody2D) -> void:
	if not _alive:
		return
	if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
		return
	var fa := a as Fruit
	var fb := b as Fruit
	if fa == null or fb == null:
		return
	if fa.merging or fb.merging:
		return
	if fa.level != fb.level or fa.level >= FruitData.MAX_LV:
		return
	fa.merging = true
	fb.merging = true
	var mid := (fa.global_position + fb.global_position) * 0.5
	var new_lv: int = fa.level + 1
	var add_score: int = FruitData.score(new_lv)
	await get_tree().create_timer(MERGE_DELAY_MS / 1000.0).timeout
	if not _alive:
		return
	if is_instance_valid(fa):
		fa.queue_free()
	if is_instance_valid(fb):
		fb.queue_free()
	await get_tree().physics_frame
	if not _alive:
		return
	var neu := _spawn_fruit(new_lv, mid)
	neu.linear_velocity = Vector2.ZERO
	neu.modulate.a = 0.25
	var tw := create_tween()
	tw.tween_property(neu, "modulate:a", 1.0, 0.18)
	_score += add_score
	_float_score(mid + Vector2(0, -FruitData.radius(new_lv)), "+%d" % add_score)
	_update_hud()

func _float_score(pos: Vector2, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.modulate = Color(1.0, 0.84, 0.31)
	lbl.add_theme_font_size_override("font_size", 16)
	_float_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", pos.y - 36.0, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)

func _physics_process(_delta: float) -> void:
	if not _alive:
		return
	var now := Time.get_ticks_msec()
	for c in _fruits.get_children():
		var fruit := c as Fruit
		if fruit == null:
			continue
		if now - fruit.born_msec < SAFE_AFTER_SPAWN_MS:
			fruit.danger_since = -1
			continue
		var r := FruitData.radius(fruit.level)
		var p: Vector2 = fruit.global_position
		var min_x := WALL + r
		var max_x := BOX_W - WALL - r
		var min_y := r
		var max_y := BOX_H - WALL - r
		if p.x < min_x or p.x > max_x or p.y < min_y or p.y > max_y:
			fruit.global_position = Vector2(clampf(p.x, min_x, max_x), clampf(p.y, min_y, max_y))
			fruit.linear_velocity = Vector2(0, 40)
		if fruit.top_y() < DANGER_Y and fruit.speed() < STILL_SPEED:
			if fruit.danger_since < 0:
				fruit.danger_since = now
			elif now - fruit.danger_since >= DANGER_HOLD_MS:
				_game_over()
				return
		else:
			fruit.danger_since = -1
	var a := 0.3 + sin(Time.get_ticks_msec() * 0.004) * 0.25
	_danger.default_color = Color(1.0, 0.27, 0.27, a)

func _game_over() -> void:
	_alive = false
	_preview.visible = false
	_aim.visible = false
	_next_preview.visible = false
	var best: int = SaveData.record(_score)
	_over_msg.text = "游戏结束\n得分：%d\n最高：%d\n\n点击重新开始" % [_score, best]
	_overlay.visible = true
	_update_hud()
