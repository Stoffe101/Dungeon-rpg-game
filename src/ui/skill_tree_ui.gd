## The Hearthtree: a zoomable, pannable constellation of skills radiating from
## the Hearth. Allocated paths burn gold with travelling sparks; available
## nodes pulse; hovering shows a full tooltip and previews the cheapest route
## from your tree (clicking kindles the whole route); a search box highlights
## matching nodes; a side panel sums up everything the tree grants.
class_name SkillTreeUI
extends Control

const BRANCH_ICON := {"blade": "sword", "pyre": "flame", "rime": "snow", "gloam": "feather", "bulwark": "shield", "kindle": "wick"}
const PANEL_W := 150.0

var zoom := 1.0
var pan := Vector2.ZERO
var hovered := ""
var route: Dictionary = {}      # cheapest path to the hovered node (SkillDB.path_to)
var search := ""
var matches := {}
var _t := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragged := false
var _bursts: Array = []
var _stars: Array = []
var _label_rects := {}          # branch -> Rect2 of its name, for click-to-focus
var _branch_total := {}
var _view_tw: Tween
var _embers: Array = []         # drifting sparks rising off the tree: [pos, vel, life, max]
var _hearth_tex: AtlasTexture
var _hearth_info: SpriteLib.SheetInfo
var points_lbl: Label
var info_lbl: Label
var find_lbl: Label
var search_box: LineEdit
var respec_btn: Button
var hearth_btn: Button
var close_btn: Button
var bonus_btn: Button
var bonus_panel: PanelContainer
var bonus_box: VBoxContainer
var hint: Label
var tip: PanelContainer
var tip_box: VBoxContainer
var pad_cursor := Vector2.ZERO
var pad_active := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 220:
		_stars.append([Vector2(rng.randf_range(-700, 700), rng.randf_range(-500, 500)), rng.randf(), rng.randi_range(0, 2)])
	for id in SkillDB.all_ids():
		for b in String(SkillDB.node(id).get("branch", "")).split("|", false):
			_branch_total[b] = int(_branch_total.get(b, 0)) + 1
	_hearth_info = SpriteLib.get_sheet("hearth")
	_hearth_tex = AtlasTexture.new()
	_hearth_tex.atlas = _hearth_info.texture
	_build_header()
	_build_bonus_panel()
	hint = UIKit.label("", 8, UIKit.C_DIM, true)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 8
	hint.offset_top = -14
	hint.offset_bottom = -4
	add_child(hint)
	_update_hint(Settings.using_pad)
	Settings.device_changed.connect(_update_hint)
	tip = UIKit.panel()
	tip.add_theme_stylebox_override("panel", UIKit.theme().get_stylebox("panel", "TooltipPanel"))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_box = UIKit.vbox(2)
	tip.add_child(tip_box)
	tip.visible = false
	add_child(tip)
	_on_profile_changed()
	Profile.changed.connect(_on_profile_changed)
	_fit_view(false)


func _build_header() -> void:
	var top := UIKit.panel()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 6
	top.offset_right = -6
	top.offset_top = 6
	add_child(top)
	var row := UIKit.hbox(6)
	top.add_child(row)
	row.add_child(UIKit.label("HEARTHTREE", 16, UIKit.C_GOLD, true))
	var info := UIKit.vbox(0)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	points_lbl = UIKit.label("", 8, UIKit.C_EMBER)
	info_lbl = UIKit.label("", 8, UIKit.C_DIM)
	info.add_child(points_lbl)
	info.add_child(info_lbl)
	row.add_child(info)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search..."
	search_box.custom_minimum_size = Vector2(64, 14)
	search_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search_box.add_theme_font_override("font", UIKit.FONT)
	search_box.add_theme_font_size_override("font_size", 8)
	search_box.add_theme_color_override("font_color", UIKit.C_TEXT)
	search_box.add_theme_color_override("font_placeholder_color", UIKit.C_DIM)
	search_box.add_theme_color_override("caret_color", UIKit.C_GOLD)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.07)
	sb.border_color = Color(0.36, 0.27, 0.21)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(2)
	sb.content_margin_left = 4
	search_box.add_theme_stylebox_override("normal", sb)
	var sbf := sb.duplicate() as StyleBoxFlat
	sbf.border_color = UIKit.C_GOLD
	search_box.add_theme_stylebox_override("focus", sbf)
	search_box.text_changed.connect(_on_search)
	search_box.focus_mode = Control.FOCUS_CLICK
	row.add_child(search_box)
	find_lbl = UIKit.label("", 8, UIKit.C_SOUL)
	find_lbl.custom_minimum_size = Vector2(12, 0)
	row.add_child(find_lbl)
	bonus_btn = UIKit.button("Bonuses", _toggle_bonuses, 44)
	row.add_child(bonus_btn)
	hearth_btn = UIKit.button("Feed the Hearth", _feed_hearth, 70)
	row.add_child(hearth_btn)
	respec_btn = UIKit.button("Respec", _respec, 44)
	row.add_child(respec_btn)
	close_btn = UIKit.button("Close", func() -> void: Game.ui.close_top(), 40)
	row.add_child(close_btn)
	# the gamepad cursor presses these; keyboard focus would double-fire with A
	for b in [bonus_btn, hearth_btn, respec_btn, close_btn]:
		b.focus_mode = Control.FOCUS_NONE


func _build_bonus_panel() -> void:
	bonus_panel = UIKit.panel("DarkPanel")
	bonus_panel.anchor_left = 1.0
	bonus_panel.anchor_right = 1.0
	bonus_panel.anchor_top = 0.0
	bonus_panel.anchor_bottom = 1.0
	bonus_panel.offset_left = -PANEL_W - 6.0
	bonus_panel.offset_right = -6.0
	bonus_panel.offset_top = 40.0
	bonus_panel.offset_bottom = -18.0
	bonus_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bonus_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bonus_panel.add_child(scroll)
	bonus_box = UIKit.vbox(2)
	bonus_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(bonus_box)
	bonus_panel.visible = bool(Profile.data.flags.get("tree_bonuses", true))


