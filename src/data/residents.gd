## The survivors who gather at the Last Hearth as it grows. Each has a sprite,
## idle remarks (barks) and things to say when spoken to; both react to what
## the player has done. Each also has a request: something only the Kindled can
## do in the Undervault, tracked across expeditions and repaid with a permanent
## gift (Profile.data.requests: id -> {state: active|complete|rewarded, n}).
class_name Residents
extends RefCounted

const LIST := [
	{"id": "ama", "name": "Ama", "title": "the Gardener", "sheet": "resident_ama", "likes": ["planters", "hearth"],
		"barks": ["Something green, in the dark. Imagine that.", "Mind the sprouts.", "The Hearth's warmth reaches the soil now."],
		"request": {"key": "chest", "goal": 4, "title": "Seed Caches",
			"ask": ["The old Kindled hid seed caches in their chests down there. Sealed, dry, waiting.", "Open what chests you find. Whatever grows, I'll grow. (Open 4 chests.)"],
			"done": ["Oh - look at these. Some of them are still alive!", "Take this pouch of hearthroot. Steep it in your flask; it mends deeper."],
			"reward": [["flask_heal", "add", 0.1]], "gift": "Hearthroot Pouch: flasks heal 10% more of your health"},
		"talk": [
			["I brought seeds down from the surface. Everyone said nothing grows without the sun.", "But the Hearth is a little piece of the sun, isn't it? Let's see who's right."],
			["Look at them! The sunblooms open toward the Hearth like it's morning.", "Every ember you bring back, they lean a little further. I think they know you."],
		]},
	{"id": "teodric", "name": "Teodric", "title": "the Old Guard", "sheet": "resident_teodric", "likes": ["dummies", "forge", "descent"],
		"barks": ["Keep your guard up. Even here.", "Ward late, not early. Late.", "My arm aches when the Undervault stirs."],
		"request": {"key": "ward", "goal": 15, "title": "The Old Guard's Lesson",
			"ask": ["You Ward like a recruit. Late is good - too late is a funeral.", "Turn aside fifteen blows down there, cleanly, and I'll teach you the rest. (Ward 15 attacks.)"],
			"done": ["Fifteen. And you're still standing. Good.", "Here's the rest: don't watch the blade, watch the shoulder. You'll find you have a little more time."],
			"reward": [["parry_window", "add", 0.03]], "gift": "Watch the Shoulder: your Ward window is longer"},
		"talk": [
			["I held the Ossuary gate for eleven years. Then the gate held me.", "The Guards down there carry shields like mine. Get behind them, or break them with something heavy."],
			["They say the Warden fell to you. I served under it, once, before it went hollow.", "Thank you. I mean that."],
		]},
	{"id": "wren", "name": "Wren", "title": "", "sheet": "resident_wren", "likes": ["hearth", "tent", "dummies"], "child": true,
		"barks": ["Are you going down again?", "I counted forty embers in the fire!", "Teodric says I'm not allowed near the Descent."],
		"request": {"key": "toy", "goal": 1, "title": "The Wooden Bird",
			"ask": ["I lost my bird! The wooden one. I think it fell down the Descent.", "It's small and it has a red wing. If you find it... please? (Find Wren's bird in a chest.)"],
			"done": ["My bird! You found it! It's only a little bit scorched.", "Here - this is my lucky button. It finds shiny things. You keep it."],
			"reward": [["ember_gain", "add", 0.1]], "gift": "Wren's Lucky Button: +10% Embers found"},
		"talk": [
			["Is it true the sun was a big Hearth in the sky?", "...and it just went out? Nobody fed it?"],
			["When I'm bigger I'm going to carry a lantern too.", "Ama says the flowers grow because of you. Can you make one for me?"],
		]},
	{"id": "bram", "name": "Bram", "title": "the Lamplighter", "sheet": "resident_bram", "likes": ["posts", "descent"], "light": true,
		"barks": ["Another post to light. Another little victory.", "Wick, oil, flame. That's the whole job.", "The dark leans in at the edges. I lean back."],
		"request": {"key": "sunshard", "goal": 3, "title": "A Wick That Never Gutters",
			"ask": ["The posts burn oil, but the Hearth burns sun. Sunshards would make a wick that never gutters.", "Bring three home from the deep. (Collect 3 Sunshards.)"],
			"done": ["Three shards. Listen to them hum.", "I've woven one into your lantern's wick. It will hold more fire now."],
			"reward": [["kindle_max", "add", 15.0]], "gift": "Sunwoven Wick: +15 maximum Kindle"},
		"talk": [
			["I light the posts. When the Hearth is strong enough to feed them all, the plateau won't be dark anywhere.", "Bring embers. I'll bring matches."],
			["Do you see how far the light reaches now? I walked to the edge last night and could still read by it.", "My father would have wept."],
		]},
	{"id": "hollis", "name": "Hollis", "title": "the Woodcutter", "sheet": "resident_hollis", "likes": ["crates", "forge", "cookpot"],
		"barks": ["Dead wood burns as well as any.", "Stew's on. Don't ask what's in it.", "The roots down there - what I could build with those."],
		"request": {"key": "bramble", "goal": 25, "title": "Thin the Thickets",
			"ask": ["Those brambles in the Rootmire choke everything. Cut them, burn them, I don't care which.", "Twenty-five should thin them out. (Clear 25 brambles.)"],
			"done": ["Twenty-five! The roots must be screaming.", "Here, take some of my kindling. Fire catches faster with a good start."],
			"reward": [["fire_damage", "add", 0.08]], "gift": "Hollis's Kindling: +8% fire damage"},
		"talk": [
			["There's still timber on the plateau. Grey, dead, but dry. It burns.", "The smith takes most of it. Fair trade for the nails."],
			["You've been to the Rootmire? Burn those brambles for me. Every one.", "...Actually, bring me a branch first. I want to see what it's made of."],
		]},
	{"id": "sefa", "name": "Sefa", "title": "the Singer", "sheet": "resident_sefa", "likes": ["hearth", "bench", "memorial"],
		"barks": ["Hm-hm-hmm...", "Sing with me sometime, Kindled.", "Every song I know ends with a sunrise."],
		"request": {"key": "elite", "goal": 4, "title": "A Verse for Champions",
			"ask": ["A song needs a hero, and a hero needs foes worth the verse.", "Bring down four of the Undervault's champions and I'll have my chorus. (Defeat 4 elite enemies.)"],
			"done": ["Four champions! The verse writes itself.", "Listen... there. Every time it's sung, you'll remember a little more of what you learn down there."],
			"reward": [["xp_gain", "add", 0.1]], "gift": "Sefa's Verse: +10% Memories gained"},
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


## Has this resident found this profile's Hearth? (A guest in a friend's
## sanctuary meets residents of the host's camp that may not live in theirs.)
static func present(id: String) -> bool:
	var n := count_present()
	for i in n:
		if String(LIST[i].id) == id:
			return true
	return false


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
	match request_state(id):
		"":
			if r.has("request") and rng.randf() < 0.6:
				return ["Kindled - could I ask you something?", "Have you a moment? I need a favour.", "When you've time... I have a request."][rng.randi_range(0, 2)]
		"complete":
			return ["You did it? Come, tell me!", "Is that - come here, quickly!", "You've done it, haven't you?"][rng.randi_range(0, 2)]
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


# --- requests -----------------------------------------------------------------------

static func _requests() -> Dictionary:
	if not Profile.data.has("requests"):
		Profile.data["requests"] = {}
	return Profile.data.requests


## "" (not asked yet), "active", "complete" (ready to hand in) or "rewarded".
static func request_state(id: String) -> String:
	return String(_requests().get(id, {}).get("state", ""))


static func request_progress(id: String) -> int:
	return int(_requests().get(id, {}).get("n", 0))


static func start_request(id: String) -> void:
	if request_state(id) == "":
		_requests()[id] = {"state": "active", "n": 0}


## Counts something the Kindled did ("chest", "ward", "toy", "sunshard", "bramble",
## "elite"). Returns the names of residents whose request just completed.
static func note(key: String, amount := 1) -> Array:
	var done: Array = []
	for r in LIST:
		var req: Dictionary = r.get("request", {})
		if req.get("key", "") != key or request_state(r.id) != "active":
			continue
		var st: Dictionary = _requests()[r.id]
		st.n = mini(int(st.n) + amount, int(req.goal))
		if int(st.n) >= int(req.goal):
			st.state = "complete"
			done.append(r.name)
	return done


## Hands in a completed request; its gift is permanent from now on.
static func claim(id: String) -> bool:
	if request_state(id) != "complete":
		return false
	_requests()[id].state = "rewarded"
	return true


## Wren's bird turns up in the next chest opened while she is waiting for it.
static func wants_toy() -> bool:
	return request_state("wren") == "active"


static func apply_rewards(stats: Stats) -> void:
	for r in LIST:
		if request_state(r.id) == "rewarded":
			stats.apply_mods(r.request.reward)


## One line per request the player knows about, for the pause menu.
static func journal() -> Array:
	var out: Array = []
	for r in LIST:
		var st := request_state(r.id)
		if st == "":
			continue
		var req: Dictionary = r.request
		match st:
			"active":
				out.append(["%s - %s: %d/%d" % [r.name, req.title, request_progress(r.id), int(req.goal)], "active"])
			"complete":
				out.append(["%s - %s: done! Return to %s." % [r.name, req.title, r.name], "complete"])
			"rewarded":
				out.append(["%s - %s" % [r.name, req.gift], "rewarded"])
	return out

