## The Hearthtree: a zoomable, pannable constellation of skills radiating from
## the Hearth. Allocated paths burn gold with travelling sparks; available
## nodes pulse; hovering shows a full tooltip; unlocking bursts with light.
class_name SkillTreeUI
extends Control

const BRANCH_ICON := {"blade": "sword", "pyre": "flame", "rime": "snow", "gloam": "feather", "bulwark": "shield", "kindle": "wick"}

var zoom := 1.0
var pan := Vector2.ZERO
var hovered := ""
var _t := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragged := false
var _bursts: Array = []
var _stars: Array = []
var points_lbl: Label
var info_lbl: Label
var respec_btn: Button
var hearth_btn: Button
var tip: PanelContainer
var tip_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 220:
		_stars.append([Vector2(rng.randf_range(-700, 700), rng.randf_range(-500, 500)), rng.randf(), rng.randi_range(0, 2)])
	var top := UIKit.panel()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 6
	top.offset_right = -6
	top.offset_top = 6
	add_child(top)
	var row := UIKit.hbox(8)
	top.add_child(row)
	var title := UIKit.label("THE HEARTHTREE", 16, UIKit.C_GOLD, true)
	row.add_child(title)
	var info := UIKit.vbox(0)
	points_lbl = UIKit.label("", 8, UIKit.C_EMBER)
	info_lbl = UIKit.label("", 8, UIKit.C_DIM)
	info.add_child(points_lbl)
	info.add_child(info_lbl)
	row.add_child(info)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	hearth_btn = UIKit.button("Feed the Hearth", _feed_hearth, 70)
	row.add_child(hearth_btn)
	respec_btn = UIKit.button("Respec", _respec, 50)
	row.add_child(respec_btn)
	row.add_child(UIKit.button("Close", func() -> void: Game.ui.close_top(), 50))
	var hint := UIKit.label("LMB kindle   RMB refund   Wheel zoom   Drag to pan", 8, UIKit.C_DIM, true)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 8
	hint.offset_top = -14
	hint.offset_bottom = -4
	add_child(hint)
	tip = UIKit.panel()
	tip.add_theme_stylebox_override("panel", UIKit.theme().get_stylebox("panel", "TooltipPanel"))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_box = UIKit.vbox(2)
	tip.add_child(tip_box)
	tip.visible = false
	add_child(tip)
	_refresh_header()
	Profile.changed.connect(_refresh_header)
	# fit the whole constellation below the header
	zoom = clampf((get_viewport_rect().size.y - 50.0) / (2.0 * 7.4 * SkillDB.RING), 0.35, 1.6)
	pan = Vector2(0, 14.0 / zoom)


func _exit_tree() -> void:
	if Profile.changed.is_connected(_refresh_header):
		Profile.changed.disconnect(_refresh_header)
	Profile.save_profile()
	# the player in the sanctuary feels new nodes immediately
	if Game.stage and Game.stage.player:
		Game.stage.player.rebuild_stats()
		Game.stage.player.ability_slots = Profile.slots()


func _refresh_header() -> void:
	var free := Profile.skill_points_free()
	points_lbl.text = "%d point%s to spend  -  Level %d" % [free, "" if free == 1 else "s", Profile.level()]
	var counts := SkillDB.branch_counts(Profile.skills())
	var parts: Array = []
	for b in SkillDB.BRANCHES:
		if counts.has(b):
			parts.append("%s %d" % [SkillDB.BRANCHES[b].name, counts[b]])
	info_lbl.text = "  ".join(parts) if not parts.is_empty() else "Your path is unwritten."
	var rc := Profile.respec_cost()
	respec_btn.text = "Respec" if rc == 0 else "Respec (%d)" % rc
	respec_btn.disabled = Profile.skills().size() <= 1 or Profile.currency("embers") < rc
	var hc := Profile.building_cost("hearth")
	if hc.is_empty():
		hearth_btn.text = "Hearth: max"
		hearth_btn.disabled = true
	else:
		var parts2: Array = []
		for k in hc:
			parts2.append("%d %s" % [hc[k], "Embers" if k == "embers" else "Sunshard"])
		hearth_btn.text = "Feed Hearth (%s)" % ", ".join(parts2).replace(" Embers", "").replace(" Sunshard", "S")
		hearth_btn.disabled = not Profile.can_afford(hc)
		hearth_btn.tooltip_text = Profile.SANCTUARY.hearth.desc