func _exit_tree() -> void:
	if Profile.changed.is_connected(_on_profile_changed):
		Profile.changed.disconnect(_on_profile_changed)
	Profile.save_profile()
	# the player in the sanctuary feels new nodes immediately
	if Game.stage and Game.stage.player:
		Game.stage.player.rebuild_stats()
		Game.stage.player.ability_slots = Profile.slots()


func _on_profile_changed() -> void:
	_refresh_header()
	_refresh_bonuses()
	_set_hovered(hovered, true)


func _refresh_header() -> void:
	var free := Profile.skill_points_free()
	points_lbl.text = "%d point%s" % [free, "" if free == 1 else "s"]
	points_lbl.add_theme_color_override("font_color", UIKit.C_EMBER if free > 0 else UIKit.C_DIM)
	info_lbl.text = "Level %d" % Profile.level()
	var rc := Profile.respec_cost()
	respec_btn.text = "Respec" if rc == 0 else "Respec %d" % rc
	respec_btn.disabled = Profile.skills().size() <= 1 or Profile.currency("embers") < rc
	var hc := Profile.building_cost("hearth")
	if hc.is_empty():
		hearth_btn.text = "Hearth: max"
		hearth_btn.disabled = true
	else:
		var parts2: Array = []
		for k in hc:
			parts2.append("%d%s" % [hc[k], "" if k == "embers" else (" Shard" if int(hc[k]) == 1 else " Shards")])
		hearth_btn.text = "Feed Hearth: %s" % " / ".join(parts2)
		hearth_btn.disabled = not Profile.can_afford(hc)
		hearth_btn.tooltip_text = Profile.SANCTUARY.hearth.desc


## The side panel: every bonus the tree grants, the powers it unlocked and the abilities.
func _refresh_bonuses() -> void:
	for c in bonus_box.get_children():
		c.queue_free()
	var alloc: Array = Profile.skills()
	var w := int(PANEL_W) - 14
	bonus_box.add_child(UIKit.label("YOUR HEARTHTREE", 8, UIKit.C_GOLD, true))
	var tot := SkillDB.totals(alloc)
	if alloc.size() <= 1:
		bonus_box.add_child(UIKit.para("Kindle nodes to grow stronger. Click any node to kindle the whole path to it.", w, UIKit.C_DIM))
	for m in tot:
		bonus_box.add_child(UIKit.para(UIKit.describe_mod(m), w))
	var powers: Array = []
	for id in alloc:
		if String(SkillDB.node(id).kind) in ["notable", "keystone", "hybrid"]:
			powers.append(id)
	if not powers.is_empty():
		bonus_box.add_child(UIKit.spacer(3))
		bonus_box.add_child(UIKit.label("POWERS", 8, UIKit.C_GOLD, true))
		for id in powers:
			var n := SkillDB.node(id)
			var l := UIKit.para(String(n.name), w, _branch_color(id))
			l.tooltip_text = String(n.get("desc", ""))
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			bonus_box.add_child(l)
	var mastery_txt: Array = []
	for id in SkillDB.unique(alloc):
		if String(SkillDB.node(id).kind) == "mastery":
			mastery_txt.append("%s %d/%d" % [String(SkillDB.node(id).name).replace(" Mastery", ""), SkillDB.rank(id, alloc), SkillDB.max_rank(id)])
	if not mastery_txt.is_empty():
		bonus_box.add_child(UIKit.spacer(3))
		bonus_box.add_child(UIKit.label("MASTERIES", 8, UIKit.C_GOLD, true))
		bonus_box.add_child(UIKit.para(", ".join(mastery_txt), w))
	var abilities := SkillDB.abilities(alloc)
	bonus_box.add_child(UIKit.spacer(3))
	bonus_box.add_child(UIKit.label("ABILITIES", 8, UIKit.C_GOLD, true))
	var names: Array = []
	for a in abilities:
		names.append(String(GearDB.ability(a).get("name", a)))
	bonus_box.add_child(UIKit.para(", ".join(names), w, UIKit.C_EMBER))


func _toggle_bonuses() -> void:
	bonus_panel.visible = not bonus_panel.visible
	Profile.data.flags["tree_bonuses"] = bonus_panel.visible
	_fit_view(true)


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


# --- view -----------------------------------------------------------------------------

func to_screen(p: Vector2) -> Vector2:
	return size * 0.5 + (p + pan) * zoom


## Fits the whole constellation between the header and the bottom hint, beside the panel.
func _fit_view(animate: bool) -> void:
	var vp := size if size.y > 10.0 else get_viewport_rect().size
	var z := clampf((vp.y - 60.0) / (2.0 * 6.5 * SkillDB.RING), 0.3, 1.6)
	var shift := -(PANEL_W * 0.5 + 4.0) if bonus_panel.visible else 0.0
	_view_to(Vector2(shift / z, 12.0 / z), z, animate)


## Centres a branch and zooms in on it.
func _focus_branch(b: String) -> void:
	var a := deg_to_rad(float(SkillDB.BRANCHES[b].angle))
	var c := Vector2(cos(a), sin(a)) * SkillDB.RING * 3.5
	var z := clampf((size.y - 80.0) / (SkillDB.RING * 6.2), 0.4, 1.6)
	var shift := -(PANEL_W * 0.5 + 4.0) if bonus_panel.visible else 0.0
	_view_to(-c + Vector2(shift / z, 10.0 / z), z, true)
	Audio.ui("ui_click")


func _view_to(p: Vector2, z: float, animate: bool) -> void:
	if _view_tw:
		_view_tw.kill()
	if not animate:
		pan = p
		zoom = z
		return
	_view_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_view_tw.tween_property(self, "pan", p, 0.45)
	_view_tw.tween_property(self, "zoom", z, 0.45)


