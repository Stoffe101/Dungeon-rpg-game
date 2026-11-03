## Who decides what in a shared expedition, and the host side of every
## interaction a guest can use (docs/DESIGN.md, "Co-op interactions"):
##
## - personal: the merchant (each Kindled has their own stock and pays from
##   their own Embers), the shrine of pacts and the Echo (one bargain each),
##   lore (read on your own screen);
## - shared, first come: the Ember Well (whoever draws pays the health; the
##   Embers spill for everyone), lost camps, sconces, chests (and every Kindled
##   gets their own relic pick from a chest);
## - voted (everyone in the party agrees): the stairs, the Hearthstone, the
##   Trial, a Hearthcall.
##
## Guests' screens ask the host (Net.ask); the host checks and applies it to
## that Kindled. Every request is checked against that Kindled's own state
## (sold, spent, taken, already voted), so a repeated request changes nothing.
class_name Party
extends RefCounted

const VOTED := ["stairs", "hearthstone", "trial"]
const VOTE_TIME := 30.0


## The host's answer to someone using a prop in a shared expedition. False:
## not a co-op matter, the single-player path handles it (the host's own Kindled).
static func serve(d: Dungeon, who: Player, what: String, prop: Prop) -> bool:
	if not Net.active():
		return false
	var nr := Net.i.run_sync
	if what in VOTED and Net.party_size() > 1 and nr:
		nr.start_vote(what, prop.net_idx, who)
		return true
	if who.controller != Player.Ctrl.REMOTE:
		return false
	var pid := who.peer_id
	match what:
		"merchant":
			_send(pid, "shop", [prop.net_idx, shop_stock(d, who, prop)])
		"shrine":
			_send(pid, "shrine", [prop.net_idx, shrine_curse(d, who, prop), spent(prop, who)])
		"echo":
			var line: Array = Lore.random_for(d.layout.region, d.rng)
			_send(pid, "echo", [prop.net_idx, String(line[1]), spent(prop, who)])
		"lore":
			_send(pid, "lore", [Lore.random_for(d.layout.region, d.rng)])
		"well":
			_send(pid, "confirm", [prop.net_idx, "well", "Draw from the Ember Well?",
				"Lose 20%% of your health. Gain about %d Embers (for the whole party)." % well_gain(d)])
		_:
			return false
	return true


static func _send(pid: int, kind: String, args: Array) -> void:
	if Net.active():
		Net.i.rpc_id(pid, "_offer", kind, args)


## Has this Kindled had its bargain here?
static func spent(prop: Prop, who: Player) -> bool:
	return prop.used or prop.data.has("used_%d" % who.peer_id)


## Marks this Kindled's bargain; the prop is spent once every Kindled has had one.
static func spend(d: Dungeon, prop: Prop, who: Player) -> void:
	prop.data["used_%d" % who.peer_id] = true
	for pl in d.players:
		if is_instance_valid(pl) and not prop.data.has("used_%d" % pl.peer_id):
			return
	prop.used = true


## A line for one Kindled's screen (theirs, wherever it is).
static func tell(who: Player, text: String, col: Color) -> void:
	if Net.active() and Net.i.run_sync:
		Net.i.run_sync.tell(who, text, col)
	else:
		Events.toast.emit(text, col)


static func skills_of(who: Player) -> Array:
	return Profile.skills() if who.sheet.is_empty() else who.sheet.get("skills", ["hearth"])


# --- the Cinder Merchant: a stock for each Kindled ---------------------------------------

static func shop_stock(d: Dungeon, who: Player, prop: Prop) -> Array:
	var key := "stock_%d" % who.peer_id
	if not prop.data.has(key):
		var run := who.run
		var skills := skills_of(who)
		var ids := RelicDB.roll_offer(d.run.rng, 3, run.relics, SkillDB.branch_counts(skills), SkillDB.abilities(skills), d.layout.depth, false)
		var stock: Array = []
		for id in ids:
			var r := RelicDB.relic(id)
			var price: int = {"common": 45, "rare": 80, "epic": 130}[r.rarity] + 15 * (d.layout.depth - 1)
			stock.append({"kind": "relic", "id": id, "price": price})
		stock.append({"kind": "flask", "price": 35})
		stock.append({"kind": "heal", "price": 25})
		prop.data[key] = stock
	return prop.data[key]