func _feed_hearth() -> void:
	if Profile.upgrade_building("hearth"):
		Audio.play("hearth_feed", 0.0)
		Game.ui.toast("The Hearth burns brighter. (+10 max health)", UIKit.C_GOLD)
		Profile.save_profile()


func _respec() -> void:
	Game.ui.confirm("Respec the Hearthtree?", "All points are returned. Cost: %d Embers." % Profile.respec_cost(), func() -> void:
		if Profile.respec():
			Audio.play("respec", 0.0)
			queue_redraw())


func to_screen(p: Vector2) -> Vector2:
	return size * 0.5 + (p + pan) * zoom


func node_at(sp: Vector2) -> String:
	for id in SkillDB.all_ids():
		var r := _radius(SkillDB.node(id).kind) * zoom + 2.0
		if to_screen(SkillDB.position_of(id)).distance_to(sp) <= r:
			return id
	return ""


func _radius(kind: String) -> float:
	match kind:
		"root":
			return 13.0
		"keystone":
			return 12.0
		"notable", "ability":
			return 10.0
		"hybrid":
			return 9.0
	return 6.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var before := (mb.position - size * 0.5) / zoom - pan
				zoom = clampf(zoom * (1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), 0.3, 2.4)
				pan = (mb.position - size * 0.5) / zoom - before
			accept_event()
			return
		if mb.pressed:
			_pressing = true
			_dragged = false
			_press_pos = mb.position
		else:
			if _pressing and not _dragged:
				var id := node_at(mb.position)
				if id != "":
					if mb.button_index == MOUSE_BUTTON_LEFT:
						_try_allocate(id)
					elif mb.button_index == MOUSE_BUTTON_RIGHT:
						_try_refund(id)
			_pressing = false
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pressing and (mm.position.distance_to(_press_pos) > 4.0 or _dragged):
			_dragged = true
			pan += mm.relative / zoom
		var h := node_at(mm.position)
		if h != hovered:
			hovered = h
			_update_tip()
		if tip.visible:
			_place_tip(mm.position)


func _try_allocate(id: String) -> void:
	if Profile.allocate(id):
		Audio.play("skill_unlock", 0.0, randf_range(0.95, 1.05))
		_bursts.append({"pos": SkillDB.position_of(id), "t": 0.0, "col": _branch_color(id)})
		_update_tip()
	else:
		Audio.ui("deny")


func _try_refund(id: String) -> void:
	if Profile.refund(id):
		Audio.play("skill_refund", -2.0)
		_update_tip()
	else:
		Audio.ui("deny")


func _branch_color(id: String) -> Color:
	var b := String(SkillDB.node(id).get("branch", ""))
	if b == "":
		return Color(1.0, 0.75, 0.4)
	if b.contains("|"):
		var bs := b.split("|")
		return (SkillDB.BRANCHES[bs[0]].color as Color).lerp(SkillDB.BRANCHES[bs[1]].color, 0.5)
	return SkillDB.BRANCHES[b].color


func _update_tip() -> void:
	for c in tip_box.get_children():
		c.queue_free()
	if hovered == "":
		tip.visible = false
		return
	var n := SkillDB.node(hovered)
	var alloc := Profile.skills().has(hovered)
	var col := _branch_color(hovered)
	tip_box.add_child(UIKit.label(n.name, 16 if n.kind in ["keystone", "root"] else 8, col, true))
	var kind_txt: String = {"minor": "Minor", "notable": "Notable", "ability": "Ability", "keystone": "Keystone", "hybrid": "Hybrid", "root": "Origin"}[n.kind]
	var b := String(n.get("branch", ""))
	var bname := ""
	for part in b.split("|", false):
		bname += ("/" if bname != "" else "") + String(SkillDB.BRANCHES[part].name)
	tip_box.add_child(UIKit.label("%s%s   Cost %d" % [kind_txt, ("  -  " + bname) if bname != "" else "", SkillDB.cost(hovered)], 8, UIKit.C_DIM))
	if n.has("desc"):
		tip_box.add_child(UIKit.para(n.desc, 170))
	for m in n.get("mods", []):
		if n.has("desc") and n.kind != "minor":
			continue
		tip_box.add_child(UIKit.label(UIKit.describe_mod(m), 8, UIKit.C_TEXT))
	if n.has("ability"):
		var ab := GearDB.ability(n.ability)
		tip_box.add_child(UIKit.label("%d Kindle   %.1fs cooldown" % [int(ab.cost), float(ab.cooldown)], 8, UIKit.C_EMBER))
	var state := ""
	var scol := UIKit.C_DIM
	if alloc:
		state = "Kindled." if hovered == "hearth" else ("Kindled - right-click to refund" if SkillDB.can_refund(hovered, Profile.skills()) else "Kindled - other nodes depend on it")
		scol = UIKit.C_GOLD
	elif SkillDB.can_allocate(hovered, Profile.skills(), Profile.skill_points_free()):
		state = "Click to kindle"
		scol = UIKit.C_GOOD
	elif Profile.skill_points_free() < SkillDB.cost(hovered):
		state = "Not enough skill points"
		scol = UIKit.C_BAD
	else:
		state = "Must connect to a kindled node"
	tip_box.add_child(UIKit.label(state, 8, scol))
	tip.visible = true
	tip.reset_size()


