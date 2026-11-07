## Deep Events: what can happen in an event room, as data. A new event is an
## entry here (where it may appear, how rare, what it looks like, what choosing
## does), not a change to the generator. Every interaction is a `site` prop:
## solo it asks and acts, in a party it is voted (a choice the whole expedition
## lives with) or taken alone (`personal`). All of it runs on the host; props and
## banners replicate like any other.
class_name DeepEvents
extends RefCounted

## regions: [] = all. weight: against the classic events (well, trial, echo,
## vault, camp - weight 3 each). min_depth: never above it.
const EVENTS := {
	"last_stand": {"regions": [], "min_depth": 1, "weight": 3},
	"procession": {"regions": ["ossuary", "throne"], "min_depth": 2, "weight": 2},
	"survivor": {"regions": [], "min_depth": 2, "weight": 5, "once": "maren"},
	"artisan": {"regions": [], "min_depth": 2, "weight": 1},
}

## A fight that plays by a rule of its own: rare, named as it starts, on the
## HUD while it lasts, and paid for with a chest when it is won. Everything about
## one is in the layout, so every machine knows it.
const RULES := {
	"one_pulse": {"name": "One Pulse", "line": "These foes share a heart: a blow to one is felt by all",
		"col": Color(1.0, 0.45, 0.42), "scar": "broken"},
	"unlit": {"name": "The Unlit Room", "line": "Your lantern shrinks here. Every kill feeds it",
		"col": Color(0.72, 0.62, 1.0), "scar": "pale"},
	"hungry": {"name": "The Hungry Floor", "line": "Swift foes, and each of them pays double",
		"col": Color(1.0, 0.62, 0.3), "scar": "kindled"},
}
const RULE_CHANCE := 24      # floors in a hundred, below the first


## Now and then one fight of a floor keeps a rule. An rng of its own: the rest
## of a seed's floor is the same with or without it.
static func rule_room(lay, seed_v: int) -> void:
	if lay.depth < 2 or lay.boss_depth:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, lay.depth, "rule"])
	var odds := RULE_CHANCE * (3 if String(Delve.band(lay.depth).get("id", "")) == "whisper" else 1)
	if rng.randi_range(0, 99) >= odds:
		return
	var cands: Array = []
	for r in lay.rooms:
		if r.type == Room.Type.COMBAT and r.objective == "" and r.landmark == "" and r.authored == "" and not r.grudge:
			cands.append(r)
	if cands.is_empty():
		return
	var r: Room = cands[rng.randi_range(0, cands.size() - 1)]
	r.rule = String(RULES.keys()[rng.randi_range(0, RULES.size() - 1)])
	r.reward = "rule"
	# the stone says so before the door does
	for k in 4:
		var t := DungeonGen._clear_tile(lay, r, rng, false)
		if t.x >= 0:
			r.props.append({"kind": "scar", "tile": t, "anim": String(RULES[r.rule].scar)})

## site choices: label over it, what it asks, its sheet and frame.
const COFFERS := {
	"gold": {"name": "The Gilded Coffer", "ask": "Open the gilded coffer", "line": "Arms and armour for each Kindled."},
	"bone": {"name": "The Bone Casket", "ask": "Open the bone casket", "line": "Rare materials, and a rune for each Kindled."},
	"glass": {"name": "The Glass Reliquary", "ask": "Open the glass reliquary", "line": "A relic, and a Gloamcap for each Kindled."},
}


## What this event room holds. The Hollow Altar is due on one floor of each
## expedition into a region (DungeonGen decides); otherwise the classics and
## the table, by weight.
static func pick(lay, rng: RandomNumberGenerator) -> String:
	if lay.altar_due:
		lay.altar_due = false
		return "altar"
	var pool: Array = []
	for e in Room.EVENTS:
		pool.append([String(e), 3])
	for id in EVENTS:
		var d: Dictionary = EVENTS[id]
		var regs: Array = d.regions
		if (lay.world.get("rescued", []) as Array).has(d.get("once", "")):
			continue     # a person is only lost once
		if lay.depth >= int(d.min_depth) and (regs.is_empty() or regs.has(lay.region)):
			pool.append([String(id), int(d.weight)])
	var total := 0
	for p in pool:
		total += int(p[1])
	var k := rng.randi_range(0, total - 1)
	for p in pool:
		k -= int(p[1])
		if k < 0:
			return String(p[0])
	return "well"