func node_at(sp: Vector2) -> String:
	for id in SkillDB.all_ids():
		var r := _radius(SkillDB.node(id).kind) * zoom + 2.0
		if to_screen(SkillDB.position_of(id)).distance_to(sp) <= r:
			return id
	return ""


func _radius(kind: String) -> float:
	match kind:
		"root":
			return 16.0
		"keystone":
			return 16.0
		"notable", "ability":
			return 13.0
		"hybrid":
			return 12.0
		"mastery":
			return 11.0
	return 8.0


# --- input ----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				if _view_tw:
					_view_tw.kill()
				var before := (mb.position - size * 0.5) / zoom - pan
				zoom = clampf(zoom * (1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), 0.3, 2.4)
				pan = (mb.position - size * 0.5) / zoom - before
			accept_event()
			return
		if mb.pressed:
			search_box.release_focus()
			if mb.double_click and node_at(mb.position) == "":
				_fit_view(true)
				accept_event()
				return
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
				elif mb.button_index == MOUSE_BUTTON_LEFT:
					for b in _label_rects:
						if (_label_rects[b] as Rect2).has_point(mb.position):
							_focus_branch(b)
			_pressing = false
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pressing and (mm.position.distance_to(_press_pos) > 4.0 or _dragged):
			if not _dragged and _view_tw:
				_view_tw.kill()
			_dragged = true
			pan += mm.relative / zoom
		var h := node_at(mm.position)
		if h != hovered:
			_set_hovered(h)
		if tip.visible:
			_place_tip(mm.position)


func _set_hovered(id: String, force := false) -> void:
	if id == hovered and not force:
		return
	hovered = id
	route = SkillDB.path_to(id, Profile.skills()) if id != "" else {}
	_update_tip()


## Kindles `id` - and, when it is not adjacent, every node on the cheapest path to it.
## A kindled mastery takes another rank instead.
func _try_allocate(id: String) -> void:
	if Profile.skills().has(id):
		if Profile.allocate(id):
			_bursts.append({"pos": SkillDB.position_of(id), "t": 0.0, "col": _branch_color(id)})
			Audio.play("skill_unlock", 0.0, 1.0 + 0.06 * SkillDB.rank(id, Profile.skills()))
			_set_hovered(hovered, true)
		else:
			Audio.ui("deny")
		return
	var r := SkillDB.path_to(id, Profile.skills())
	if r.is_empty() or int(r.cost) > Profile.skill_points_free():
		Audio.ui("deny")
		return
	var k := 0
	for nid in r.nodes:
		if not Profile.allocate(nid):
			break
		_bursts.append({"pos": SkillDB.position_of(nid), "t": -0.09 * k, "col": _branch_color(nid)})
		k += 1
	Audio.play("skill_unlock", 0.0, randf_range(0.95, 1.05) + 0.03 * k)
	_set_hovered(hovered, true)


func _try_refund(id: String) -> void:
	if Profile.refund(id):
		Audio.play("skill_refund", -2.0)
		_set_hovered(hovered, true)
	else:
		Audio.ui("deny")


func _on_search(text: String) -> void:
	search = text.strip_edges().to_lower()
	matches.clear()
	if search != "":
		for id in SkillDB.all_ids():
			var n := SkillDB.node(id)
			var hay := (String(n.name) + " " + String(n.get("desc", ""))).to_lower()
			for m in n.get("mods", []):
				hay += " " + UIKit.describe_mod(m).to_lower()
			for b in String(n.get("branch", "")).split("|", false):
				hay += " " + String(SkillDB.BRANCHES[b].name).to_lower()
			if hay.contains(search):
				matches[id] = true
	find_lbl.text = "" if search == "" else str(matches.size())


func _branch_color(id: String) -> Color:
	var b := String(SkillDB.node(id).get("branch", ""))
	if b == "":
		return Color(1.0, 0.75, 0.4)
	if b.contains("|"):
		var bs := b.split("|")
		return (SkillDB.BRANCHES[bs[0]].color as Color).lerp(SkillDB.BRANCHES[bs[1]].color, 0.5)
	return SkillDB.BRANCHES[b].color


# --- tooltip ----------------------------------------------------------------------------

