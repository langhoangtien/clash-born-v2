class_name ItemDef
extends GameDef
## Trang bị (mục ITM): chỉ số là Modifier, kỹ năng dùng chung AbilityDef (ITM-02).

@export var cost: int
@export var modifiers: Array[ModifierDef] = []
## Kỹ năng chủ động hoặc bị động của món đồ (slot = ITEM). Có thể rỗng.
@export var ability: AbilityDef
## Số lần dùng; 0 = không giới hạn.
@export var charges: int

enum Category { ATTACK, MAGIC, DEFENSE, UTILITY }
## SHOP-07: danh mục trong cửa hàng.
@export var category: Category = Category.UTILITY
## Mô tả kỹ năng chủ động / bị động hiện ở khung chi tiết của cửa hàng (chỉ số tự sinh từ modifier).
@export_multiline var description: String

enum ShopKind { BASE, SECRET }
## SHOP-02: đồ thường (mua mọi nơi) hay đồ shop ẩn.
@export var shop: ShopKind = ShopKind.BASE
## SHOP-03: mở bán từ giây này (0 = ngay từ đầu).
@export var unlock_time: float
## SHOP-04: cả trận chỉ một món.
@export var unique: bool = false
