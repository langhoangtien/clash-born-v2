class_name RecipeTree
extends RefCounted
## Cây ghép đồ kiểu Liên Quân trong khung chi tiết shop (D-115, SHOP-09):
## món đang xem ở trên, các thành phần bên dưới nối bằng đường gấp khúc (tối đa 2 tầng),
## thành phần đang có trong túi viền xanh; hàng "Ghép thành" ở dưới cùng. Chạm một ô → xem món đó.

const ROOT_RADIUS: float = 32.0
const CHILD_RADIUS: float = 28.0
const LEVEL_GAP: float = 104.0
const INTO_RADIUS: float = 24.0
const INTO_STEP: float = 62.0
const LINE: Color = Color(1, 0.8, 0.4, 0.75)
const OWNED: Color = Color(0.4, 1, 0.5)


class TreeNode:
	extends RefCounted
	var def: ItemDef
	var center: Vector2
	var radius: float
	## Chỉ số nút cha trong danh sách; -1 = gốc hoặc hàng "Ghép thành".
	var parent: int = -1
	var owned: bool = false
	var into: bool = false


## Xếp các nút trong vùng bắt đầu ở `origin`, rộng `width`. Trả về [danh sách TreeNode, chiều cao].
static func layout(w: World, hero: Entity, d: ItemDef, origin: Vector2, width: float) -> Array:
	var nodes: Array[TreeNode] = []
	var root: TreeNode = _node(d, Vector2(origin.x + width * 0.5, origin.y + ROOT_RADIUS + 4), ROOT_RADIUS, -1)
	nodes.append(root)
	var bottom: float = root.center.y + ROOT_RADIUS
	var parts: Array[ItemDef] = _parts(w, d)
	var owned: Array[bool] = owned_flags(hero, d)
	var slot: float = width / maxf(1.0, parts.size())
	for i: int in range(parts.size()):
		var x: float = origin.x + slot * (i + 0.5)
		var child: TreeNode = _node(parts[i], Vector2(x, root.center.y + LEVEL_GAP), minf(CHILD_RADIUS, slot * 0.36), 0)
		child.owned = owned[i]
		nodes.append(child)
		var me: int = nodes.size() - 1
		bottom = maxf(bottom, child.center.y + child.radius)
		var grand: Array[ItemDef] = _parts(w, parts[i])
		var gslot: float = slot / maxf(1.0, grand.size())
		for j: int in range(grand.size()):
			var gx: float = x - slot * 0.5 + gslot * (j + 0.5)
			var g: TreeNode = _node(grand[j], Vector2(gx, child.center.y + LEVEL_GAP * 0.85), minf(22.0, gslot * 0.38), me)
			nodes.append(g)
			bottom = maxf(bottom, g.center.y + g.radius)
	var into: Array[ItemDef] = builds_into(w, d)
	if not into.is_empty():
		var y: float = bottom + 56.0 + INTO_RADIUS
		var per_row: int = maxi(1, int((width - 110.0) / INTO_STEP))
		for k: int in range(into.size()):
			var n: TreeNode = _node(into[k], Vector2(origin.x + 110.0 + INTO_RADIUS + (k % per_row) * INTO_STEP, y + (k / per_row) * INTO_STEP), INTO_RADIUS, -1)
			n.into = true
			nodes.append(n)
		bottom = y + ((into.size() - 1) / per_row) * INTO_STEP + INTO_RADIUS
	return [nodes, bottom - origin.y + 12.0]


## Món nhận `d` làm thành phần, theo tên.
static func builds_into(w: World, d: ItemDef) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for o: ItemDef in w.item_catalog.values():
		if o.components.has(d.id):
			out.append(o)
	out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.display_name < b.display_name)
	return out


## Từng thành phần của `d` có trong túi không (mỗi món trong túi chỉ tính cho một thành phần, như Shop.price).
static func owned_flags(hero: Entity, d: ItemDef) -> Array[bool]:
	var used: Array[int] = []
	var out: Array[bool] = []
	for id: StringName in d.components:
		var hit: bool = false
		for it: ItemInstance in Items.slots(hero):
			if it != null and it.def.id == id and not used.has(it.index):
				used.append(it.index)
				hit = true
				break
		out.append(hit)
	return out


## Phí ghép = giá món − tổng giá thành phần.
static func fee(w: World, d: ItemDef) -> int:
	var sum: int = 0
	for p: ItemDef in _parts(w, d):
		sum += p.cost
	return d.cost - sum


## Nút dưới điểm `at`, null nếu không trúng.
static func node_at(nodes: Array, at: Vector2) -> TreeNode:
	for n: TreeNode in nodes:
		if at.distance_to(n.center) <= n.radius + 6.0:
			return n
	return null


static func draw(panel: ShopPanel, font: Font, w: World, nodes: Array, origin: Vector2) -> void:
	for n: TreeNode in nodes:
		if n.parent >= 0:
			_elbow(panel, nodes[n.parent], n)
	var root: TreeNode = nodes[0]
	if nodes.size() > 1 and not (nodes[1] as TreeNode).into:
		var f: int = fee(w, root.def)
		if f > 0:
			panel.draw_string(font, root.center + Vector2(ROOT_RADIUS + 14, 6), "+ phí %d" % f, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.85, 0.3))
	for n: TreeNode in nodes:
		panel.draw_circle(n.center, n.radius + 3.0, Color(0.05, 0.06, 0.09))
		panel._draw_icon(font, n.center, n.radius, n.def, true)
		if n.owned:
			panel.draw_arc(n.center, n.radius + 3.0, 0, TAU, 32, OWNED, 3.0, true)
		if n.parent < 0 and not n.into:
			panel.draw_arc(n.center, n.radius + 3.0, 0, TAU, 32, Color(1, 0.9, 0.4), 3.0, true)
	var first_into: TreeNode = null
	for n: TreeNode in nodes:
		if n.into:
			first_into = n
			break
	if first_into != null:
		panel.draw_string(font, Vector2(origin.x, first_into.center.y + 6), "Ghép thành", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.7))


## Đường gấp khúc: từ đáy nút cha xuống nửa chừng, ngang tới cột nút con, xuống đỉnh nút con.
static func _elbow(panel: ShopPanel, p: TreeNode, c: TreeNode) -> void:
	var col: Color = OWNED if c.owned else LINE
	var mid: float = (p.center.y + p.radius + c.center.y - c.radius) * 0.5
	panel.draw_polyline(PackedVector2Array([p.center + Vector2(0, p.radius), Vector2(p.center.x, mid),
		Vector2(c.center.x, mid), c.center - Vector2(0, c.radius)]), col, 3.0, true)


static func _parts(w: World, d: ItemDef) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for id: StringName in d.components:
		var part: ItemDef = w.item_catalog.get(id)
		if part != null:
			out.append(part)
	return out


static func _node(d: ItemDef, at: Vector2, r: float, parent: int) -> TreeNode:
	var n: TreeNode = TreeNode.new()
	n.def = d
	n.center = at
	n.radius = r
	n.parent = parent
	return n