func _update_tip() -> void:
	for c in tip_box.get_children():
		c.queue_free()
	if hovered == "":
		tip.visible = false
		return
	var n := SkillDB.node(hovered)
	var alloc: Array = Profile.skills()
	var is_alloc := alloc.has(hovered)
	var col := _branch_color(hovered)
	var head := UIKit.hbox(4)
	head.add_child(UIKit.icon_rect(SkillDB.icon_of(hovered)))
	head.add_child(UIKit.label(n.name, 16 if n.kind in ["keystone", "root"] else 8, col, true))
	tip_box.add_child(head)
	var kind_txt: String = {"minor": "Minor", "notable": "Notable", "ability": "Ability", "keystone": "Keystone", "hybrid": "Hybrid", "root": "Origin", "mastery": "Mastery"}[n.kind]
	var mastery: bool = n.kind == "mastery"
	var b := String(n.get("branch", ""))
	var bname := ""
	for part in b.split("|", false):
		bname += ("/" if bname != "" else "") + String(SkillDB.BRANCHES[part].name)
	tip_box.add_child(UIKit.label("%s%s   Cost %d%s" % [kind_txt, ("  -  " + bname) if bname != "" else "", SkillDB.cost(hovered), " per rank" if mastery else ""], 8, UIKit.C_DIM))
	if mastery:
		tip_box.add_child(UIKit.label("Rank %d / %d   (each rank:)" % [SkillDB.rank(hovered, alloc), SkillDB.max_rank(hovered)], 8, UIKit.C_GOLD))
	if n.has("desc"):
		tip_box.add_child(UIKit.para(n.desc, 180))
	var totals := _totals_by_key(alloc)
	for m in n.get("mods", []):
		if n.has("desc") and not n.kind in ["minor", "mastery"]:
			continue
		tip_box.add_child(UIKit.label(UIKit.describe_mod(m), 8, UIKit.C_TEXT))
		var key := "%s|%s" % [m[0], m[1]]
		if totals.has(key) or not is_alloc:
			# what the whole tree adds up to, before and after this node
			var now := float(totals.get(key, 0.0))
			var after := now
			var growing := not is_alloc or (mastery and SkillDB.rank(hovered, alloc) < SkillDB.max_rank(hovered))
			if growing:
				after = (1.0 + now) * (1.0 + float(m[2])) - 1.0 if m[1] == "more" else now + float(m[2])
			if absf(after - float(m[2])) > 0.0001 or is_alloc:
				var txt := "Tree total: %s" % _short(m[0], m[1], now)
				if growing:
					txt += "  ->  %s" % _short(m[0], m[1], after)
				tip_box.add_child(UIKit.label(txt, 8, UIKit.C_DIM))
	if n.has("ability"):
		var ab := GearDB.ability(n.ability)
		tip_box.add_child(UIKit.label("%d Kindle   %.1fs cooldown" % [int(ab.cost), float(ab.cooldown)], 8, UIKit.C_EMBER))
	var free := Profile.skill_points_free()
	var state := ""
	var scol := UIKit.C_DIM
	var verb := "A" if Settings.using_pad else "Click"
	if mastery and is_alloc and SkillDB.rank(hovered, alloc) < SkillDB.max_rank(hovered):
		if free >= 1:
			state = "%s to add a rank" % verb
			scol = UIKit.C_GOOD
		else:
			state = "Needs 1 point for the next rank"
			scol = UIKit.C_BAD
		if SkillDB.can_refund(hovered, alloc):
			state += "  -  %s removes one" % ("X" if Settings.using_pad else "right-click")
	elif mastery and is_alloc:
		state = "Mastered  -  %s removes a rank" % ("X" if Settings.using_pad else "right-click")
		scol = UIKit.C_GOLD
	elif is_alloc:
		if hovered == "hearth":
			state = "Kindled."
		elif SkillDB.can_refund(hovered, alloc):
			state = "Kindled - %s to refund" % ("X" if Settings.using_pad else "right-click")
		else:
			state = "Kindled - other nodes depend on it"
		scol = UIKit.C_GOLD
	elif not route.is_empty():
		var steps: int = (route.nodes as Array).size()
		var cost := int(route.cost)
		if cost <= free:
			state = "%s to kindle" % verb if steps == 1 else "%s to kindle the path: %d nodes, %d points" % [verb, steps, cost]
			scol = UIKit.C_GOOD
		else:
			state = "Needs %d point%s (you have %d)%s" % [cost, "" if cost == 1 else "s", free, "" if steps == 1 else " - path of %d nodes" % steps]
			scol = UIKit.C_BAD
	tip_box.add_child(UIKit.label(state, 8, scol))
	tip.visible = true
	tip.reset_size()


func _totals_by_key(alloc: Array) -> Dictionary:
	var out := {}
	for m in SkillDB.totals(alloc):
		out["%s|%s" % [m[0], m[1]]] = float(m[2])
	return out


## A stat value without its description ("+18%", "+35").
func _short(stat: String, op: String, v: float) -> String:
	var full := UIKit.describe_mod([stat, op, v])
	var sp := full.find(" ")
	return full.substr(0, sp) if sp > 0 and (full.begins_with("+") or full.begins_with("-")) else full


func _place_tip(mp: Vector2) -> void:
	var p := mp + Vector2(12, 10)
	if p.x + tip.size.x > size.x - 4:
		p.x = mp.x - tip.size.x - 12
	if p.y + tip.size.y > size.y - 4:
		p.y = size.y - tip.size.y - 4
	tip.position = p


# --- drawing ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_gamepad(delta)
	_step_embers(delta)
	for b in _bursts:
		b.t += delta
	_bursts = _bursts.filter(func(b): return b.t < 0.8)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.017, 0.035, 0.98))
	var alloc: Array = Profile.skills()
	var free := Profile.skill_points_free()
	var counts := SkillDB.branch_counts(alloc)
	var center := to_screen(Vector2.ZERO)
	_draw_nebula(center, counts)
	# star field (parallax, twinkling)
	for s in _stars:
		var sp: Vector2 = size * 0.5 + (s[0] + pan * 0.35) * zoom * 0.8
		if Rect2(Vector2.ZERO, size).has_point(sp):
			var tw: float = 0.35 + 0.65 * absf(sin(_t * (0.6 + s[1]) + s[1] * 10.0))
			draw_rect(Rect2(sp.floor(), Vector2(1, 1) * (1 + int(s[2] == 2))), Color(0.75, 0.7, 0.9, tw * 0.5))
	# faint orbit rings
	for ring in range(1, 7):
		draw_arc(center, ring * SkillDB.RING * zoom, 0.0, TAU, 96, Color(0.35, 0.28, 0.4, 0.09), 1.0)
	_draw_trunks(center, counts)
	# the Hearth's glow grows with every point spent
	var flick := 0.85 + 0.15 * sin(_t * 3.1) * sin(_t * 1.7)
	var gr := (44.0 + 3.0 * SkillDB.spent(alloc)) * zoom
	for k in 6:
		draw_circle(center, gr * (1.0 - k * 0.15), Color(1.0, 0.52, 0.2, (0.02 + 0.012 * k) * flick))
	_draw_labels(counts)
	_draw_edges(alloc, free)
	_draw_route(free)
	for id in SkillDB.all_ids():
		_draw_node(id, alloc, free)
	_draw_embers()
	_draw_vignette()
	# nothing peeks out above the header bar
	draw_rect(Rect2(0, 0, size.x, 7), Color(0.02, 0.017, 0.035))
	if pad_active:
		var c := pad_cursor.round()
		draw_rect(Rect2(c - Vector2(6, 0), Vector2(4, 1)), UIKit.C_GOLD)
		draw_rect(Rect2(c + Vector2(3, 0), Vector2(4, 1)), UIKit.C_GOLD)
		draw_rect(Rect2(c - Vector2(0, 6), Vector2(1, 4)), UIKit.C_GOLD)
		draw_rect(Rect2(c + Vector2(0, 3), Vector2(1, 4)), UIKit.C_GOLD)
	# unlock bursts (staggered along a kindled path)
	for b in _bursts:
		if b.t < 0.0:
			continue
		var p := to_screen(b.pos)
		var k: float = b.t / 0.8
		var col: Color = b.col
		col.a = 1.0 - k
		draw_arc(p, (10.0 + k * 40.0) * zoom, 0.0, TAU, 32, col, 2.0)
		for i in 10:
			var ang := i * TAU / 10.0 + k
			var q := p + Vector2(cos(ang), sin(ang)) * (8.0 + k * 50.0) * zoom
			draw_rect(Rect2(q.round(), Vector2(2, 2)), col)