func _place_tip(mp: Vector2) -> void:
	var p := mp + Vector2(12, 10)
	if p.x + tip.size.x > size.x - 4:
		p.x = mp.x - tip.size.x - 12
	if p.y + tip.size.y > size.y - 4:
		p.y = size.y - tip.size.y - 4
	tip.position = p


func _process(delta: float) -> void:
	_t += delta
	for b in _bursts:
		b.t += delta
	_bursts = _bursts.filter(func(b): return b.t < 0.8)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.02, 0.04, 0.97))
	# star field (parallax)
	for s in _stars:
		var sp: Vector2 = size * 0.5 + (s[0] + pan * 0.35) * zoom * 0.8
		if Rect2(Vector2.ZERO, size).has_point(sp):
			var tw: float = 0.35 + 0.65 * absf(sin(_t * (0.6 + s[1]) + s[1] * 10.0))
			var c := Color(0.75, 0.7, 0.9, tw * 0.5)
			draw_rect(Rect2(sp.floor(), Vector2(1, 1) * (1 + int(s[2] == 2))), c)
	var alloc: Array = Profile.skills()
	var free := Profile.skill_points_free()
	# faint branch sectors give each school its own colour field
	var center := to_screen(Vector2.ZERO)
	for b in SkillDB.BRANCHES:
		var binfo: Dictionary = SkillDB.BRANCHES[b]
		var a0 := deg_to_rad(float(binfo.angle) - 26.0)
		var a1 := deg_to_rad(float(binfo.angle) + 26.0)
		var fan := PackedVector2Array([center])
		for k in 9:
			var aa := lerpf(a0, a1, k / 8.0)
			fan.append(center + Vector2(cos(aa), sin(aa)) * SkillDB.RING * 6.6 * zoom)
		var bc: Color = binfo.color
		draw_colored_polygon(fan, Color(bc.r, bc.g, bc.b, 0.045))
	# guide rings and branch names
	for ring in range(1, 7):
		draw_arc(center, ring * SkillDB.RING * zoom, 0.0, TAU, 96, Color(0.3, 0.25, 0.35, 0.18), 1.0)
	for b in SkillDB.BRANCHES:
		var info: Dictionary = SkillDB.BRANCHES[b]
		var a := deg_to_rad(float(info.angle))
		var p := to_screen(Vector2(cos(a), sin(a)) * SkillDB.RING * 6.75)
		var name: String = String(info.name).to_upper()
		var fs := 16 if zoom > 0.9 else 8
		var w := UIKit.FONT_OUTLINE.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(UIKit.FONT_OUTLINE, (p - Vector2(w * 0.5, -fs * 0.4)).round(), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, (info.color as Color).darkened(0.1))
	# edges
	var done := {}
	for id in SkillDB.all_ids():
		for nb in SkillDB.neighbours(id):
			var key: String = id + ":" + nb if id < nb else nb + ":" + id
			if done.has(key):
				continue
			done[key] = true
			var a := to_screen(SkillDB.position_of(id))
			var bpos := to_screen(SkillDB.position_of(nb))
			var ia := alloc.has(id)
			var ib := alloc.has(nb)
			if ia and ib:
				draw_line(a, bpos, Color(0.55, 0.38, 0.15), 3.0)
				draw_line(a, bpos, Color(1.0, 0.75, 0.35), 1.0)
				# travelling sparks
				var L := a.distance_to(bpos)
				var n := maxi(1, int(L / 40.0))
				for k in n:
					var f := fmod(_t * 0.6 + float(k) / n + float(hash(key) % 100) / 100.0, 1.0)
					var sp := a.lerp(bpos, f)
					draw_rect(Rect2(sp.round() - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.92, 0.6))
			elif ia or ib:
				var other: String = nb if ia else id
				var can := SkillDB.cost(other) <= free
				_dashed(a, bpos, Color(0.85, 0.6, 0.3, 0.7) if can else Color(0.5, 0.4, 0.35, 0.45))
			else:
				draw_line(a, bpos, Color(0.25, 0.22, 0.3, 0.6), 1.0)
	# nodes
	for id in SkillDB.all_ids():
		_draw_node(id, alloc, free)
	# unlock bursts
	for b in _bursts:
		var p := to_screen(b.pos)
		var k: float = b.t / 0.8
		var col: Color = b.col
		col.a = 1.0 - k
		draw_arc(p, (10.0 + k * 40.0) * zoom, 0.0, TAU, 32, col, 2.0)
		for i in 10:
			var ang := i * TAU / 10.0 + k
			var q := p + Vector2(cos(ang), sin(ang)) * (8.0 + k * 50.0) * zoom
			draw_rect(Rect2(q.round(), Vector2(2, 2)), col)


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / maxf(L, 0.01)
	var off := fmod(_t * 12.0, 8.0)
	var s := -off
	while s < L:
		var s0 := maxf(s, 0.0)
		var s1 := minf(s + 4.0, L)
		if s1 > s0:
			draw_line(a + d * s0, a + d * s1, col, 1.0)
		s += 8.0


