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
## CMB-13 (D-125): khuếch đại phép mỗi điểm Trí tuệ (0.003 = +0.3%).
@export var spell_amp_per_intelligence: float = 0.0
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
## CMB-04b (D-125): trụ gây × sát thương lên lính đường (lính sống lâu hơn dưới trụ, đẩy trụ nhanh hơn).
@export var tower_creep_damage: float = 1.0
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
## CRP-11: cứ creep_upgrade_interval giây lính thêm creep_upgrade_step máu / sát thương.
@export var creep_upgrade_interval: float
@export var creep_upgrade_step: float
## CRP-12: lính siêu cấp (trụ 3 lane đổ) và siêu lính (cả 3 trụ 3 đổ).
@export var super_creep_hp: float
@export var super_creep_damage: float
@export var mega_creep_hp: float
@export var mega_creep_damage: float
@export var mega_extra_melee: int
@export var mega_creep_bounty: float
@export var creep_acquire_range: float
@export var creep_chase_leash: float
@export var creep_hero_aggro_range: float
@export var creep_hero_aggro_time: float
@export var creep_front_margin: float

@export_group("Cửa hàng (SHOP)")
## SHOP-02: bán kính quanh shop ẩn.
@export var shop_radius: float
## SHOP-05: tỉ lệ tiền khi bán, và thời gian hoàn đủ sau khi mua (giây).
@export var sell_ratio: float
@export var sell_full_refund_time: float

@export_group("Quái rừng (JGL)")
## JGL-05: lần đầu xuất hiện, chu kỳ kiểm tra hồi trại (giây), bán kính phải trống quanh tâm trại.
@export var jungle_first_spawn: float
@export var jungle_respawn_check: float
@export var camp_spawn_box: float
## JGL-01: bỏ đuổi khi mục tiêu / quái ra xa tâm trại chừng này, hoặc chừng này giây không bị đánh.
@export var jungle_leash: float
@export var jungle_aggro_time: float

@export_group("Hero")
## ABL-04: mỗi lần đổi điểm thừa cộng chừng này vào cả 3 thuộc tính.
@export var attribute_bonus: float
## ABL-04: số lần đổi điểm lấy thuộc tính tối đa; cấp tối đa.
@export var attribute_bonus_max: int
## TAL-01: cấp chọn talent.
@export var talent_level: int
@export var hero_max_level: int
## XP để lên cấp kế: xp_base + xp_per_level × (cấp hiện tại − 1).
@export var xp_base: int
@export var xp_per_level: int
## ECO-04: hồi sinh sau respawn_base + respawn_per_level × cấp giây.
@export var respawn_base: float
@export var respawn_per_level: float
## DTH-02: thời gian nằm chờ tái sinh (giây).
@export var reincarnate_delay: float
## WRD-04: máu ward tính theo đòn: mỗi đòn đánh của hero trừ ward_hero_hit, của lính / trụ / khác trừ ward_other_hit.
@export var ward_hero_hit: float
@export var ward_other_hit: float

@export_group("Trạng thái (ST)")
## ST-16: tốc chạy cố định khi HEXED.
@export var hex_move_speed: float
## ST-11: GHOST nhận sát thương phép × (1 + ghost_magic_amp).
@export var ghost_magic_amp: float

@export_group("Kinh tế (ECO)")
## ECO-01: cứ passive_gold_interval giây mỗi hero được passive_gold vàng.
@export var passive_gold: int
## D-106: vàng mỗi hero có lúc vào trận.
@export var starting_gold: int
@export var passive_gold_interval: float
## ECO-03: XP chia cho hero phe kia trong tầm này khi đơn vị chết.
@export var xp_share_range: float
## Hạ hero: XP = base + per_level × cấp nạn nhân; vàng = base + per_level × cấp nạn nhân.
@export var hero_kill_xp_base: float
@export var hero_kill_xp_per_level: float
@export var hero_kill_gold_base: int
@export var hero_kill_gold_per_level: int
## ECO-05: chết mất death_gold_per_level × cấp vàng.
@export var death_gold_per_level: int
## ECO-09: hero gây sát thương lên hero địch trong chừng này giây trước khi nó chết được tính hỗ trợ.
@export var assist_window: float

@export_group("Tầm nhìn (VIS)")
## VIS-07: ra tay trong bụi thì lộ chừng này giây.
@export var bush_reveal_time: float
## VIS-03: bán kính true sight quanh tâm fountain.
@export var fountain_true_sight: float

@export_group("Điều khiển (CTL)")
## CTL-02: tầm tìm mục tiêu = tầm đánh + chừng này.
@export var attack_search_bonus: float
## CTL-04: mục tiêu khóa cách mép xa hơn chừng này thì bỏ khóa.
@export var lock_break_range: float

@export_group("Bot (BOT, DEF-09/10)")
## DEF-09: vùng nguy hiểm trụ = tầm bắn + bán kính hero + chừng này.
@export var tower_danger_margin: float
## DEF-10: được vào vùng trụ khi trụ đang bắn đơn vị khác, có ≥ tower_tank_creeps lính phe mình trong tầm trụ và máu ≥ dive_min_hp.
@export var tower_tank_creeps: int
@export var dive_min_hp: float
## BOT-22: bot chỉ bán món có giá dưới mức này (đồ đầu trận) khi đầy ô.
@export var bot_sell_max_cost: int
## BOT-02/03: rút khi máu < bot_retreat_hp, đứng hồi tới bot_recover_hp (phần máu tối đa).
@export var bot_retreat_hp: float
@export var bot_recover_hp: float
## BOT-05: săn khi máu người chơi < bot_kill_hp và trong bot_kill_range.
@export var bot_kill_hp: float
@export var bot_kill_range: float
## BOT-04/05: không đuổi xa hơn chừng này tính từ chỗ bắt đầu đuổi (DEF-08).
@export var bot_chase_leash: float
## BOT-04: đánh trả trong chừng này giây sau khi bị hero gây giao tranh (DEF-11).
@export var bot_trade_window: float
## BOT-09: đứng sau hàng lính phe mình chừng này.
@export var bot_lane_offset: float
## BOT-18: đang hơn khi hơn chừng này mạng hoặc cấp; khi đó lao trụ chỉ cần bot_siege_tanks lính đỡ và máu ≥ bot_siege_min_hp.
@export var bot_ahead_kills: int
@export var bot_ahead_levels: int
@export var bot_siege_tanks: int
@export var bot_siege_min_hp: float

@export_group("Fountain (STR-04)")
@export var fountain_radius: float
## RCL-01: thời gian kênh về thành (giây).
@export var recall_time: float
## STR-04 (D-101): fountain chỉ bắn hero địch trong bán kính này (nhỏ hơn vùng hồi máu) để đánh được nhà chính.
@export var fountain_attack_radius: float
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