## The room's props (DungeonGen._decorate). Only open floor is used: a scene
## never takes a door or a tile the fight needs.
static func build(lay, r: Room, rng: RandomNumberGenerator) -> void:
	var c := Vector2i(r.center())
	var g: TileGrid = lay.grid
	var at := func(t: Vector2i) -> Vector2i:
		for rad in 3:
			for dy in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					var q := t + Vector2i(dx, dy)
					if g.at(q.x, q.y) == TileGrid.FLOOR and not DungeonGen._prop_at(r, q):
						return q
		return t
	match r.event:
		"altar":
			r.props.append({"kind": "site", "tile": at.call(c + Vector2i(0, -2)), "event": "altar_stone"})
			var o := [Vector2i(-4, 1), Vector2i(0, 2), Vector2i(4, 1)]
			var states := Chronicle.STATES.keys()
			for k in 3:
				r.props.append({"kind": "site", "tile": at.call(c + o[k]), "event": "altar", "choice": String(states[k])})
			for s in [Vector2i(-6, -2), Vector2i(6, -2)]:
				r.props.append({"kind": "candles", "tile": at.call(c + s)})
		"last_stand":
			# a barricade across the room, facing a door that is not there any more
			for k in 7:
				var t: Vector2i = at.call(c + Vector2i(-6 + k * 2, -2 + (k % 2)))
				var one: Array[Vector2i] = [t]
				if DungeonGen._floor_whole(lay, r, one):
					r.props.append({"kind": "dressing", "tile": t, "sheet": "barricade", "scene": true})
			for k in 9:
				var t: Vector2i = at.call(c + Vector2i(rng.randi_range(-7, 7), rng.randi_range(-3, 4)))
				r.props.append({"kind": "dressing", "tile": t, "sheet": "fallen_shield", "low": true, "scene": true})
			r.props.append({"kind": "site", "tile": at.call(c + Vector2i(0, 1)), "event": "dead_brazier"})
			r.props.append({"kind": "lore", "tile": at.call(c + Vector2i(-5, 3))})
		"procession":
			r.props.append({"kind": "trial_altar", "tile": at.call(c), "sheet": "bier", "label": "The Lost Procession",
				"ask": "Open the bier", "vote": "procession"})
			for k in 8:
				var a := TAU * k / 8.0
				var t: Vector2i = at.call(c + Vector2i(roundi(cos(a) * 5.0), roundi(sin(a) * 3.0)))
				r.props.append({"kind": "dressing", "tile": t, "sheet": "pallbearer_bones", "low": true, "scene": true})
			r.props.append({"kind": "lore", "tile": at.call(c + Vector2i(5, -3))})
		"survivor":
			# a camp made in a corner by someone who stopped expecting anyone
			r.props.append({"kind": "site", "tile": at.call(c), "event": "survivor"})
			for k in 5:
				var t: Vector2i = at.call(c + Vector2i(-5 + k * 2 + rng.randi_range(0, 1), 2 + (k % 2)))
				var one: Array[Vector2i] = [t]
				if DungeonGen._floor_whole(lay, r, one):
					r.props.append({"kind": "dressing", "tile": t, "sheet": "rubble", "anim": "a" if k % 2 == 0 else "b", "scene": true})
			r.props.append({"kind": "candles", "tile": at.call(c + Vector2i(-2, -1))})
		"artisan":
			r.props.append({"kind": "site", "tile": at.call(c), "event": "artisan"})
			r.props.append({"kind": "candles", "tile": at.call(c + Vector2i(3, 0))})
			r.props.append({"kind": "lore", "tile": at.call(c + Vector2i(-4, 2))})


