## Things worth saying once. A line the first time a thing is met, on this machine, never
## again; someone with a dozen expeditions behind them is taken to know already, and a
## setting turns them off. Nothing here stops play or opens anything.
class_name Hints
extends RefCounted

const COLOR := Color(0.62, 0.92, 0.86)
const EXPERIENCED := 12

const TEXT := {
	"ward": "Struck. Right mouse Wards: time it to the blow and it turns aside, and pays Kindle.",
	"spells": "Your lantern holds Kindle: spells spend it, and it is also how far your light reaches.",
	"spikes": "Those plates rise after they warn. Teeth only hurt while they are out.",
	"elite": "A named foe carries a power of its own, written over its head. It pays for itself.",
	"bramble": "Thorn can be cut, and it burns. Hedges with a root mound under them cannot be cut.",
	"altar": "A Hollow Altar. What you choose stays with this region, and can always be changed again.",
	"fork": "Two ways down. Each kind of stair leads to a different sort of floor.",
	"penitent": "A Penitent: stone while your lantern is turned on it. Do not turn your back.",
	"canopy": "A Canopy Mother: what stands under her can only be hurt from under her. Go in.",
	"slag": "Slag burns both sides. Lead them through it.",
	"snuffer": "A Snuffer steals your flame and runs. Bring it down to get it back.",
	"harvest": "Souls drifting to the Warden: strike every one down and it reels. Let one through and it reaps.",
	"bow": "A bow rewards patience: hold to draw, and let go as the string settles.",
	"evolve": "Great things gather Resonance as you use them. Their tooltip counts it.",
	"tree": "You have points to spend in the Hearthtree (K). Changing your mind costs nothing.",
	"notice": "The noticeboard pays for doing things you might do anyway. Nothing on it expires.",
}
const FOES := {"penitent": "penitent", "canopy_mother": "canopy", "slagbearer": "slag", "snuffer": "snuffer", "soul_mote": "harvest"}


static func enabled() -> bool:
	return bool(Settings.get_value("hints", true)) and int(Profile.data.stats.get("runs", 0)) < EXPERIENCED


static func seen(id: String) -> bool:
	return (Profile.data.world.get("hints", {}) as Dictionary).has(id)


## Says it, if it has not been said here before.
static func give(id: String) -> bool:
	if not enabled() or seen(id) or not TEXT.has(id):
		return false
	var h: Dictionary = Profile.data.world.get("hints", {})
	h[id] = true
	Profile.data.world["hints"] = h
	Net.mute += 1
	Events.toast.emit(String(TEXT[id]), COLOR)
	Net.mute -= 1
	return true


## What this machine's Kindled can see from where they stand (Dungeon, twice a second).
static func look_around(st: Stage, pl: Player) -> void:
	if pl == null or not enabled():
		return
	if pl.hp < pl.max_hp * 0.98:
		give("ward")
	if pl.kindle >= pl.kindle_max() * 0.5:
		give("spells")
	for a in st.actors:
		if not a is Enemy or not a.alive or a.pos.distance_to(pl.pos) > 12.0:
			continue
		var e := a as Enemy
		if e.elite:
			give("elite")
		if FOES.has(e.id):
			give(String(FOES[e.id]))
	for p in st.props:
		if not is_instance_valid(p) or p.pos.distance_to(pl.pos) > 5.0:
			continue
		match String(p.kind):
			"spikes":
				give("spikes")
			"bramble":
				give("bramble")
			"site":
				if String(p.data.get("event", "")) == "altar":
					give("altar")
			"stairs":
				if p.data.has("route"):
					give("fork")
	if pl.weapon and pl.weapon.id == "bow":
		give("bow")
	for slot in Profile.equipped():
		var it: Variant = Profile.equipped()[slot]
		if it is Dictionary and Evolutions.can_evolve(it):
			give("evolve")
			break