## Soft clouds of each branch's colour drifting along its axis; brighter where
## you have invested.
func _draw_nebula(center: Vector2, counts: Dictionary) -> void:
	for b in SkillDB.BRANCHES:
		var info: Dictionary = SkillDB.BRANCHES[b]
		var a := deg_to_rad(float(info.angle))
		var dir := Vector2(cos(a), sin(a))
		var bc: Color = info.color
		var inv := clampf(float(counts.get(b, 0)) / 8.0, 0.0, 1.0)
		for k in 4:
			var along := (1.6 + k * 1.25 + 0.15 * sin(_t * 0.3 + k + a)) * SkillDB.RING
			var side := sin(_t * 0.21 + k * 1.7 + a * 3.0) * 0.5 * SkillDB.RING
			var p := center + (dir * along + dir.orthogonal() * side) * zoom
			var r := (70.0 + 22.0 * k) * zoom
			for ring in 4:
				draw_circle(p, r * (1.0 - ring * 0.22), Color(bc.r, bc.g, bc.b, (0.012 + 0.018 * inv) * (1.0 + ring * 0.6)))


## Dark trunks from the Hearth out to each keystone, so the constellation reads
## as a tree; they take on their branch's colour as you invest.
func _draw_trunks(center: Vector2, counts: Dictionary) -> void:
	for b in SkillDB.BRANCHES:
		var info: Dictionary = SkillDB.BRANCHES[b]
		var a := deg_to_rad(float(info.angle))
		var dir := Vector2(cos(a), sin(a))
		var perp := dir.orthogonal()
		var inv := clampf(float(counts.get(b, 0)) / 8.0, 0.0, 1.0)
		var bark := Color(0.09, 0.07, 0.09).lerp((info.color as Color).darkened(0.7), 0.4 + 0.4 * inv)
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in 13:
			var f := i / 12.0
			var bend := sin(f * PI) * 0.35 * SkillDB.RING
			var p := dir * f * SkillDB.RING * 6.2 + perp * bend
			var w := lerpf(16.0, 2.0, f) * zoom
			left.append(center + p * zoom + perp * w)
			right.append(center + p * zoom - perp * w)
		var edge := left.duplicate()
		right.reverse()
		draw_colored_polygon(left + right, Color(bark, 0.75))
		draw_polyline(edge, Color(bark.lightened(0.25), 0.35), 1.0)


## Embers rising off the tree, more of them the more is kindled.
func _draw_embers() -> void:
	for e in _embers:
		var k: float = e[2] / e[3]
		var c := Color(1.0, 0.65 + 0.3 * k, 0.3, k * 0.9)
		draw_rect(Rect2(to_screen(e[0]).round(), Vector2(1, 1) * (2 if k > 0.6 else 1)), c)


func _step_embers(delta: float) -> void:
	var alloc: Array = Profile.skills()
	var rate := 2.0 + alloc.size() * 0.35
	if randf() < delta * rate:
		var src: String = alloc[randi() % alloc.size()]
		var p := SkillDB.position_of(src) + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		var life := randf_range(1.6, 3.2)
		_embers.append([p, Vector2(randf_range(-6, 6), randf_range(-28, -16)), life, life])
	for i in range(_embers.size() - 1, -1, -1):
		var e: Array = _embers[i]
		e[2] -= delta
		if e[2] <= 0.0:
			_embers.remove_at(i)
			continue
		e[0] += e[1] * delta
		e[1].x += sin(_t * 2.0 + i) * 4.0 * delta


## Darkened edges frame the tree.
func _draw_vignette() -> void:
	for i in 6:
		var a := 0.13 * (1.0 - i / 6.0)
		var m := i * 5.0
		draw_rect(Rect2(m, m, size.x - m * 2.0, 5.0), Color(0, 0, 0, a))
		draw_rect(Rect2(m, size.y - m - 5.0, size.x - m * 2.0, 5.0), Color(0, 0, 0, a))
		draw_rect(Rect2(m, m + 5.0, 5.0, size.y - m * 2.0 - 10.0), Color(0, 0, 0, a))
		draw_rect(Rect2(size.x - m - 5.0, m + 5.0, 5.0, size.y - m * 2.0 - 10.0), Color(0, 0, 0, a))


## A gently curved connection between two nodes (stable per pair).
func _curve(a: Vector2, b: Vector2, key: String) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := b - a
	var bend := (float(absi(hash(key)) % 200) / 100.0 - 1.0) * 0.16 * d.length()
	var ctrl := (a + b) * 0.5 + d.orthogonal().normalized() * bend
	var n := clampi(int(d.length() / 6.0), 3, 14)
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return pts


func _point_on(pts: PackedVector2Array, f: float) -> Vector2:
	var x := clampf(f, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(int(x), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], x - i)


