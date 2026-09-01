class_name FruitData
extends RefCounted

## 11 tiers: radius / color / merge score (matches original plan).
const RADII := [18.0, 25.0, 34.0, 44.0, 56.0, 70.0, 85.0, 100.0, 118.0, 138.0, 160.0]
const SCORES := [1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 100]
# Match original BASE_LEVELS hex colors.
const COLORS := [
	Color(1.0, 0.42, 0.42),       # FF6B6B
	Color(1.0, 0.608, 0.243),     # FF9B3E
	Color(1.0, 0.824, 0.247),     # FFD23F
	Color(0.494, 0.851, 0.341),   # 7ED957
	Color(0.0, 0.749, 0.647),     # 00BFA5
	Color(0.161, 0.714, 0.965),   # 29B6F6
	Color(0.486, 0.302, 1.0),     # 7C4DFF
	Color(1.0, 0.502, 0.671),     # FF80AB
	Color(1.0, 0.341, 0.133),     # FF5722
	Color(0.914, 0.118, 0.388),   # E91E63
	Color(0.263, 0.627, 0.278),   # 43A047
]
const DROP_MAX_LV := 4
const MAX_LV := 10

static func radius(lv: int) -> float:
	return float(RADII[clampi(lv, 0, MAX_LV)])

static func color(lv: int) -> Color:
	return COLORS[clampi(lv, 0, MAX_LV)]

static func score(lv: int) -> int:
	return int(SCORES[clampi(lv, 0, MAX_LV)])

static func random_drop_lv() -> int:
	return randi_range(0, DROP_MAX_LV)
