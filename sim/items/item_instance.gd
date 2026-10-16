class_name ItemInstance
extends RefCounted
## Một món đồ trong ô (ITM-01, ITM-07).

var def: ItemDef
## Chỉ số ô 0..5 (hiển thị và `item_slot` = index + 1).
var index: int
## Số lần dùng còn lại (`def.charges` > 0 mới có ý nghĩa).
var charges: int = 0
## Nguồn modifier chỉ số của món (World.next_serial).
var serial: int
## Kỹ năng của món (chủ động hoặc bị động), luôn rank 1; null nếu món không có kỹ năng.
var ability: AbilityInstance
## Tick mua (bán hoàn đủ trong thời gian ngắn, SHOP).
var bought_tick: int = 0
