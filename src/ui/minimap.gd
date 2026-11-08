## The floor's map, drawn from the real floor plan: one pixel a tile, baked
## into a texture whenever what is known changes (a room entered, a room
## sealed or opened), so it costs nothing per frame. Rooms keep their true
## shapes, passages run between them, pillars and closed gates show.
##
## The minimap (top right) follows this Kindled. The full map (Tab) dims the
## world and fits everything known into most of the screen; the mouse wheel
## zooms in around you. Both draw every Kindled of the party in its colour -
## where each one really is on this machine - and the same icons, from the
## same knowledge (`known_rooms`).
class_name Minimap
extends Control

var big := false
var zoom := 1                       # the full map: 1 fits the floor, 2-3 close in on you

var _img: Image
var _tex: ImageTexture
var _sig := ""
var _owner := PackedInt32Array()     # tile -> room (passages belong to the nearest room)
var _owner_lay: Object = null        # the layout `_owner` was made for
var _walk := PackedInt32Array()      # every tile a room owns (they can change: a gate closes)
var _edge := PackedInt32Array()      # every wall touching one
var _edge_rooms: Array = []          # ...and the rooms each touches
var _bounds := Rect2i()              # the tiles of everything known
var _centre := Vector2(-1, -1)       # minimap: where it looks (tiles), eased

const C_FLOOR := Color(0.25, 0.23, 0.31)
const C_FLOOR_HERE := Color(0.44, 0.34, 0.25)
const C_FLOOR_KNOWN := Color(0.12, 0.11, 0.17)
const C_WALL := Color(0.62, 0.53, 0.43)
const C_WALL_KNOWN := Color(0.28, 0.25, 0.31)
const C_BLOCK := Color(0.47, 0.40, 0.34)
const C_PIT := Color(0.03, 0.03, 0.05)
const C_GATE := Color(0.95, 0.38, 0.26)
const LOCK_COLS := {"key": Color(1.0, 0.82, 0.4), "lever": Color(0.62, 0.68, 0.78), "pale": Color(0.72, 0.62, 1.0)}
const C_SELF := Color(1.0, 0.78, 0.38)


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if not big:
		return
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = mini(3, zoom + 1)
			accept_event()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxi(1, zoom - 1)
			accept_event()


## What this machine knows of the floor: 2 = walked, 1 = seen through a door
## (or felt: a guardian's lair, a remembered floor).
static func known_rooms(d: Dungeon) -> Dictionary:
	var lay := d.layout
	var known := {}
	for r in lay.rooms:
		if r.visited:
			known[r.id] = 2
	for r in lay.rooms:
		if r.visited:
			for dd in r.doors:
				if not dd.secret and not known.has(dd.to):
					known[dd.to] = 1
	if lay.boss_depth and not known.has(lay.exit_id):
		known[lay.exit_id] = 1
	if d.has_key and lay.vault_room >= 0 and not known.has(lay.vault_room):
		known[lay.vault_room] = 1     # the key shows where it fits
	if d.remembered() or d.charted or Game.chart_run:
		for r in lay.rooms:
			if not known.has(r.id):
				known[r.id] = 1
	return known


func _draw() -> void:
	var d := Game.stage as Dungeon
	if d == null or d.layout == null or d.grid == null:
		return
	var known := known_rooms(d)
	_bake(d, known)
	if big:
		_draw_big(d, known)
	else:
		_draw_mini(d, known)


# --- the floor plan texture --------------------------------------------------------

