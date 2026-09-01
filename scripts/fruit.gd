class_name Fruit
extends RigidBody2D
## One fruit ball. Same-level contact → parent merge.

signal merge_wanted(a: RigidBody2D, b: RigidBody2D)

const MAX_SPEED := 520.0

var level: int = 0
var merging: bool = false
var born_msec: int = 0
var danger_since: int = -1
var _pending_lv: int = -1

func setup(lv: int) -> void:
	_pending_lv = lv
	if is_inside_tree() and is_node_ready():
		_apply_level(lv)

func _ready() -> void:
	if _pending_lv >= 0:
		_apply_level(_pending_lv)

func _apply_level(lv: int) -> void:
	level = lv
	born_msec = Time.get_ticks_msec()
	danger_since = -1
	var r := FruitData.radius(level)
	var shape_node: CollisionShape2D = $CollisionShape2D
	var visual: Polygon2D = $Visual
	var cs := CircleShape2D.new()
	cs.radius = r
	shape_node.shape = cs
	visual.color = FruitData.color(level)
	visual.polygon = _circle_poly(r, 24)
	# Soft highlight ring via second poly would be P1; keep simple outline via color lift
	mass = maxf(0.4, r * r * 0.002)
	physics_material_override = _make_mat()
	linear_damp = 0.55
	angular_damp = 1.2
	contact_monitor = true
	max_contacts_reported = 8
	gravity_scale = 1.0
	can_sleep = true
	lock_rotation = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _make_mat() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = 0.22
	m.friction = 0.5
	return m

func _circle_poly(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var v := state.linear_velocity
	if v.length() > MAX_SPEED:
		state.linear_velocity = v.limit_length(MAX_SPEED)

func _on_body_entered(body: Node) -> void:
	if merging or level >= FruitData.MAX_LV:
		return
	if body == null or not (body is RigidBody2D):
		return
	var other := body as RigidBody2D
	if not other.has_method("is_fruit"):
		return
	if other.merging or other.level != level:
		return
	if get_instance_id() < other.get_instance_id():
		merge_wanted.emit(self, other)

func is_fruit() -> bool:
	return true

func top_y() -> float:
	return global_position.y - FruitData.radius(level)

func speed() -> float:
	return linear_velocity.length()
