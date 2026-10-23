class_name AreaAction
extends ActionDef
## Vùng (ABL-06, ABL-07, ABL-13): sau `delay` chạy `actions` lên mọi đơn vị hợp lệ trong
## vùng. CIRCLE: `target` là tâm, bán kính `radius`. RECT: bắt đầu từ chủ kỹ năng, dài
## `length`, rộng `width`, theo hướng chọn lúc tung. CONE: quạt góc `angle` bán kính `radius`
## từ chủ kỹ năng theo hướng chọn lúc tung (ABL-20). `falloff`: giảm theo khoảng cách.

enum Shape { CIRCLE, RECT, CONE }

@export var shape: Shape = Shape.CIRCLE
@export var radius: String
@export var length: String
@export var width: String
## CONE (ABL-20): góc mở (độ), đỉnh ở chủ kỹ năng, bán kính `radius`.
@export var angle: String
@export var delay: String
@export var falloff: String
@export var actions: Array[ActionDef] = []
