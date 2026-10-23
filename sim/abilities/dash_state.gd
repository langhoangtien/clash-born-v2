class_name DashState
extends RefCounted
## Cú lướt đang diễn ra (ABL-08). DashSystem di chuyển, ActionRunner tạo.

var target_id: int
var speed: float
var actions: Array[ActionDef] = []
var ctx: ExprContext
var source_id: int
var untargetable: bool = true
