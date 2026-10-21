class_name ItemDef
extends GameDef
## Trang bị (mục ITM): chỉ số là Modifier, kỹ năng dùng chung AbilityDef (ITM-02).

@export var cost: int
@export var modifiers: Array[ModifierDef] = []
## Kỹ năng chủ động hoặc bị động của món đồ (slot = ITEM). Có thể rỗng.
@export var ability: AbilityDef
## Số lần dùng; 0 = không giới hạn.
@export var charges: int

enum Category { ATTACK, MAGIC, DEFENSE, UTILITY, BASIC }
## SHOP-07: danh mục trong cửa hàng.
@export var category: Category = Category.UTILITY
## Mô tả kỹ năng chủ động / bị động hiện ở khung chi tiết của cửa hàng (chỉ số tự sinh từ modifier).
@export_multiline var description: String

enum ShopKind { BASE, SECRET }
## SHOP-02: đồ thường (mua mọi nơi) hay đồ shop ẩn.
@export var shop: ShopKind = ShopKind.BASE
## SHOP-03: mở bán từ giây này (0 = ngay từ đầu).
@export var unlock_time: float
## WRD-01: mua thêm cộng `charges` vào món cùng loại đang có, tối đa chừng này lần dùng (0 = không gộp).
@export var max_stack: int
## SHOP-08: kho mỗi đội — có sẵn, tối đa, cứ bao nhiêu giây thêm 1 (stock_max 0 = không giới hạn).
@export var stock_initial: int
@export var stock_max: int
@export var stock_restock: float
## SHOP-09 (ECO-06): ghép từ các món này (id, lặp được). Giá `cost` là tổng; phí ghép = cost − tổng giá thành phần.
@export var components: Array[StringName] = []
## SHOP-04: cả trận chỉ một món.
@export var unique: bool = false
