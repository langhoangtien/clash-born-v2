class_name BalanceSettings
extends Resource
## Hệ số công thức chỉ số và sát thương (STAT-04, CMB-03, CMB-11). Giá trị nằm trong
## content/balance/balance_settings.tres, không đặt trong code (AGENTS mục 4).

@export_group("Thuộc tính → chỉ số (STAT-04)")
@export var hp_per_strength: float
@export var hp_regen_per_strength: float
@export var armor_per_agility: float
@export var attack_speed_per_agility: float
@export var mana_per_intelligence: float
@export var mana_regen_per_intelligence: float
@export var magic_armor_per_intelligence: float
@export var primary_damage_coefficient: float

@export_group("Sát thương (CMB-03)")
## Hệ số giáp: hệ số nhận = 1 / (1 + k × |giáp|), giáp âm đối xứng quanh 1.
@export var armor_coefficient: float

@export_group("Tốc đánh")
@export var minimum_attacks_per_second: float
@export var maximum_attacks_per_second: float
## Trần thứ hai: không quá N lần tốc gốc (1 / base_attack_time).
@export var maximum_attack_speed_multiplier: float
@export var minimum_attack_interval: float

@export_group("Giới hạn khác")
## 1.0 = không giới hạn né (CMB-11, D-33).
@export var evasion_cap: float
@export var status_resistance_cap: float
@export var minimum_movement_speed: float

@export_group("Công trình (CMB-04, STR)")
@export var hero_structure_damage: float
@export var creep_structure_damage: float
@export var siege_structure_damage: float
## STR-01: trụ nhớ hero gây giao tranh hero trong chừng này giây.
@export var tower_aggro_time: float

@export_group("Lính đường (CRP)")
@export var first_wave_time: float
@export var wave_interval: float
@export var wave_melee: int
@export var wave_ranged: int
@export var siege_every_waves: int
@export var creep_acquire_range: float
@export var creep_chase_leash: float
@export var creep_hero_aggro_range: float
@export var creep_hero_aggro_time: float
@export var creep_front_margin: float

@export_group("Hero")
## ABL-04: mỗi lần đổi điểm thừa cộng chừng này vào cả 3 thuộc tính.
@export var attribute_bonus: float
## ECO-04: hồi sinh sau respawn_base + respawn_per_level × cấp giây.
@export var respawn_base: float
@export var respawn_per_level: float

@export_group("Điều khiển (CTL)")
## CTL-02: tầm tìm mục tiêu = tầm đánh + chừng này.
@export var attack_search_bonus: float
## CTL-04: mục tiêu khóa cách mép xa hơn chừng này thì bỏ khóa.
@export var lock_break_range: float

@export_group("Fountain (STR-04)")
@export var fountain_radius: float
## Phần máu/mana tối đa hồi mỗi giây.
@export var fountain_regen: float
@export var fountain_damage: float
@export var fountain_attack_interval: float

@export_group("Di chuyển (MOV)")
## MOV-04: tốc độ tối đa một đơn vị bị đẩy ra khi chồng lên đơn vị khác.
@export var separation_speed: float
## MAP-01: bán kính thân trụ chặn đứng/đi.
@export var tower_body_radius: float


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if armor_coefficient <= 0.0:
		errors.append("armor_coefficient phải > 0")
	if minimum_attacks_per_second <= 0.0 or minimum_attacks_per_second > maximum_attacks_per_second:
		errors.append("cần 0 < minimum_attacks_per_second ≤ maximum_attacks_per_second")
	if maximum_attack_speed_multiplier < 1.0:
		errors.append("maximum_attack_speed_multiplier phải ≥ 1")
	if minimum_attack_interval <= 0.0:
		errors.append("minimum_attack_interval phải > 0")
	if evasion_cap < 0.0 or evasion_cap > 1.0:
		errors.append("evasion_cap trong [0, 1]")
	if status_resistance_cap < 0.0 or status_resistance_cap > 1.0:
		errors.append("status_resistance_cap trong [0, 1]")
	if separation_speed <= 0.0 or tower_body_radius <= 0.0:
		errors.append("separation_speed và tower_body_radius phải > 0")
	if hp_per_strength <= 0.0 or mana_per_intelligence < 0.0 or minimum_movement_speed < 0.0:
		errors.append("hệ số thuộc tính / tốc chạy không hợp lệ")
	return errors