## A `site` prop's look and words (Dungeon._place_props).
static func site_data(pd: Dictionary, region: String, world: Dictionary) -> Dictionary:
	var ev := String(pd.get("event", ""))
	var choice := String(pd.get("choice", ""))
	match ev:
		"altar_stone":
			var st := Chronicle.site_of(world, region)
			var nm := String(Chronicle.ALTARS.get(region, {}).get("name", "the Vigil"))
			return {"sheet": "hollow_altar", "anim": st if st != "" else "idle", "label": nm.capitalize(), "col": Color(0.75, 0.7, 0.85), "solid": true,
				"light": [(Chronicle.STATES.get(st, {}).get("color", Color(0.5, 0.55, 0.7)) as Color), 1.4, 6.0], "light_h": 1.2,
				"lines": String(Chronicle.ALTARS.get(region, {}).get("line", ""))}
		"altar":
			var s: Dictionary = Chronicle.STATES[choice]
			return {"sheet": "altar_offering", "anim": choice, "label": String(s.verb), "prompt": "Choose this", "radius": 1.5, "col": s.color,
				"solid": true, "light": [s.color, 0.8, 3.0], "light_h": 0.8}
		"spoor":
			return {"sheet": "spoor", "anim": "fresh", "label": "Its Trail", "prompt": "Read the trail", "radius": 1.6, "flat": true,
				"col": Color(0.55, 0.95, 0.9), "light": [Color(0.45, 0.95, 0.9), 0.6, 2.5], "light_h": 0.2}
		"survivor":
			return {"sheet": "resident_maren", "anim": "sit", "label": "Someone Alive", "prompt": "Help them up", "radius": 1.6,
				"col": Color(0.65, 0.85, 1.0), "solid": true, "light": [Color(1.0, 0.7, 0.4), 0.7, 3.5], "light_h": 0.6}
		"artisan":
			return {"sheet": "whetstone", "anim": "idle", "label": "A Travelling Grindstone", "prompt": "Whet your weapon", "radius": 1.5,
				"col": Color(1.0, 0.82, 0.5), "solid": true, "light": [Color(1.0, 0.7, 0.4), 0.9, 3.5], "light_h": 0.8}
		"dead_brazier":
			return {"sheet": "dead_brazier", "anim": "dead", "label": "A Cold Brazier", "prompt": "Rekindle it", "radius": 1.5, "col": Color(1.0, 0.7, 0.4), "solid": true}
		"bowl":
			return {"sheet": "pale_bowl", "anim": "idle", "label": "The Pale Bowl", "prompt": "Feed the Bowl: -25% health, a rare reagent", "radius": 1.5,
				"col": Color(0.72, 0.62, 1.0), "solid": true, "light": [Color(0.7, 0.6, 1.0), 0.9, 3.5], "light_h": 0.8}
		"coffer":
			var cf: Dictionary = COFFERS[choice]
			return {"sheet": "coffer", "anim": choice, "label": String(cf.name), "prompt": String(cf.ask), "radius": 1.4, "col": Color(1.0, 0.82, 0.45), "solid": true}
	return {}


## Is this site a choice the whole party answers (else whoever stands there)?
static func voted(prop: Prop) -> bool:
	return String(prop.data.get("event", "")) in ["altar", "coffer"]


## The vote's kind for a site: "site:<event>:<choice>".
static func vote_kind(prop: Prop) -> String:
	return "site:%s:%s" % [prop.data.get("event", ""), prop.data.get("choice", "")]


## The question a choice asks (solo: the confirm box; a party: the card).
static func ask(ev: String, choice: String) -> Array:
	match ev:
		"altar":
			var s: Dictionary = Chronicle.STATES.get(choice, {})
			return ["%s?" % s.get("verb", "Choose"), "Every later expedition here: %s" % s.get("short", "")]
		"coffer":
			var cf: Dictionary = COFFERS.get(choice, {})
			return ["%s?" % cf.get("name", "Open it"), "%s The others seal for good." % cf.get("line", "")]
	return ["Agree?", ""]


