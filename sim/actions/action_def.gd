class_name ActionDef
extends Resource
## Lớp cha của hành động (ARCHITECTURE 3.5). Mỗi loại một file trong sim/actions/;
## thêm loại mới = cơ chế mới (AGENTS mục 3). M0.5 chỉ có dữ liệu; thực thi ở M3.
## Trường `String` là biểu thức (EFF-09), đọc giá trị có tên của kỹ năng.

## Ai nhận hành động.
enum Target {
	SELF,          # chủ kỹ năng / chủ hiệu ứng
	TARGET,        # mục tiêu của kỹ năng, hoặc từng đơn vị trúng vùng/đạn
	EVENT_SOURCE,  # kẻ gây ra sự kiện (trigger)
	EVENT_TARGET,  # đối tượng của sự kiện (trigger)
}

@export var target: Target = Target.TARGET
