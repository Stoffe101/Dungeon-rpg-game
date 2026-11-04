## Minimap / full map of the current floor: visited rooms, known doors,
## room types of unexplored neighbours and the player's position.
class_name Minimap
extends Control

var big := false


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var d := Game.stage as Dungeon
	if d == null or d.layout == null:
		return
	var lay := d.layout
	var cw := 22.0 if big else 12.0
	var ch := 15.0 if big else 8.0
	var known := {}
	for r in lay.rooms:
		if r.visited:
			known[r.id] = 2
			for dd in r.doors:
				if not dd.secret and not known.has(dd.to):
					known[dd.to] = 1
	# a guardian's floor: its lair is felt from the start
	if lay.boss_depth and not known.has(lay.exit_id):
		known[lay.exit_id] = 1
	# the Bone Colossus remembered this depth: every hall, hidden ones too
	if d.remembered():
		for r in lay.rooms:
			if not known.has(r.id):
				known[r.id] = 1
	# frame
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.82))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.36, 0.27, 0.21), false, 1.0)
	# center the map on the current room (or the whole floor for the big map)
	var focus := Vector2(DungeonGen.GW * 0.5, DungeonGen.GH * 0.5)
	if not big and d.current_room:
		focus = _cell_center(d.current_room)
	var origin := size * 0.5 - Vector2(focus.x * cw, focus.y * ch)
	var clip := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	# connections
	for r in lay.rooms:
		if not known.has(r.id) or known[r.id] < 2:
			continue
		for dd in r.doors:
			if dd.secret and not lay.room(dd.to).visited:
				continue
			var o: Room = lay.room(dd.to)
			if not known.has(o.id):
				continue
			var a := origin + _door_point(r, dd, cw, ch)
			var b := a + Vector2(dd.dir) * (3.0 if not big else 5.0)
			if clip.has_point(a) and clip.has_point(b):
				draw_line(a, b, Color(0.55, 0.48, 0.42), 1.0)
	# rooms
	for r in lay.rooms:
		if not known.has(r.id):
			continue
		var rect := _room_rect(r, cw, ch)
		rect.position += origin
		rect = rect.intersection(clip)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var visited: bool = known[r.id] == 2
		var col := Color(0.22, 0.2, 0.28) if visited else Color(0.1, 0.09, 0.13)
		if r == d.current_room:
			col = Color(0.42, 0.34, 0.26)
		draw_rect(rect, col)
		draw_rect(rect, Color(0.6, 0.5, 0.4) if visited else Color(0.3, 0.27, 0.32), false, 1.0)
		var icon := _room_icon(r, visited)
		if icon != "" and rect.size.x > 6:
			var tex := UIKit.icon(icon)
			var s := 8.0 if not big else 12.0
			draw_texture_rect(tex, Rect2(rect.get_center() - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 0.9 if not visited else 0.6))
	# player
	if d.player and d.current_room:
		var r := d.current_room
		var rr := _room_rect(r, cw, ch)
		var rel := (d.player.pos - Vector2(r.rect.position)) / Vector2(r.rect.size)
		var pp := origin + rr.position + rel * rr.size
		if clip.has_point(pp):
			draw_rect(Rect2(pp - Vector2(1, 1), Vector2(3, 3)), Color(1.0, 0.75, 0.35))
	if big:
		var fl := String(Delve.floor_def(lay.region, lay.depth, d.run.delve)[0])
		draw_string(UIKit.FONT_OUTLINE, Vector2(6, 12), "%s - %s%s - Tier %s" % [Delve.NAME if d.run.delve else String(d.region.name), (fl + ", ") if fl != "" else "",
			Delve.depth_short(lay.region, lay.depth, d.run.delve), Difficulty.roman(d.run.tier)], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIKit.C_GOLD)


func _cell_center(r: Room) -> Vector2:
	var c := Vector2.ZERO
	for cell in r.cells:
		c += Vector2(cell) + Vector2(0.5, 0.5)
	return c / r.cells.size()


func _room_rect(r: Room, cw: float, ch: float) -> Rect2:
	var mn := Vector2(999, 999)
	var mx := Vector2(-1, -1)
	for c in r.cells:
		mn = mn.min(Vector2(c))
		mx = mx.max(Vector2(c))
	return Rect2(Vector2(mn.x * cw + 1, mn.y * ch + 1), Vector2((mx.x - mn.x + 1) * cw - 2, (mx.y - mn.y + 1) * ch - 2))


func _door_point(r: Room, dd: Dictionary, cw: float, ch: float) -> Vector2:
	var tiles: Array = dd.tiles
	var t: Vector2i = tiles[0]
	var cell := Vector2((t.x - DungeonGen.MARGIN) / float(DungeonGen.CELL_W), (t.y - DungeonGen.MARGIN) / float(DungeonGen.CELL_H))
	var rr := _room_rect(r, cw, ch)
	var p := Vector2(cell.x * cw, cell.y * ch)
	if dd.dir.x != 0:
		p.x = rr.position.x + (rr.size.x if dd.dir.x > 0 else 0.0)
	else:
		p.y = rr.position.y + (rr.size.y if dd.dir.y > 0 else 0.0)
	return p


func _room_icon(r: Room, visited: bool) -> String:
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