## Someone used a site (Dungeon.request "site"). Solo it asks first; a party's
## question was already voted through (Party.serve -> NetRun._check_vote).
static func interact(d: Dungeon, who: Player, prop: Prop) -> void:
	var ev := String(prop.data.get("event", ""))
	match ev:
		"altar", "coffer":
			var q := ask(ev, String(prop.data.get("choice", "")))
			d._ask(String(q[0]), String(q[1]), func() -> void: resolve(d, prop, who))
		_:
			resolve(d, prop, who)


## What a site does (host).
static func resolve(d: Dungeon, prop: Prop, who: Player) -> void:
	if prop == null or not is_instance_valid(prop) or prop.used:
		return
	var ev := String(prop.data.get("event", ""))
	var choice := String(prop.data.get("choice", ""))
	match ev:
		"altar":
			_altar(d, prop, choice)
		"dead_brazier":
			_last_stand(d, prop)
		"bowl":
			_bowl(d, prop, who)
		"coffer":
			_coffer(d, prop, choice)
		"spoor":
			prop.used = true
			if prop.sprite:
				prop.sprite.play("read")
			if prop.light:
				prop.light.visible = false
			d.fx.unmark(prop)
			d.hunt_sign("You read its trail")
		"survivor":
			_survivor(d, prop)
		"artisan":
			_artisan(d, prop, who)


static func _altar(d: Dungeon, prop: Prop, state: String) -> void:
	var region := d.layout.region
	var s: Dictionary = Chronicle.STATES[state]
	Chronicle.set_site(region, state)
	var col: Color = s.color
	for p in d.props:
		if not is_instance_valid(p) or p.kind != "site":
			continue
		if String(p.data.get("event", "")) == "altar":
			p.used = true
			if p.light:
				p.light.visible = false
			if p != prop and p.sprite:
				p.sprite.play("spent")
			d.fx.unmark(p)
		elif String(p.data.get("event", "")) == "altar_stone":
			if p.sprite and p.sprite.has_anim(state):
				p.sprite.play(state)
			if p.light:
				p.light.light_color = col
			d.fx.burst(p.pos, 1.2, col, 40, 4.0, 0.8, 6.0, Vector2.UP, 1.3)
			d.fx.ring(p.pos, 3.0, col, 0.6, 0.3)
			d.fx.flash_light(p.pos, 1.4, col, 4.0, 9.0, 0.7)
	d.fx.shake(0.25)
	Audio.play("altar_" + state, -2.0)
	Events.banner.emit(String(s.name).to_upper(), String(s.done))
	Net.rec(["wit", "altar_" + state])


static func _last_stand(d: Dungeon, prop: Prop) -> void:
	prop.used = true
	if prop.sprite:
		prop.sprite.play("lit")
	if not prop.light:
		prop._light(Color(1.0, 0.65, 0.35), 1.8, 7.0, Vector3(0, 1.4 * Iso.SQ2, 0.2))
	d.fx.burst(prop.pos, 0.8, Color(1.0, 0.65, 0.3), 24, 3.0, 0.6, 3.0, Vector2.UP, 1.2)
	Audio.play("hearth_feed", -4.0)
	var c := prop.pos
	Prop.make(d, "chest", Vector2i(d._open_spot(c + Vector2(2.0, 1.0))), {"tier": 2})
	Pickup.spawn(d, "ember", c, 6)
	Chronicle.mark("last_stand")
	Chronicle.note("A cold brazier lit again, among those who held the line.")
	Events.banner.emit("They Held Here", "Someone left this for whoever came after")
	Net.rec(["wit", "last_stand"])