func _bake(d: Dungeon, known: Dictionary) -> void:
	var g := d.grid
	if _owner_lay != d.layout or _owner.size() != g.width * g.height:
		_owner_lay = d.layout
		_owner = _owners(g)
		_index(g)
		_sig = ""
	var keys := known.keys()
	keys.sort()
	var sig := "%s|%s|%d|%d|%d" % [str(keys), str(known.values()), d.current_room.id if d.current_room else -1, d.active_room.id if d.active_room else -1, d.layout.locks.filter(func(l): return l.open).size()]
	if sig == _sig and _tex:
		return
	_sig = sig
	var t_bake := Dev.tick()
	if _img == null or _img.get_width() != g.width or _img.get_height() != g.height:
		_img = Image.create(g.width, g.height, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	var here := d.current_room.id if d.current_room else -1
	var mn := Vector2i(g.width, g.height)
	var mx := Vector2i(-1, -1)
	var w := g.width
	# barred ways in the colour of what opens them, never the red of a room's seal
	var barred := {}
	for lk in d.layout.locks:
		if not lk.open:
			for bt: Vector2i in lk.tiles:
				barred[bt.y * w + bt.x] = LOCK_COLS.get(String(lk.kind), C_GATE)
	# (the lists made in `_index`: walking every tile of the grid here took 30 ms
	# in script on every room change, a visible hitch at a door)
	for i in _walk:
		var rid := _owner[i]
		if not known.has(rid):
			continue
		var x := i % w
		var y := i / w
		var t := g.at(x, y)
		var lvl: int = known[rid]
		var c := C_FLOOR if lvl == 2 else C_FLOOR_KNOWN
		if rid == here:
			c = C_FLOOR_HERE
		match t:
			TileGrid.PILLAR:
				c = C_BLOCK if lvl == 2 else C_WALL_KNOWN
			TileGrid.PIT:
				c = C_PIT
			TileGrid.GATE:
				c = barred.get(i, C_GATE)
		_img.set_pixel(x, y, c)
		mn = Vector2i(mini(mn.x, x), mini(mn.y, y))
		mx = Vector2i(maxi(mx.x, x), maxi(mx.y, y))
	# walls: the edge around what is shown
	for k in _edge.size():
		var best := 0
		for r2 in _edge_rooms[k]:
			if known.has(r2):
				best = maxi(best, int(known[r2]))
		if best > 0:
			var i: int = _edge[k]
			_img.set_pixel(i % w, i / w, C_WALL if best == 2 else C_WALL_KNOWN)
	if mx.x < 0:
		mn = Vector2i.ZERO
		mx = Vector2i(g.width - 1, g.height - 1)
	_bounds = Rect2i(mn - Vector2i(2, 2), mx - mn + Vector2i(5, 5))
	if _tex == null or _tex.get_width() != g.width or _tex.get_height() != g.height:
		_tex = ImageTexture.create_from_image(_img)
	else:
		_tex.update(_img)
	Dev.lap("map", t_bake, 1.0)


## Which tiles the plan ever draws, listed once per floor.
func _index(g: TileGrid) -> void:
	_walk = PackedInt32Array()
	_edge = PackedInt32Array()
	_edge_rooms = []
	for y in g.height:
		for x in g.width:
			var t := g.at(x, y)
			if t == TileGrid.VOID:
				continue
			var i := y * g.width + x
			if t != TileGrid.WALL:
				if _owner[i] >= 0:
					_walk.append(i)
				continue
			var rooms := PackedInt32Array()
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var nx := x + ox
					var ny := y + oy
					if nx < 0 or ny < 0 or nx >= g.width or ny >= g.height:
						continue
					var t2 := g.at(nx, ny)
					if t2 == TileGrid.VOID or t2 == TileGrid.WALL:
						continue
					var r2 := _owner[ny * g.width + nx]
					if r2 >= 0 and not rooms.has(r2):
						rooms.append(r2)
			if not rooms.is_empty():
				_edge.append(i)
				_edge_rooms.append(rooms)


## Every walkable tile's room: a room's own tiles, and the passages between
## rooms split between the rooms they lead from (the nearest one).
static func _owners(g: TileGrid) -> PackedInt32Array:
	var own := PackedInt32Array()
	own.resize(g.width * g.height)
	var q: Array[Vector2i] = []
	for y in g.height:
		for x in g.width:
			var i := y * g.width + x
			own[i] = g.room_of[i]
			if own[i] >= 0:
				q.append(Vector2i(x, y))
	var head := 0
	while head < q.size():
		var p := q[head]
		head += 1
		var r := own[p.y * g.width + p.x]
		for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := p + dv
			if not g.inb(n.x, n.y):
				continue
			var j := n.y * g.width + n.x
			if own[j] >= 0:
				continue
			var t := g.at(n.x, n.y)
			if t == TileGrid.VOID or t == TileGrid.WALL:
				continue
			own[j] = r
			q.append(n)
	return own


# --- the minimap ---------------------------------------------------------------------

func _draw_mini(d: Dungeon, known: Dictionary) -> void:
	var r := Rect2(Vector2.ZERO, size)
	_frame(r)
	var inner := r.grow(-2)
	var me: Player = d.player
	var want := me.pos if me else Vector2(_bounds.get_center())
	_centre = want if _centre.x < 0.0 or _centre.distance_to(want) > 30.0 else _centre.lerp(want, 0.25)
	# four screen pixels a tile at the usual interface size (never under two)
	var us := float(maxi(1, Settings.effective_ui_scale()))
	var px := maxf(2.0, roundf(us * 1.34)) / us
	var origin := (inner.get_center() - _centre * px).round()
	draw_set_transform(Vector2.ZERO)
	# the plan, clipped to the frame
	var src := Rect2((inner.position - origin) / px, inner.size / px)
	draw_texture_rect_region(_tex, inner, src)
	_icons(d, known, origin, px, inner, 8.0)
	_markers(d, origin, px, inner, false)


# --- the full map ---------------------------------------------------------------------

func _draw_big(d: Dungeon, known: Dictionary) -> void:
	var vp := size
	# the world stays in sight, quieted
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.01, 0.01, 0.03, 0.55))
	var pw := minf(vp.x - 32.0, maxf(320.0, vp.y * 1.6))
	var ph := vp.y - 40.0
	var panel := Rect2(((vp - Vector2(pw, ph)) * 0.5).round(), Vector2(pw, ph).round())
	var sb := UIKit.theme().get_stylebox("panel", "DarkPanel")
	draw_style_box(sb, panel)
	# the header: where (large), which floor and how deep, the Tier
	var lay := d.layout
	var region := Delve.NAME if d.run.delve else String(d.region.name)
	var fl := String(Delve.floor_def(lay.region, lay.depth, d.run.delve)[0])
	var depth := Delve.depth_short(lay.region, lay.depth, d.run.delve)
	var hx := panel.position.x + 10.0
	var hy := panel.position.y + 8.0
	draw_string(UIKit.FONT_OUTLINE, Vector2(hx, hy + 13.0), region.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x * 0.6, 16, UIKit.C_GOLD)
	var sub := ("%s  -  %s" % [fl, depth]) if fl != "" else depth
	draw_string(UIKit.FONT, Vector2(hx, hy + 25.0), sub, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x * 0.6, 8, UIKit.C_TEXT)
	var tier := "TIER %s" % Difficulty.roman(d.run.tier)
	var tw := UIKit.FONT_OUTLINE.get_string_size(tier, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var tx := panel.end.x - 10.0 - tw
	draw_string(UIKit.FONT_OUTLINE, Vector2(tx, hy + 13.0), tier, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIKit.C_EMBER)
	if lay.boss_depth:
		var gw := UIKit.FONT.get_string_size("A guardian's floor", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(UIKit.FONT, Vector2(panel.end.x - 10.0 - gw, hy + 25.0), "A guardian's floor", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.6, 0.5))
	var sep_y := hy + 31.0
	draw_rect(Rect2(panel.position.x + 8.0, sep_y, panel.size.x - 16.0, 1.0), Color(0.35, 0.27, 0.22))
	# the map area, with a line at the foot for the key and the hint
	var area := Rect2(panel.position.x + 10.0, sep_y + 6.0, panel.size.x - 20.0, panel.end.y - sep_y - 30.0)
	var b := _bounds
	var fit := minf(area.size.x / float(b.size.x), area.size.y / float(b.size.y))
	# a whole number of screen pixels a tile, as large as fits: the plan stays crisp
	var us := float(maxi(1, Settings.effective_ui_scale()))
	var px := maxf(1.0, floorf(fit * us)) / us
	# a floor barely begun is not blown up: at most eight screen pixels a tile
	px = minf(px, 8.0 / us)
	px *= zoom
	var origin := area.get_center() - Vector2(b.get_center()) * px
	if zoom > 1 and d.player:
		# closer in: around this Kindled, kept within the floor
		origin = area.get_center() - d.player.pos * px
	origin = origin.round()
	var src := Rect2((area.position - origin) / px, area.size / px)
	draw_texture_rect_region(_tex, area, src)
	_icons(d, known, origin, px, area, 12.0)
	_markers(d, origin, px, area, true)
	# the key: what the icons on this map mean, and the hint
	var ky := panel.end.y - 14.0
	var kx := panel.position.x + 10.0
	var seen := {}
	for r in lay.rooms:
		if known.has(r.id):
			var ic := _room_icon(r, int(known[r.id]) == 2)
			if ic != "" and not seen.has(ic):
				seen[ic] = true
	for ic in ["stairs", "boss", "merchant", "shrine", "chest", "skull", "vigor", "embers", "relic", "key", "eye", "heart", "sun", "star"]:
		if not seen.has(ic):
			continue
		var name: String = KEY_NAMES.get(ic, "")
		var nw := UIKit.FONT.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		if kx + 12.0 + nw > panel.end.x - 120.0:
			break
		draw_texture_rect(UIKit.icon(ic), Rect2(kx, ky - 4.0, 8, 8), false)
		draw_string(UIKit.FONT, Vector2(kx + 10.0, ky + 3.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIKit.C_DIM)
		kx += 18.0 + nw
	var hint := "%s close   Wheel zoom" % Settings.describe_action("map")
	var hw := UIKit.FONT.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(UIKit.FONT, Vector2(panel.end.x - 10.0 - hw, ky + 3.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.75, 0.66, 0.55))


const KEY_NAMES := {"stairs": "Stairs", "boss": "Guardian", "merchant": "Peddler", "shrine": "Shrine", "chest": "Treasure",
	"skull": "Elite / Trial", "vigor": "Rest", "embers": "Well", "relic": "Echo", "key": "Hidden", "eye": "Colossus",
	"heart": "Heartroot", "sun": "Sun-disc", "star": "Landmark"}


# --- shared: icons and markers ------------------------------------------------------------

func _icons(d: Dungeon, known: Dictionary, origin: Vector2, px: float, clip: Rect2, s: float) -> void:
	for r in d.layout.rooms:
		if not known.has(r.id):
			continue
		var visited: bool = int(known[r.id]) == 2
		var ic := _room_icon(r, visited)
		if ic == "":
			continue
		var c := origin + (Vector2(r.rect.position) + Vector2(r.rect.size) * 0.5) * px
		var rr := Rect2((c - Vector2(s, s) * 0.5).round(), Vector2(s, s))
		if not clip.encloses(rr):
			continue
		draw_texture_rect(UIKit.icon(ic), rr, false, Color(1, 1, 1, 0.95 if not visited else 0.7))


## Every Kindled where it is on this machine (a guest's own is predicted, the
## others drawn from the host's word): its colour, and on the full map its
## name. One beyond the minimap's edge shows as a pip on the edge, toward it.
func _markers(d: Dungeon, origin: Vector2, px: float, clip: Rect2, names: bool) -> void:
	# pings: a ring in the pinger's colour, while it lasts
	for pg in d.pings:
		var at: Vector2 = origin + (pg.pos as Vector2) * px
		if clip.has_point(at):
			draw_arc(at, 3.0 + fmod(float(pg.t) * 3.0, 2.0), 0.0, TAU, 12, pg.col, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	var me := d.player
	var order: Array = []
	for p in d.players:
		if is_instance_valid(p) and p != me:
			order.append(p)
	if me and is_instance_valid(me):
		order.append(me)     # drawn last: on top
	var taken: Array[Rect2] = []     # name labels already drawn (two side by side stack)
	for p: Player in order:
		var mine := p == me
		var col := C_SELF if (mine and d.players.size() <= 1) else Net.color_of(p.peer_id)
		var at := origin + p.pos * px
		if not clip.grow(-2.0).has_point(at):
			if names:
				continue
			# off the minimap: a pip on its edge, toward them
			var c := clip.get_center()
			var dir := (at - c)
			var k := minf((clip.size.x * 0.5 - 3.0) / maxf(0.001, absf(dir.x)), (clip.size.y * 0.5 - 3.0) / maxf(0.001, absf(dir.y)))
			var e := (c + dir * k).round()
			draw_rect(Rect2(e - Vector2(2, 2), Vector2(4, 4)), Color(0.02, 0.02, 0.04))
			draw_rect(Rect2(e - Vector2(1, 1), Vector2(2, 2)), col)
			continue
		at = at.round()
		var r := 3.0 if mine else 2.5
		if names:
			r += 1.0
		if p.downed or not p.alive:
			col = Color(1.0, 0.35, 0.3) if int(t * 3.0) % 2 == 0 else Color(0.5, 0.15, 0.15)
		elif p.away:
			col = Color(col, 0.45)
		var shape := Minimap.player_mark(at, r, mine)
		draw_colored_polygon(shape[0], Color(0.02, 0.02, 0.04))
		draw_colored_polygon(shape[1], col)
		if mine and shape.size() > 2:
			draw_colored_polygon(shape[2], Color(1.0, 0.95, 0.8))     # a pale heart: this one is you
		if names and d.players.size() > 1:
			var nm := Net.name_of(p.peer_id)
			var w := UIKit.FONT_OUTLINE.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			var lr := Rect2(at + Vector2(r + 3.0, -5.0), Vector2(w, 9.0))
			for k in 4:
				var clash := false
				for tr in taken:
					if tr.intersects(lr):
						clash = true
				if not clash:
					break
				lr.position.y += 9.0
			taken.append(lr)
			draw_string(UIKit.FONT_OUTLINE, lr.position + Vector2(0, 8.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


## A Kindled on the map: an outlined diamond, and for your own a pale heart in it. Nothing
## reaches past the diamond (the facing line that used to stick out of it is gone: it
## only cluttered the map). [outline, fill, heart?]
static func player_mark(at: Vector2, r: float, mine: bool) -> Array:
	var out: Array = [
		PackedVector2Array([at + Vector2(0, -r - 1), at + Vector2(r + 1, 0), at + Vector2(0, r + 1), at + Vector2(-r - 1, 0)]),
		PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]),
	]
	if mine:
		out.append(PackedVector2Array([at + Vector2(0, -1), at + Vector2(1, 0), at + Vector2(0, 1), at + Vector2(-1, 0)]))
	return out


func _frame(r: Rect2) -> void:
	draw_rect(r, Color(0.02, 0.02, 0.04, 0.86))
	draw_rect(r.grow(-1), Color(0.03, 0.03, 0.05, 0.6))
	draw_rect(r, Color(0.05, 0.04, 0.06), false, 1.0)
	draw_rect(r.grow(-1), Color(0.40, 0.31, 0.24), false, 1.0)
	# iron studs at the corners
	for c in [r.position, Vector2(r.end.x - 3, r.position.y), Vector2(r.position.x, r.end.y - 3), r.end - Vector2(3, 3)]:
		draw_rect(Rect2(c, Vector2(3, 3)), Color(0.62, 0.48, 0.30))
		draw_rect(Rect2(c + Vector2(1, 1), Vector2(1, 1)), Color(1.0, 0.82, 0.5))


static func _room_icon(r: Room, visited: bool) -> String:
	if r.landmark != "":
		return {"colossus": "eye", "heartroot": "heart", "sundisc": "sun"}.get(r.landmark, "star")
	match r.type:
		Room.Type.SECRET:
			return "key" if not visited else ""
		Room.Type.BOSS:
			return "boss"
		Room.Type.STAIRS:
			return "stairs"
		Room.Type.MERCHANT:
			return "merchant"
		Room.Type.SHRINE:
			return "shrine"
		Room.Type.TREASURE:
			return "chest" if not visited else ""
		Room.Type.ELITE:
			return "skull" if not r.cleared else ""
		Room.Type.REST:
			return "vigor"
		Room.Type.EVENT:
			return {"well": "embers", "trial": "skull", "echo": "relic"}.get(r.event, "") if not r.visited or r.event == "trial" else ""
	return ""