func _dashed_curve(pts: PackedVector2Array, col: Color, width := 1.0, speed := 12.0) -> void:
	var off := fmod(_t * speed, 8.0)
	var walked := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var L := a.distance_to(b)
		if L < 0.01:
			continue
		var s := 0.0
		while s < L:
			var phase := fmod(walked + s - off + 80.0, 8.0)
			var seg := minf((4.0 if phase < 4.0 else 8.0) - phase, L - s)
			if phase < 4.0:
				draw_line(a.lerp(b, s / L), a.lerp(b, (s + seg) / L), col, width)
			s += maxf(seg, 0.25)
		walked += L


## Branch names sit just outside the ring, pushed away from the keystones:
## icon, NAME and "kindled / total". Clicking one focuses that branch.
func _draw_labels(counts: Dictionary) -> void:
	_label_rects.clear()
	var mp := get_local_mouse_position()
	for b in SkillDB.BRANCHES:
		var info: Dictionary = SkillDB.BRANCHES[b]
		var a := deg_to_rad(float(info.angle))
		var dir := Vector2(cos(a), sin(a))
		var vertical := absf(dir.x) < 0.3
		# top and bottom branches: beside their keystone, so the view stays compact
		var p := to_screen(dir * SkillDB.RING * (6.0 if vertical else 6.7))
		var name: String = String(info.name).to_upper()
		var cnt := " %d/%d" % [int(counts.get(b, 0)), int(_branch_total.get(b, 0))]
		var fs := 16 if zoom > 0.9 else 8
		var w := UIKit.FONT_OUTLINE.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cw := UIKit.FONT_OUTLINE.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var total_w := 10.0 + w + cw
		# left-side labels end at the anchor, right-side ones start there
		var x0 := p.x - total_w * 0.5
		var y_mid := p.y + dir.y * 6.0
		if vertical:
			x0 = p.x + _radius("keystone") * zoom + 8.0
			y_mid = p.y
		elif dir.x < -0.3:
			x0 = p.x - total_w + 6.0
		elif dir.x > 0.3:
			x0 = p.x - 6.0
		var rect := Rect2(Vector2(x0 - 2.0, y_mid - fs * 0.6 - 2.0), Vector2(total_w + 4.0, fs * 1.2 + 4.0))
		_label_rects[b] = rect
		var col: Color = (info.color as Color).darkened(0.1)
		if rect.has_point(mp):
			col = col.lightened(0.35)
			draw_rect(rect, Color(col.r, col.g, col.b, 0.12))
		var base := Vector2(x0 + 10.0, y_mid + fs * 0.4).round()
		draw_texture_rect(UIKit.icon_small(BRANCH_ICON[b]), Rect2(Vector2(x0, y_mid - 4.0).round(), Vector2(8, 8)), false, Color(col, 0.9))
		draw_string(UIKit.FONT_OUTLINE, base, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		draw_string(UIKit.FONT_OUTLINE, base + Vector2(w, 0), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(col, 0.65))


func _draw_edges(alloc: Array, free: int) -> void:
	var done := {}
	for id in SkillDB.all_ids():
		for nb in SkillDB.neighbours(id):
			var key: String = id + ":" + nb if id < nb else nb + ":" + id
			if done.has(key):
				continue
			done[key] = true
			var lo: String = id if id < nb else nb
			var hi: String = nb if id < nb else id
			var a := to_screen(SkillDB.position_of(lo))
			var bpos := to_screen(SkillDB.position_of(hi))
			var ia := alloc.has(id)
			var ib := alloc.has(nb)
			var fade := 1.0 if search == "" or (matches.has(id) and matches.has(nb)) else 0.45
			var pts := _curve(a, bpos, key)
			if ia and ib:
				# a living branch: dark bark, a glowing core and sap-light running along it
				draw_polyline(pts, Color(0.12, 0.06, 0.03), 5.0)
				draw_polyline(pts, Color(0.6, 0.36, 0.14), 3.0)
				draw_polyline(pts, Color(1.0, 0.78, 0.4), 1.0)
				var L := a.distance_to(bpos)
				var n := maxi(1, int(L / 34.0))
				for k in n:
					var f := fmod(_t * 0.55 + float(k) / n + float(absi(hash(key)) % 100) / 100.0, 1.0)
					var sp := _point_on(pts, f)
					draw_rect(Rect2(sp.round() - Vector2(1, 1), Vector2(3, 3)), Color(1.0, 0.75, 0.35, 0.35))
					draw_rect(Rect2(sp.round(), Vector2(1, 1)), Color(1.0, 0.95, 0.75))
			elif ia or ib:
				var other: String = nb if ia else id
				var can := SkillDB.cost(other) <= free
				draw_polyline(pts, Color(0.08, 0.06, 0.08, 0.8 * fade), 3.0)
				_dashed_curve(pts, Color(0.95, 0.65, 0.3, 0.8 * fade) if can else Color(0.5, 0.4, 0.35, 0.45 * fade))
			else:
				draw_polyline(pts, Color(0.06, 0.05, 0.07, 0.7 * fade), 3.0)
				draw_polyline(pts, Color(0.3, 0.26, 0.34, 0.55 * fade), 1.0)


## The previewed path to the hovered node, drawn as a bright marching line.
func _draw_route(free: int) -> void:
	if route.is_empty() or (route.nodes as Array).size() < 2:
		return
	var ok := int(route.cost) <= free
	var col := Color(1.0, 0.9, 0.55) if ok else Color(1.0, 0.45, 0.4)
	var chain: Array = [route.from] + route.nodes
	for i in range(chain.size() - 1):
		var ida: String = chain[i]
		var idb: String = chain[i + 1]
		var lo: String = ida if ida < idb else idb
		var hi: String = idb if ida < idb else ida
		var pts := _curve(to_screen(SkillDB.position_of(lo)), to_screen(SkillDB.position_of(hi)), lo + ":" + hi)
		draw_polyline(pts, Color(col, 0.25), 4.0)
		_dashed_curve(pts, col, 2.0, 24.0)


func _dashed(a: Vector2, b: Vector2, col: Color, width := 1.0, speed := 12.0) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / maxf(L, 0.01)
	var s := -fmod(_t * speed, 8.0)
	while s < L:
		var s0 := maxf(s, 0.0)
		var s1 := minf(s + 4.0, L)
		if s1 > s0:
			draw_line(a + d * s0, a + d * s1, col, width)
		s += 8.0


func _draw_node(id: String, alloc: Array, free: int) -> void:
	var n := SkillDB.node(id)
	var kind: String = n.kind
	var p := to_screen(SkillDB.position_of(id)).round()
	var r := _radius(kind) * zoom
	var col := _branch_color(id)
	var is_alloc := alloc.has(id)
	var can := SkillDB.can_allocate(id, alloc, free)
	var reachable := false
	for nb in SkillDB.neighbours(id):
		if alloc.has(nb):
			reachable = true
	var on_route := not is_alloc and not route.is_empty() and (route.nodes as Array).has(id) and (route.nodes as Array).size() > 1
	var found := search != "" and matches.has(id)
	var fade := 1.0 if search == "" or found or is_alloc else 0.35
	var pulse := 0.5 + 0.5 * sin(_t * 4.0 + p.x * 0.013)
	# soft glow
	if is_alloc:
		for k in 3:
			draw_circle(p, r + (2.0 + k * 3.0) * zoom, Color(col.r, col.g, col.b, (0.16 - k * 0.05) * fade))
	elif can:
		draw_circle(p, r + (2.0 + pulse * 3.0) * zoom, Color(col.r, col.g, col.b, 0.1 + 0.1 * pulse))
	# body: a dark socket with a lit core; the rim says what state it is in
	var fill := Color(0.06, 0.055, 0.085).lerp(col, 0.05)
	var core := Color(0.09, 0.08, 0.12)
	var rim := col.darkened(0.62)
	if is_alloc:
		fill = col.darkened(0.6)
		core = col.darkened(0.25)
		rim = Color(1.0, 0.86, 0.52)
	elif can:
		fill = Color(0.1, 0.08, 0.12)
		core = col.darkened(0.72)
		rim = col.lerp(Color.WHITE, 0.3 * pulse)
	elif reachable:
		rim = col.darkened(0.35)
	if on_route:
		rim = Color(1.0, 0.9, 0.55) if int(route.cost) <= free else Color(1.0, 0.5, 0.45)
	fill.a *= fade
	core.a *= fade
	rim.a *= fade
	if kind == "keystone":
		# a crown of points around the keystone
		for i in 6:
			var ang := PI / 6.0 + i * TAU / 6.0 + PI / 6.0
			var dir := Vector2(cos(ang), sin(ang))
			var tri := PackedVector2Array([p + dir * (r + 5.0 * zoom), p + dir.rotated(0.32) * r * 0.92, p + dir.rotated(-0.32) * r * 0.92])
			draw_colored_polygon(tri, Color(rim.r, rim.g, rim.b, rim.a * 0.85))
	if kind == "root":
		_draw_hearth_root(p, r, fade)
		return
	var pts := _shape_points(kind, p, r)
	# drop shadow, body, then a core graded toward the light
	draw_colored_polygon(_shape_points(kind, p + Vector2(1, 2), r), Color(0, 0, 0, 0.45 * fade))
	draw_colored_polygon(pts, fill)
	draw_colored_polygon(_shape_points(kind, p, r * 0.74), core)
	draw_colored_polygon(_shape_points(kind, p + Vector2(-0.18, -0.22) * r, r * 0.42), core.lightened(0.12 if is_alloc else 0.05))
	if is_alloc:
		# embers shimmer inside a kindled node
		var sh := 0.5 + 0.5 * sin(_t * 5.0 + p.y * 0.07)
		draw_circle(p + Vector2(0, r * 0.15), r * 0.38, Color(1.0, 0.7, 0.3, (0.08 + 0.1 * sh) * fade))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(0.02, 0.02, 0.03, fade), 3.0)
	# a bevelled rim: lit along the top-left, shaded along the bottom-right
	var lit_rim := rim.lightened(0.35)
	var dark_rim := rim.darkened(0.45)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var mid := ((a + b) * 0.5 - p).normalized()
		var light := clampf(-(mid.x + mid.y) * 0.7071, -1.0, 1.0)
		var c := rim.lerp(lit_rim, light) if light > 0.0 else rim.lerp(dark_rim, -light)
		draw_line(a, b, c, 1.5 if kind == "minor" else 2.0)
	if kind in ["notable", "keystone", "root", "ability"]:
		var inner := _shape_points(kind, p, r - 3.0 * zoom)
		inner.append(inner[0])
		draw_polyline(inner, Color(rim.r, rim.g, rim.b, rim.a * 0.55), 1.0)
	if kind == "notable":
		for i in 4:
			var dir := Vector2.from_angle(i * TAU / 4.0 - PI / 2.0)
			draw_rect(Rect2((p + dir * r).round() - Vector2(1, 1), Vector2(2, 2)), rim)
	# icon: crisp 16px when there is room, a downsampled 8px otherwise
	var d := r * 2.0
	var s := 16.0 if d >= 22.0 else (8.0 if d >= 9.0 else 0.0)
	if s > 0.0:
		var tint := Color(1, 1, 1, fade)
		if not is_alloc and not can:
			tint = Color(col.r * 0.6 + 0.3, col.g * 0.6 + 0.3, col.b * 0.6 + 0.3, 0.8 * fade)
		var tex: Texture2D = UIKit.icon(SkillDB.icon_of(id)) if s >= 16.0 else UIKit.icon_small(SkillDB.icon_of(id))
		draw_texture_rect(tex, Rect2((p - Vector2(s, s) * 0.5).round(), Vector2(s, s)), false, tint)
	elif is_alloc:
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.9, 0.6))
	if kind == "mastery":
		# rank pips in an arc under the node, and the count beside it
		var mr := SkillDB.max_rank(id)
		var rk := SkillDB.rank(id, alloc)
		for i in mr:
			var ang := deg_to_rad(50.0 + 80.0 * float(i) / maxf(mr - 1, 1))
			var q := (p + Vector2(cos(ang), sin(ang)) * (r + 3.0 * zoom + 2.0)).round()
			draw_rect(Rect2(q - Vector2(2, 2), Vector2(3, 3)), Color(0.02, 0.02, 0.03, fade))
			draw_rect(Rect2(q - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.86, 0.52, fade) if i < rk else Color(col.r, col.g, col.b, 0.35 * fade))
		if zoom > 0.45:
			draw_string(UIKit.FONT_OUTLINE, (p + Vector2(r + 3.0, 3.0)).round(), "%d/%d" % [rk, mr], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.86, 0.52, fade) if rk > 0 else Color(col, 0.7 * fade))
	if found:
		draw_arc(p, r + 5.0 * zoom, 0.0, TAU, 32, Color(0.45, 0.95, 0.85, 0.55 + 0.45 * pulse), 1.5)
	if id == hovered:
		draw_arc(p, r + 4.0 * zoom + 1.0, 0.0, TAU, 32, Color(1, 1, 1, 0.85), 1.0)