static func buy(d: Dungeon, who: Player, prop: Prop, i: int) -> bool:
	var stock := shop_stock(d, who, prop)
	if i < 0 or i >= stock.size() or who.run == null:
		return false
	var item: Dictionary = stock[i]
	if item.get("sold", false) or who.run.embers < int(item.price):
		return false
	who.run.embers -= int(item.price)
	item["sold"] = true
	match String(item.kind):
		"relic":
			Game.grant_relic_to(who, String(item.id))
		"flask":
			who.flask = mini(who.flask + 1, int(who.stats.v("flask_charges")))
		"heal":
			who.heal(who.max_hp * 0.4)
	return true


# --- the shrine of pacts: one bargain each -------------------------------------------------

static func shrine_curse(d: Dungeon, who: Player, prop: Prop) -> String:
	var key := "curse_%d" % who.peer_id
	if not prop.data.has(key):
		var curses: Array = RelicDB.RELICS.filter(func(r): return r.get("cursed", false) and not who.run.relics.has(r.id))
		prop.data[key] = String(curses[d.run.rng.randi_range(0, curses.size() - 1)].id) if not curses.is_empty() else ""
	return String(prop.data[key])


## "blood": a quarter of their health for a rare relic of their choosing;
## "curse": the offered curse and 40 Embers.
static func shrine_choice(d: Dungeon, who: Player, prop: Prop, choice: String) -> void:
	if spent(prop, who) or not who.alive or who.downed:
		return
	match choice:
		"blood":
			spend(d, prop, who)
			who.hp = maxf(1.0, who.hp - who.max_hp * 0.25)
			d.fx.burst(who.pos, 1.0, Color(0.8, 0.2, 0.3), 16, 3.0, 0.5, 4.0)
			Audio.play_at("pact", who.pos, 0.0)
			var skills := skills_of(who)
			var offer := RelicDB.roll_offer(d.run.rng, 3, who.run.relics, SkillDB.branch_counts(skills), SkillDB.abilities(skills), d.layout.depth + 2, false)
			offer = offer.filter(func(id): return RelicDB.relic(id).rarity != "common")
			if offer.is_empty():
				offer = RelicDB.roll_offer(d.run.rng, 3, who.run.relics, {}, [], 3, false)
			offer_relic(d, who, prop, offer)
		"curse":
			var id := shrine_curse(d, who, prop)
			if id == "":
				return
			spend(d, prop, who)
			Game.grant_relic_to(who, id)
			who.run.embers += 40
			Audio.play_at("pact", who.pos, 0.0, 0.8)


# --- relic picks: each Kindled chooses on their own screen ---------------------------------

## Offers `offer` to one Kindled: the host's own pick opens here, a guest's on
## their machine (answered through Dungeon.coop_relic_pick).
static func offer_relic(d: Dungeon, who: Player, prop: Prop, offer: Array, on_taken := Callable()) -> void:
	if offer.is_empty():
		return
	if who.controller == Player.Ctrl.REMOTE:
		prop.data["offer_%d" % who.peer_id] = offer
		_send(who.peer_id, "relic", [prop.net_idx, offer])
		return
	if who.autopilot:
		Game.grant_relic_to(who, offer[0])
		if on_taken.is_valid():
			on_taken.call()
		return
	Game.ui.relic_choice(offer, func(id: String) -> void:
		if id != "":
			Game.grant_relic_to(who, id)
			if on_taken.is_valid():
				on_taken.call())


# --- the Echo: one offering each ---------------------------------------------------------

static func echo_gift(d: Dungeon, who: Player, prop: Prop) -> void:
	if spent(prop, who):
		return
	if who.run.embers < 30:
		tell(who, "You do not carry enough Embers.", Color(0.8, 0.7, 0.7))
		return
	spend(d, prop, who)
	who.run.embers -= 30
	var skills := skills_of(who)
	var offer := RelicDB.roll_offer(d.run.rng, 1, who.run.relics, SkillDB.branch_counts(skills), SkillDB.abilities(skills), d.layout.depth + 1, false)
	if not offer.is_empty():
		Game.grant_relic_to(who, offer[0])
	if prop.used:
		prop.sprite.set_instance_shader_parameter("tint", Color(1, 1, 1, 0.3))
	Audio.play_at("relic", prop.pos, 0.0, 0.9)


# --- the Ember Well: shared, first come ----------------------------------------------------

static func well_gain(d: Dungeon) -> int:
	return 40 + 25 * d.layout.depth