func _draw_node(id: String, alloc: Array, free: int) -> void:
	var n := SkillDB.node(id)
	var p := to_screen(SkillDB.position_of(id)).round()
	var r := _radius(n.kind) * zoom
	var col := _branch_color(id)
	var is_alloc := alloc.has(id)
	var can := SkillDB.can_allocate(id, alloc, free)
	var reachable := false
	for nb in SkillDB.neighbours(id):
		if alloc.has(nb):
			reachable = true
	var fill := Color(0.08, 0.07, 0.11)
	var edge := Color(0.32, 0.28, 0.36)
	if is_alloc:
		fill = col.darkened(0.25)
		edge = Color(1.0, 0.85, 0.5)
		# glow
		draw_circle(p, r + 4.0 * zoom, Color(col.r, col.g, col.b, 0.18))
	elif can:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		edge = col.lerp(Color.WHITE, 0.3 * pulse)
		fill = Color(0.12, 0.1, 0.14)
		draw_circle(p, r + (2.0 + pulse * 2.0) * zoom, Color(col.r, col.g, col.b, 0.12 + 0.1 * pulse))
	elif reachable:
		edge = col.darkened(0.35)
	else:
		edge = col.darkened(0.62)
		fill = Color(0.06, 0.055, 0.08).lerp(col, 0.06)
	var pts := _shape_points(n.kind, p, r)
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(0.02, 0.02, 0.03), 3.0)
	draw_polyline(closed, edge, 1.5 if n.kind in ["minor"] else 2.0)
	if n.kind in ["notable", "keystone", "root"]:
		var inner := _shape_points(n.kind, p, r - 3.0 * zoom)
		inner.append(inner[0])
		draw_polyline(inner, edge.darkened(0.3), 1.0)
	# icon
	var icon_name := ""
	match n.kind:
		"root":
			icon_name = "hearth"
		"ability":
			icon_name = GearDB.ability(n.ability).get("icon", "star")
		"keystone":
			icon_name = "star"
		"notable", "hybrid":
			icon_name = BRANCH_ICON.get(String(n.branch).split("|")[0], "star")
	if icon_name != "" and r >= 7.0:
		var s := 16.0 if r >= 12.0 else (12.0 if r >= 9.0 else 8.0)
		s = roundf(s * clampf(zoom, 0.6, 1.5))
		var tint := Color(1, 1, 1, 1) if is_alloc or can else Color(0.55, 0.52, 0.6, 0.8)
		draw_texture_rect(UIKit.icon(icon_name), Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)).abs(), false, tint)
	if id == hovered:
		draw_arc(p, r + 5.0 * zoom, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 1.0)


func _shape_points(kind: String, p: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var sides := 16
	var rot := 0.0
	match kind:
		"keystone":
			sides = 6
			rot = PI / 6.0
		"ability":
			sides = 4
		"hybrid":
			sides = 8
			rot = PI / 8.0
		"minor":
			sides = 12
	for i in sides:
		var a := rot + float(i) / sides * TAU
		pts.append(p + Vector2(cos(a), sin(a)) * r)
	return pts