## The origin of the tree: the Hearth itself, burning, ringed in gold.
func _draw_hearth_root(p: Vector2, r: float, fade: float) -> void:
	var info: Dictionary = _hearth_info.anims["burn"]
	var f := int(_t * float(info.fps)) % int(info.frames)
	var fs := Vector2(_hearth_info.frame_size)
	_hearth_tex.region = Rect2(Vector2(f * fs.x, float(info.row) * fs.y), fs)
	var k := maxf(0.5, roundf(zoom * 2.0) / 2.0)
	var sz := fs * k
	var origin := Vector2(_hearth_info.origin) * k
	draw_circle(p, r + 6.0 * zoom, Color(1.0, 0.55, 0.2, 0.18 * fade))
	draw_arc(p, r + 2.0, 0.0, TAU, 40, Color(0.02, 0.02, 0.03, fade), 3.0)
	draw_arc(p, r + 2.0, 0.0, TAU, 40, Color(1.0, 0.86, 0.52, fade), 1.5)
	draw_texture_rect(_hearth_tex, Rect2((p - origin + Vector2(0, r * 0.55)).round(), sz), false, Color(1, 1, 1, fade))
	if hovered == "hearth":
		draw_arc(p, r + 6.0, 0.0, TAU, 40, Color(1, 1, 1, 0.85), 1.0)


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
		"mastery":
			sides = 10
			rot = -PI / 2.0
	for i in sides:
		var a := rot + float(i) / sides * TAU
		pts.append(p + Vector2(cos(a), sin(a)) * r)
	return pts


