class_name DashAction
extends ActionDef
## Lướt tới mục tiêu (ABL-08).

@export var speed: String
@export var on_arrive: Array[ActionDef] = []
## ABL-08b: false = vẫn bị nhắm khi lướt (Quyết Đấu).
@export var untargetable: bool = true
## ABL-08c: true = bay qua vách / rừng / thân trụ; lướt xong mà kẹt thì về chỗ đi được gần nhất.
@export var over_terrain: bool = false
