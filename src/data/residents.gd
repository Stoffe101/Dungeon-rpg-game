## The survivors who gather at the Last Hearth as it grows. Each has a sprite,
## idle remarks (barks) and things to say when spoken to; both react to what
## the player has done.
class_name Residents
extends RefCounted

const LIST := [
	{"id": "ama", "name": "Ama", "title": "the Gardener", "sheet": "resident_ama", "likes": ["planters", "hearth"],
		"barks": ["Something green, in the dark. Imagine that.", "Mind the sprouts.", "The Hearth's warmth reaches the soil now."],
		"talk": [
			["I brought seeds down from the surface. Everyone said nothing grows without the sun.", "But the Hearth is a little piece of the sun, isn't it? Let's see who's right."],
			["Look at them! The sunblooms open toward the Hearth like it's morning.", "Every ember you bring back, they lean a little further. I think they know you."],
		]},
	{"id": "teodric", "name": "Teodric", "title": "the Old Guard", "sheet": "resident_teodric", "likes": ["dummies", "forge", "descent"],
		"barks": ["Keep your guard up. Even here.", "Ward late, not early. Late.", "My arm aches when the Undervault stirs."],
		"talk": [
			["I held the Ossuary gate for eleven years. Then the gate held me.", "The Guards down there carry shields like mine. Get behind them, or break them with something heavy."],
			["They say the Warden fell to you. I served under it, once, before it went hollow.", "Thank you. I mean that."],
		]},
	{"id": "wren", "name": "Wren", "title": "", "sheet": "resident_wren", "likes": ["hearth", "tent", "dummies"], "child": true,
		"barks": ["Are you going down again?", "I counted forty embers in the fire!", "Teodric says I'm not allowed near the Descent."],
		"talk": [
			["Is it true the sun was a big Hearth in the sky?", "...and it just went out? Nobody fed it?"],
			["When I'm bigger I'm going to carry a lantern too.", "Ama says the flowers grow because of you. Can you make one for me?"],
		]},
	{"id": "bram", "name": "Bram", "title": "the Lamplighter", "sheet": "resident_bram", "likes": ["posts", "descent"], "light": true,
		"barks": ["Another post to light. Another little victory.", "Wick, oil, flame. That's the whole job.", "The dark leans in at the edges. I lean back."],
		"talk": [
			["I light the posts. When the Hearth is strong enough to feed them all, the plateau won't be dark anywhere.", "Bring embers. I'll bring matches."],
			["Do you see how far the light reaches now? I walked to the edge last night and could still read by it.", "My father would have wept."],
		]},
	{"id": "hollis", "name": "Hollis", "title": "the Woodcutter", "sheet": "resident_hollis", "likes": ["crates", "forge", "cookpot"],
		"barks": ["Dead wood burns as well as any.", "Stew's on. Don't ask what's in it.", "The roots down there - what I could build with those."],
		"talk": [
			["There's still timber on the plateau. Grey, dead, but dry. It burns.", "The smith takes most of it. Fair trade for the nails."],
			["You've been to the Rootmire? Burn those brambles for me. Every one.", "...Actually, bring me a branch first. I want to see what it's made of."],
		]},
	{"id": "sefa", "name": "Sefa", "title": "the Singer", "sheet": "resident_sefa", "likes": ["hearth", "bench", "memorial"],
		"barks": ["Hm-hm-hmm...", "Sing with me sometime, Kindled.", "Every song I know ends with a sunrise."],
		"talk": [
			["I sing the names of the Kindled who didn't come back. It keeps the Hearth company.", "It keeps me company, too."],
			["I wrote a new verse. It's about you.", "Don't worry - it ends well. I decided."],
		]},
]


## How many residents have found the Hearth: more come as it grows and as
## expeditions return.
static func count_present() -> int:
	var runs := int(Profile.data.stats.get("runs", 0))
	return clampi(Profile.building("hearth") + runs / 3, 1, LIST.size())


static func get_def(id: String) -> Dictionary:
	for r in LIST:
		if r.id == id:
			return r
	return {}


## Progress tier for dialogue: 0 before the first Warden falls, 1 after.
static func tier() -> int:
	return 1 if int(Profile.data.world.get("warden_kills", 0)) > 0 else 0


static func talk(id: String) -> Array:
	var r := get_def(id)
	if r.is_empty():
		return ["..."]
	var t: Array = r.talk
	return t[mini(tier(), t.size() - 1)]


## A one-liner for when the player walks by: personal, or about recent events.
static func bark(id: String, rng: RandomNumberGenerator) -> String:
	var r := get_def(id)
	var pool: Array = r.get("barks", ["..."]).duplicate()
	var st: Dictionary = Profile.data.stats
	if not Profile.active_grudges().is_empty():
		pool.append("They whisper about %s down there. Be careful." % Profile.active_grudges()[0].name)
	if int(st.get("deaths", 0)) > 0:
		pool.append("You came back. That's what matters.")
	if int(Profile.data.world.get("warden_kills", 0)) > 0:
		pool.append("The Warden's gone. I still can't believe it.")
	if Profile.skill_points_free() > 0:
		pool.append("The Hearth is humming. It wants you.")
	return pool[rng.randi_range(0, pool.size() - 1)]


## Growth of the sanctuary's planters: 0 bare soil .. 3 glowing sunbloom.
static func garden_stage() -> int:
	var runs := int(Profile.data.stats.get("runs", 0))
	return clampi(Profile.building("hearth") - 1 + runs / 4, 0, 3)
