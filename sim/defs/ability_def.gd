class_name AbilityDef
extends GameDef
## Kỹ năng của hero hoặc của đồ (ARCHITECTURE 3.4, mục ABL, ITM-02).

enum Slot { INNATE, Q, W, R, ITEM }
enum Targeting { PASSIVE, NO_TARGET, UNIT, POINT, DIRECTION }
enum Team { ENEMY, ALLY, SELF, ANY }
enum BotUsage { DISABLE, POKE, FINISH, ENGAGE, ESCAPE, SELF_DEFENSE, TEAMFIGHT }  # BOT-13

## Số phần tử của mảng giá trị theo ô (ABL-01, ABL-11). Đồ không có cấp.
const RANKS: Dictionary[Slot, int] = {Slot.INNATE: 6, Slot.Q: 5, Slot.W: 5, Slot.R: 3, Slot.ITEM: 1}
## Tên giá trị mà hệ thống kỹ năng đọc trực tiếp (ABL-02).
const SYSTEM_VALUES: PackedStringArray = ["cooldown", "mana", "cast_range"]

@export var slot: Slot = Slot.Q
@export var targeting: Targeting = Targeting.NO_TARGET
@export var target_team: Team = Team.ENEMY
@export var hits_heroes: bool = true
@export var hits_creeps: bool = true
@export var hits_neutrals: bool = true
@export var hits_structures: bool = false
@export var pierces_magic_immunity: bool = false  # ST-15
## Giá trị có tên theo cấp (ABL-09): tên → một số cho mỗi cấp.
@export var values: Dictionary[StringName, PackedFloat32Array] = {}
@export var cast_time: String
@export var on_cast: Array[ActionDef] = []
## Bị động: áp hiệu ứng vĩnh viễn khi học / lên cấp (ARCHITECTURE 3.4).
@export var on_learn: Array[ActionDef] = []
@export var talent: TalentDef
@export var bot_usages: Array[BotUsage] = []
## Điều kiện dữ liệu cho bot (CONTENT "Cách bot dùng skill"); kiểm tra ở M7.
@export var bot_conditions: Array[StringName] = []


func value_names() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key: StringName in values:
		out.append(String(key))
	return out


func expected_ranks() -> int:
	return RANKS[slot]