# --- gamepad --------------------------------------------------------------------------

## Controller support: left stick moves a cursor that snaps to nearby nodes,
## right stick pans, triggers zoom, A kindles (the whole path), X refunds,
## Y focuses the branch under the cursor, B closes.
func _gamepad(delta: float) -> void:
	if search_box.has_focus():
		return
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var pn := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var joy_used := mv.length() > 0.25 or pn.length() > 0.25
	if (joy_used or Settings.using_pad) and not pad_active:
		pad_active = true
		pad_cursor = size * 0.5
	if not pad_active:
		return
	if mv.length() > 0.25:
		pad_cursor += mv * 180.0 * delta
		pad_cursor = pad_cursor.clamp(Vector2(8, 8), size - Vector2(8, 8))
	if pn.length() > 0.25:
		pan -= pn * 240.0 * delta / zoom
	if Input.is_action_pressed("attack"):
		zoom = clampf(zoom * (1.0 + delta * 1.5), 0.3, 2.4)
	if Input.is_action_pressed("ward"):
		zoom = clampf(zoom / (1.0 + delta * 1.5), 0.3, 2.4)
	# snap toward the nearest node so selection is easy with a stick
	var best := ""
	var bd := 22.0
	for id in SkillDB.all_ids():
		var d := to_screen(SkillDB.position_of(id)).distance_to(pad_cursor)
		if d < bd:
			bd = d
			best = id
	if best != hovered:
		_set_hovered(best)
	if tip.visible:
		_place_tip(pad_cursor)
	if Input.is_action_just_pressed("ui_accept"):
		for b: Button in [bonus_btn, hearth_btn, respec_btn, close_btn]:
			if b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(get_global_transform() * pad_cursor):
				Audio.ui("ui_click")
				b.pressed.emit()
				return
		if hovered != "":
			_try_allocate(hovered)
	if Input.is_action_just_pressed("ability_1") and hovered != "":
		_try_refund(hovered)
	if Input.is_action_just_pressed("ability_2"):
		# focus the branch nearest the cursor, or zoom back out
		var tp := (pad_cursor - size * 0.5) / zoom - pan
		if tp.length() < SkillDB.RING * 1.2:
			_fit_view(true)
		else:
			var best_b := ""
			var best_d := 999.0
			for b in SkillDB.BRANCHES:
				var da := absf(angle_difference(tp.angle(), deg_to_rad(float(SkillDB.BRANCHES[b].angle))))
				if da < best_d:
					best_d = da
					best_b = b
			_focus_branch(best_b)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and pad_active and (event as InputEventMouseMotion).relative.length() > 6.0:
		pad_active = false


func _update_hint(pad: bool) -> void:
	if pad:
		hint.text = "L-Stick cursor   A kindle   X refund   Y focus branch   R-Stick pan   LT/RT zoom   B close"
	else:
		hint.text = "LMB kindle (whole path)   RMB refund   Wheel zoom   Drag pan   Click a branch name to focus   Double-click to reset"