## The Pale Pact: each Kindled once a floor. Blood for a reagent they may lack,
## and the Bowl remembers: their Grudges grow on the way home (RunState.pale).
static func _bowl(d: Dungeon, prop: Prop, who: Player) -> void:
	var taken: Array = prop.data.get("taken", [])
	if taken.has(who.peer_id):
		Events.toast.emit("The Bowl has had enough of you. This floor.", Color(0.72, 0.62, 1.0))
		return
	taken.append(who.peer_id)
	prop.data["taken"] = taken
	who.hp = maxf(1.0, who.hp - who.max_hp * 0.25)
	who.run.pale += 1
	var ids: Array = Tinctures.REAGENTS.keys()
	var id: String = ids[d.rng.randi_range(0, ids.size() - 1)]
	var solo := d.players.size() <= 1
	Pickup.spawn(d, "reagent", prop.pos + Vector2(0.8, 0.8), 1, {"id": id}, 0 if solo else who.peer_id)
	d.fx.motes(who.pos, 0.6, Color(0.72, 0.62, 1.0), 16, 1.6, 0.9, 0.4)
	Audio.play("blood_pact", -4.0)


## Maren: she has mapped this floor by hand for longer than she will say. She
## goes up with the next who climbs, and a chart table comes with her.
static func _survivor(d: Dungeon, prop: Prop) -> void:
	prop.used = true
	if prop.sprite:
		prop.sprite.play("idle")
	d.fx.unmark(prop)
	d.fx.burst(prop.pos, 0.8, Color(0.65, 0.85, 1.0), 20, 2.5, 0.7, 2.0, Vector2.UP, 1.2)
	Audio.play("relic", -4.0, 1.2)
	d.chart_floor()
	Chronicle.rescue("maren")
	Chronicle.mark("rescued")
	Chronicle.note("Maren, who drew the Undervault by hand, was found alive.")
	Events.banner.emit("Maren the Chartwright", "\"Take this floor, I drew it. Tell me there is still a Hearth up there\"")
	Net.rec(["wit", "rescued_maren"])


## A grindstone someone left turning: one edge each, for this expedition.
static func _artisan(d: Dungeon, prop: Prop, who: Player) -> void:
	var taken: Array = prop.data.get("taken", [])
	if taken.has(who.peer_id):
		Events.toast.emit("Your edge is as good as this stone can make it.", Color(1.0, 0.82, 0.5))
		return
	taken.append(who.peer_id)
	prop.data["taken"] = taken
	Game.grant_relic_to(who, "whetted")
	d.fx.burst(prop.pos, 0.6, Color(1.0, 0.75, 0.4), 18, 3.0, 0.4, 8.0)
	Audio.play("forge_upgrade", -8.0, 1.4)
	Events.toast.emit("Whetted: +12% weapon damage this expedition.", Color(1.0, 0.82, 0.5))
	Chronicle.mark("whetted")


## A treasury: the party chooses one, the others seal.
static func _coffer(d: Dungeon, prop: Prop, choice: String) -> void:
	for p in d.props:
		if is_instance_valid(p) and p.kind == "site" and String(p.data.get("event", "")) == "coffer":
			p.used = true
			d.fx.unmark(p)
			if p != prop and p.sprite:
				p.sprite.play("shut")
	var c := prop.pos + Vector2(0, 1.2)
	match choice:
		"gold":
			for k in 2:
				d._gear_drop(c, func() -> Dictionary: return ItemDB.random_drop(d.layout.region, d.layout.depth + 1, d.rng, 0.3, d.run.tier, d._favour))
		"bone":
			var rare: String = {"rootmire": "spore_silk", "throne": "sun_gold"}.get(d.layout.region, "soul_glass")
			Pickup.spawn(d, "material", c, 4, {"id": rare})
			Pickup.spawn(d, "material", c, 2, {"id": "ember_core"})
			d._rune_drop(c)
		"glass":
			Prop.make(d, "relic_altar", Vector2i(d._open_spot(c + Vector2(0, 1.0))), {"tier": 2})
			d._reagent_drop(c, "gloamcap", 1.0)
	d.fx.burst(prop.pos, 0.8, Color(1.0, 0.82, 0.45), 24, 3.0, 0.6, 3.0, Vector2.UP, 1.2)
	Audio.play("chest", 0.0, 0.9)
	Chronicle.mark("treasury_" + choice)
