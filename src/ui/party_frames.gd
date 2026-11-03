## The party, always on screen while you are in one - in the sanctuary and
## below: a card for every other Kindled with their portrait (in their own
## armour and look), name, level, health (with numbers) and Kindle, ringed in
## their seat colour. A card says plainly when its Kindled is down (and how
## long they can wait), fallen, has lost the link, or is somewhere else (at the
## menu, reading the summary). Health changes ease in, with a flash.
##
## Data: every Kindled on this stage is a Player (the host simulates guests;
## a guest draws the host's word); levels come from each player's sheet.
class_name PartyFrames
extends Control

const W := 150
const H := 27
const GAP := 3

var _cards := {}       # peer -> _Card


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Net.i.roster_changed.connect(_rebuild)
	Net.i.sheet_changed.connect(func(pid: int) -> void:
		if _cards.has(pid):
			(_cards[pid] as _Card).set_sheet(Net.i.roster.get(pid, {}).get("sheet", {})))
	_rebuild()


func _rebuild() -> void:
	var want: Array = []
	if Net.active() and Net.party_size() > 1:
		var seats: Array = Net.i.roster.keys()
		seats.sort_custom(func(a, b): return int(Net.i.roster[a].slot) < int(Net.i.roster[b].slot))
		for pid in seats:
			if int(pid) != Net.my_id():
				want.append(int(pid))
	for pid in _cards.keys():
		if not want.has(pid):
			(_cards[pid] as Node).queue_free()
			_cards.erase(pid)
	for k in want.size():
		var pid: int = want[k]
		if not _cards.has(pid):
			var c := _Card.new()
			c.pid = pid
			add_child(c)
			c.set_sheet(Net.i.roster[pid].get("sheet", {}))
			_cards[pid] = c
		var card: _Card = _cards[pid]
		card.position = Vector2(0, k * (H + GAP))
	custom_minimum_size = Vector2(W, want.size() * (H + GAP))
	size = custom_minimum_size
	visible = not want.is_empty()


## Where this card's Kindled is on this machine's stage (null: not here).
static func actor_of(pid: int) -> Player:
	var st: Stage = Game.stage
	if st == null:
		return null
	for pl in st.players:
		if is_instance_valid(pl) and pl.peer_id == pid:
			return pl
	return null


