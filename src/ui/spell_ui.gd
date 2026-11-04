## Spells in the interface: one card and one tooltip wherever a spell is shown
## or chosen (the Descent's loadout and its picker, the hotbar). The numbers
## are the ones the cast uses (Player._try_ability): the build's Kindle cost and
## cooldown, and the multipliers of the runes set in that spell.
class_name SpellUI
extends RefCounted

## Hearthtree notables that change a spell (shown under it: learned or not).
const SYNERGY := {
	"knives": ["g_cut"],
	"orb": ["k_det"],
	"hearthfire": ["b_forged"],
	"rush": ["b_forged"],
	"rimewall": ["r_bast"],
	"beam": ["p_pour"],
}

const C_FRAME := Color(0.40, 0.31, 0.24)
const C_FRAME_HI := Color(1.0, 0.72, 0.36)
const C_FILL := Color(0.06, 0.05, 0.08)


## The Kindled whose build sets the numbers (this machine's, in camp or below).
static func _pl() -> Player:
	var st: Stage = Game.stage
	return st.player if st and st.player and st.player.stats else null


## {cost, cd} for spell `id` as this Kindled would cast it.
static func numbers(id: String, pl: Player = null) -> Dictionary:
	if pl == null:
		pl = _pl()
	var d := GearDB.ability(id)
	var cost := float(d.get("cost", 0.0))
	var cd := float(d.get("cooldown", 0.0))
	if pl:
		cost *= pl.stats.v("ability_cost") * Runes.cost_mult(pl, id)
		cd *= pl.stats.v("cooldown") * Runes.cooldown_mult(pl, id)
		if id == "gloamstep" and pl.stats.has("twin_shade"):
			cd *= 0.6
	return {"cost": cost, "cd": cd}


static func _learned(id: String) -> bool:
	return SkillDB.abilities(Profile.skills()).has(id)


## The tooltip's body: name, what it does, its numbers for this build, its
## runes, the Hearthtree notables that change it, and whether it is learned.
static func tip(id: String, width := 170) -> VBoxContainer:
	var v := UIKit.vbox(2)
	var d := GearDB.ability(id)
	var h := UIKit.hbox(4)
	var ic := UIKit.icon_rect(String(d.get("icon", "flare")))
	h.add_child(ic)
	h.add_child(UIKit.label(String(d.get("name", id)).to_upper(), 8, UIKit.C_GOLD, true))
	v.add_child(h)
	v.add_child(UIKit.para(String(d.get("desc", "")), width, UIKit.C_TEXT))
	var n := numbers(id)
	var line := "%d Kindle    %s s rest" % [int(round(n.cost)), str(snappedf(n.cd, 0.1))]
	v.add_child(UIKit.label(line, 8, UIKit.C_EMBER))
	var facts: Array = []
	if d.has("damage"):
		facts.append("%d damage" % int(d.damage))
	if d.has("radius"):
		facts.append("%s tiles around" % str(snappedf(float(d.radius), 0.1)))
	if d.has("range"):
		facts.append("reaches %s tiles" % str(snappedf(float(d.range), 0.1)))
	if d.has("duration"):
		facts.append("lasts %s s" % str(snappedf(float(d.duration), 0.1)))
	if not facts.is_empty():
		v.add_child(UIKit.label(", ".join(facts), 8, UIKit.C_DIM))
	var pl := _pl()
	for r in Runes.of(pl, id) if pl else []:
		if String(r) == "":
			continue
		var rd := Runes.get_def(String(r))
		v.add_child(UIKit.para("%s: %s" % [rd.get("name", r), Runes.describe(String(r), id)], width, rd.get("color", UIKit.C_SOUL)))
	for nid in SYNERGY.get(id, []):
		var node := SkillDB.node(String(nid))
		if node.is_empty():
			continue
		var has := Profile.skills().has(nid)
		var txt := ("Hearthtree - %s: %s" % [node.name, node.get("desc", "")]) if has else ("Pairs with %s on the Hearthtree" % node.name)
		v.add_child(UIKit.para(txt, width, UIKit.C_GOOD if has else UIKit.C_DIM))
	if not _learned(id):
		v.add_child(UIKit.label("Not yet learned - the Hearthtree teaches it", 8, UIKit.C_BAD))
	return v


## A spell slot or a spell to choose: its icon in a carved frame, the key that
## casts it, its name and its numbers. `id` "" is an empty slot.
static func card(id: String, key: String, w := 96, selected := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, 26)
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_FILL
	sb.border_color = C_FRAME_HI if selected else C_FRAME
	sb.set_border_width_all(1)
	sb.content_margin_left = 3
	var hi := sb.duplicate() as StyleBoxFlat
	hi.border_color = C_FRAME_HI
	hi.bg_color = Color(0.12, 0.09, 0.08)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hi)
	b.add_theme_stylebox_override("pressed", hi)
	b.add_theme_stylebox_override("focus", UIKit._focus_box())
	# the icon well
	var well := ColorRect.new()
	well.color = Color(0.02, 0.02, 0.03)
	well.position = Vector2(3, 3)
	well.size = Vector2(20, 20)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(well)
	var d := GearDB.ability(id) if id != "" else {}
	var ic := TextureRect.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.texture = UIKit.icon(String(d.get("icon", "flare"))) if id != "" else null
	ic.position = Vector2(5, 5)
	ic.size = Vector2(16, 16)
	b.add_child(ic)
	if key != "":
		var k := UIKit.label(key, 8, UIKit.C_GOLD, true)
		k.position = Vector2(2, 15)
		k.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(k)
	var nm := UIKit.label(String(d.get("name", "Empty")) if id != "" else "Empty", 8, UIKit.C_TEXT if id != "" else UIKit.C_DIM)
	nm.position = Vector2(27, 3)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nm)
	var sub := ""
	if id != "":
		var n := numbers(id)
		sub = "%d Kindle  %ss" % [int(round(n.cost)), str(snappedf(n.cd, 0.1))]
	else:
		sub = "choose a spell"
	var sl := UIKit.label(sub, 8, UIKit.C_EMBER if id != "" else UIKit.C_DIM)
	sl.position = Vector2(27, 13)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sl)
	return b


## The third slot before it opens: a sealed well with a lock, what it is for
## and when it opens.
static func locked_card(level: int, w := 96) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.03, 0.05)
	sb.border_color = Color(0.26, 0.22, 0.28)
	sb.set_border_width_all(1)
	sb.content_margin_left = 3
	sb.content_margin_top = 2
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(w, 26)
	var h := UIKit.hbox(4)
	p.add_child(h)
	var ic := UIKit.icon_rect("lock")
	ic.modulate = Color(0.75, 0.7, 0.8, 0.8)
	h.add_child(ic)
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label("Third spell", 8, Color(0.75, 0.7, 0.8)))
	v.add_child(UIKit.label("opens at Lv %d" % level, 8, UIKit.C_DIM))
	h.add_child(v)
	p.tooltip_text = "A third spell slot opens at level %d (you are level %d): one more spell to carry below." % [level, Profile.level()]
	return p
