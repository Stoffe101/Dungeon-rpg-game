## The Keeper's advice: reacts to what the player has (and hasn't) done yet.
class_name Keeper
extends RefCounted


static func lines() -> Array:
	var d := Profile.data
	var out: Array = []
	var st: Dictionary = d.stats
	if int(st.get("runs", 0)) == 0:
		out.append("Your lantern burns brighter the more Kindle you hold. Strike foes to stoke it, then spend it on your gifts.")
		out.append("When something winds up to strike, the floor will show you where. Dodge through it - at the very last moment, if you dare.")
		return out
	if Profile.skill_points_free() > 0:
		out.append("You have grown since you last communed with the Hearth. Spend what you've learned - %d point%s waiting." % [Profile.skill_points_free(), "" if Profile.skill_points_free() == 1 else "s"])
	if Profile.building("forge") == 0 and Profile.currency("embers") >= 40:
		out.append("The old forge lies in ruin to the west. Feed it embers and the smith will return to it.")
	if not Profile.active_grudges().is_empty():
		var g: Dictionary = Profile.active_grudges()[0]
		out.append("%s still wanders the Ossuary with your embers. The Undervault remembers - so should you." % g.name)
	for it in Profile.equipped().values():
		if it is Dictionary and not (it as Dictionary).is_empty() and Evolutions.ready(it):
			out.append("%s is asking you something. Open your Satchel and answer it." % ItemDB.item_name(it))
			break
	var falls: Dictionary = Chronicle.snapshot().falls
	if not falls.is_empty():
		var region: String = falls.keys()[0]
		out.append("Your lantern still lies cold in %s, depth %d. Light it again. It remembers you." % [EnemyDB.REGIONS.get(region, {}).get("name", region), int(falls[region].depth)])
	if Chronicle.rescued("maren"):
		out.append("Maren draws faster than the walls move, she says. Buy a chart before you go down and see if she is right.")
	var sites: Array = []
	for r in Chronicle.ALTARS:
		if Chronicle.site(r) != "":
			sites.append(Chronicle.site(r))
	if sites.has("broken"):
		out.append("Something walks that used to be kept. I can feel the Breach from here. You will want to be ready when you go to it.")
	elif sites.has("pact"):
		out.append("There is a paleness on you. Whatever you fed down there, it knows your name now. Mind your Grudges.")
	elif sites.has("kindled"):
		out.append("Someone is tending a Vigil again. I had not thought to feel that in my lifetime. Thank you.")
	if Chronicle.marks("hunts") > 0:
		out.append("You hunted it down through its own halls. It will not be the last thing that learns your name for that.")
	if int(d.world.get("delve_best", 0)) >= 10:
		out.append("You have been further down than anyone I ever sent. Tell me: does the light still look the same?")
	if int(d.world.get("warden_kills", 0)) == 0 and int(d.world.get("deepest", 0)) >= 2:
		out.append("The Warden swallows light. When it snuffs the braziers, give them back their fire. It cannot abide the flame.")
	if int(d.world.get("warden_kills", 0)) > 0:
		out.append("The Warden fell, and the Undervault noticed. Its dead will be stronger now - and so will what they guard.")
		out.append("With the Warden gone, the way to the Rootmire lies open. Bring fire. The brambles there remember it, and they are afraid.")
	if EnemyDB.region_unlocked("throne") and int(d.world.get("ashen_king_kills", 0)) == 0:
		out.append("Warden and Bloom both fallen... then the Sunken Throne will open for you. The last sun-king sits there in his ashes. When he puts out the sun, stand by a fire.")
	if int(d.world.get("ashen_king_kills", 0)) > 0 and Difficulty.unlocked() < Difficulty.MAX_TIER:
		out.append("You've felled a king. The deep will burn hotter for you now - choose a harder tier at the Descent, and win the Throne again to go deeper still.")
	if not Profile.scrolls().is_empty():
		out.append("You carry an unread blueprint. Open your satchel and learn it - the smith can forge things from those that I cannot describe.")
	out.append("Ward with the right hand: a well-timed Ward turns arrows back and leaves brutes reeling.")
	out.append("The Hearthstone at each stairway can carry you home. There's no shame in returning with full pockets.")
	return [out[randi() % out.size()]]