class _Card:
	extends Control

	var pid := 0
	var hp_shown := 1.0
	var hp_lag := 1.0
	var flash := 0.0
	var flash_col := Color.WHITE
	var _last_hp := -1.0
	var _portrait: Control
	var _sheet := {}

	func _ready() -> void:
		custom_minimum_size = Vector2(PartyFrames.W, PartyFrames.H)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_sheet(sh: Dictionary) -> void:
		_sheet = sh
		if _portrait:
			_portrait.queue_free()
		_portrait = GearUI.head(sh, 16)
		_portrait.position = Vector2(4, 5)
		add_child(_portrait)

	func _process(delta: float) -> void:
		var pl := PartyFrames.actor_of(pid)
		var ratio := 1.0
		if pl and pl.alive:
			ratio = clampf(pl.hp / maxf(1.0, pl.max_hp), 0.0, 1.0)
		elif pl:
			ratio = 0.0
		if _last_hp >= 0.0 and pl:
			if pl.hp < _last_hp - 0.5:
				flash = 1.0
				flash_col = Color(1.0, 0.35, 0.3)
			elif pl.hp > _last_hp + 0.5:
				flash = 0.7
				flash_col = Color(0.55, 1.0, 0.6)
		_last_hp = pl.hp if pl else -1.0
		hp_shown = ratio
		hp_lag = maxf(hp_shown, move_toward(hp_lag, hp_shown, delta * 0.6))
		flash = maxf(0.0, flash - delta * 3.0)
		tooltip_text = _tip(pl)
		if _portrait:
			_portrait.modulate = Color(0.45, 0.42, 0.48) if (pl and not pl.alive) or _away() else Color.WHITE
		queue_redraw()

	func _away() -> bool:
		return bool(Net.i.roster.get(pid, {}).get("away", false))

	func _where() -> String:
		return String(Net.i.roster.get(pid, {}).get("where", ""))

	func _tip(pl: Player) -> String:
		var lines := ["%s   Lv %d" % [Net.name_of(pid), int(_sheet.get("level", 1))]]
		var wid := String(_sheet.get("weapon", "sword"))
		lines.append("%s +%d" % [GearDB.weapon(wid).get("name", wid), int(_sheet.get("weapon_level", 0))])
		if pl:
			lines.append("Health %d / %d   Kindle %d / %d" % [int(ceil(pl.hp)), int(pl.max_hp), int(pl.kindle), int(pl.kindle_max())])
		var w := Net.where_text(pid)
		if w != "":
			lines.append(w.capitalize())
		return "\n".join(PackedStringArray(lines))

	func _draw() -> void:
		var col := Net.color_of(pid)
		var pl := PartyFrames.actor_of(pid)
		var w := size.x
		var h := size.y
		# plate: ink rim, dark body, the seat's colour down the left edge
		draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.04, 0.82))
		draw_rect(Rect2(1, 1, w - 2, h - 2), Color(0.07, 0.06, 0.1, 0.9))
		var rim := Color(0.36, 0.27, 0.21).lerp(flash_col, flash * 0.8)
		draw_rect(Rect2(0, 0, w, 1), rim)
		draw_rect(Rect2(0, h - 1, w, 1), rim)
		draw_rect(Rect2(w - 1, 0, 1, h), rim)
		draw_rect(Rect2(0, 0, 2, h), col)
		# portrait frame
		draw_rect(Rect2(3, 4, 18, 18), Color(0.02, 0.02, 0.04))
		draw_rect(Rect2(3, 4, 18, 1), col.darkened(0.2))
		draw_rect(Rect2(3, 21, 18, 1), col.darkened(0.45))
		var x := 25.0
		var lvl := int(_sheet.get("level", 1))
		draw_string(UIKit.FONT_OUTLINE, Vector2(x, 9), Net.name_of(pid).substr(0, 12), HORIZONTAL_ALIGNMENT_LEFT, w - x - 32, 8, col)
		draw_string(UIKit.FONT_OUTLINE, Vector2(w - 31, 9), "Lv%d" % lvl, HORIZONTAL_ALIGNMENT_RIGHT, 28, 8, UIKit.C_DIM)
		var bw := w - x - 42.0
		var by := 12.0
		if _away():
			var p := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
			draw_string(UIKit.FONT_OUTLINE, Vector2(x, by + 9), "LINK LOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.55, 0.45, 0.55 + 0.45 * p))
			return
		if pl == null:
			var where: String = {"menu": "At the menu", "summary": "Reading the summary", "hub": "In camp", "below": "Below"}.get(_where(), "On the way")
			draw_string(UIKit.FONT_OUTLINE, Vector2(x, by + 9), where, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIKit.C_DIM)
			return
		# health
		draw_rect(Rect2(x - 1, by - 1, bw + 2, 7), Color(0.02, 0.02, 0.04))
		draw_rect(Rect2(x, by, bw, 5), Color(0.18, 0.05, 0.08))
		if pl.downed:
			# how long they can wait (orange) and the revive taking hold (white)
			var bleed := clampf(pl.bleed_t / Player.BLEED_TIME, 0.0, 1.0)
			draw_rect(Rect2(x, by, roundf(bw * bleed), 5), Color(1.0, 0.55, 0.3))
			draw_rect(Rect2(x, by + 4, roundf(bw * clampf(pl.revive_k, 0.0, 1.0)), 1), Color(1.0, 0.95, 0.7))
			var p2 := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 130.0)
			draw_string(UIKit.FONT_OUTLINE, Vector2(x + bw + 3, by + 6), "DOWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.5, 0.4, p2))
		elif not pl.alive:
			draw_string(UIKit.FONT_OUTLINE, Vector2(x + bw + 3, by + 6), "fallen", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIKit.C_DIM)
		else:
			draw_rect(Rect2(x, by, roundf(bw * hp_lag), 5), Color(0.95, 0.85, 0.6))
			draw_rect(Rect2(x, by, roundf(bw * hp_shown), 5), Color(0.8, 0.2, 0.25))
			draw_rect(Rect2(x, by, roundf(bw * hp_shown), 1), Color(0.95, 0.45, 0.42))
			if pl.barrier > 0.0 or pl.aegis_hp > 0.0:
				draw_rect(Rect2(x, by + 4, roundf(bw * minf(1.0, (pl.barrier + pl.aegis_hp) / maxf(1.0, pl.max_hp))), 1), Color(1.0, 0.85, 0.45))
			draw_string(UIKit.FONT_OUTLINE, Vector2(x + bw + 3, by + 6), "%d/%d" % [int(ceil(pl.hp)), int(pl.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, 40, 8, UIKit.C_TEXT)
		# kindle
		var ky := by + 7.0
		var kr := clampf(pl.kindle / maxf(1.0, pl.kindle_max()), 0.0, 1.0)
		draw_rect(Rect2(x - 1, ky - 1, bw + 2, 4), Color(0.02, 0.02, 0.04))
		draw_rect(Rect2(x, ky, bw, 2), Color(0.16, 0.08, 0.04))
		draw_rect(Rect2(x, ky, roundf(bw * kr), 2), Color(1.0, 0.85, 0.45) if kr >= 0.999 else Color(1.0, 0.6, 0.25))