static func draw_well(d: Dungeon, who: Player, prop: Prop) -> void:
	if prop.used or not who.alive or who.downed:
		return
	prop.used = true
	var gain := well_gain(d)
	who.hp = maxf(1.0, who.hp - who.max_hp * 0.2)
	d.fx.burst(who.pos, 0.8, Color(0.9, 0.25, 0.3), 14, 3.0, 0.5, 4.0)
	for i in 10:
		Pickup.spawn(d, "ember", prop.pos, int(ceil(gain / 10.0)))
	prop.sprite.play("empty")
	if prop.light:
		prop.light.light_energy = 0.2
	Audio.play_at("pact", prop.pos, -2.0, 1.2)


# --- client: the screens for what the host offered -------------------------------------------

static var _shop_view := {}     # the open guest shop: {"idx", "stock", "rebuild"}


static func on_offer(kind: String, args: Array) -> void:
	var ui := Game.ui
	var d := Game.stage as Dungeon
	if ui == null or d == null:
		return
	match kind:
		"relic":
			var idx := int(args[0])
			if _bot():
				Net.ask("relic", [idx, args[1][0]])
				return
			ui.relic_choice(args[1], func(id: String) -> void:
				if id != "":
					Net.ask("relic", [idx, id]))
		"shop":
			var idx2 := int(args[0])
			if not _shop_view.is_empty() and int(_shop_view.idx) == idx2 and is_instance_valid(_shop_view.get("node")):
				_shop_view.stock = args[1]
				(_shop_view.rebuild as Callable).call()
			elif not _bot():
				ui.open(Screens.shop_view(ui, idx2, args[1]))
		"shrine":
			if not _bot():
				ui.open(Screens.shrine_view(ui, int(args[0]), String(args[1]), bool(args[2])))
		"echo":
			var idx3 := int(args[0])
			var ask := func() -> void: Net.ask("echo", [idx3])
			if bool(args[2]):
				ui.dialogue("Echo of a Fallen Kindled", ["...the light was warm, once. Go on. Carry it further than I did."])
			elif _bot():
				ask.call()
			else:
				ui.dialogue("Echo of a Fallen Kindled", ["I came down with a lantern like yours. %s" % String(args[1]),
					"Leave a little light for me - thirty Embers - and take what I no longer need."], Callable(),
					[["Offer 30 Embers (you carry %d)" % (Game.run.embers if Game.run else 0), ask], ["Leave", Callable()]])
		"lore":
			if not _bot():
				ui.lore(args[0])
		"confirm":
			var idx4 := int(args[0])
			var what := String(args[1])
			if _bot():
				Net.ask("confirm", [idx4, what])
			else:
				ui.confirm(String(args[2]), String(args[3]), func() -> void: Net.ask("confirm", [idx4, what]))


static func _bot() -> bool:
	var d := Game.stage as Dungeon
	return d != null and d.player != null and d.player.autopilot


# --- votes (shown on every machine; tallied by the host, NetRun) ----------------------------


static func vote_title(kind: String, by: String) -> Array:
	match kind:
		"stairs":
			return ["Descend?", "%s is at the stairs. The whole party goes down together." % by]
		"hearthstone":
			return ["Return to the Last Hearth?", "%s would take the party home. Everyone keeps what they carry." % by]
		"trial":
			return ["Begin the Trial?", "%s would wake the altar. Three hard waves; the doors seal until it is done." % by]
		"hearthcall":
			return ["Answer the Hearthcall?", "%s calls the party home. Everyone keeps what they carry." % by]
	return ["Agree?", ""]


## A vote began (or someone answered): every machine shows the question on
## its request card (no pause, no focus taken: a fight goes on around it),
## with each Kindled's answer as it comes in.
static func show_vote(id: int, kind: String, by_peer: int, yes: Array, _need: int) -> void:
	var ui := Game.ui
	if ui == null:
		return
	if _bot() and not yes.has(Net.my_id()):
		answer(id, true)
		return
	var t := vote_title(kind, Net.name_of(by_peer))
	RequestCard.ensure(ui).show_vote(id, String(t[0]), String(t[1]), yes, Net.i.present(), VOTE_TIME)


static func end_vote(id: int, passed: bool, why: String) -> void:
	if Game.ui:
		RequestCard.ensure(Game.ui).end_vote(id)
		if why != "":
			Game.ui.toast(why, Color(0.75, 0.95, 0.9) if passed else Color(1.0, 0.7, 0.55))


static func answer(id: int, agree: bool) -> void:
	if Net.is_host():
		if Net.i.run_sync:
			Net.i.run_sync.cast_vote(Net.my_id(), id, agree)
	else:
		Net.ask("vote", [id, agree])
