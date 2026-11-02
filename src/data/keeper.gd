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
	if int(d.world.get("warden_kills", 0)) == 0 and int(d.world.get("deepest", 0)) >= 2:
		out.append("The Warden swallows light. When it snuffs the braziers, give them back their fire. It cannot abide the flame.")
	if int(d.world.get("warden_kills", 0)) > 0:
		out.append("The Warden fell, and the Undervault noticed. Its dead will be stronger now - and so will what they guard.")
	out.append("Ward with the right hand: a well-timed Ward turns arrows back and leaves brutes reeling.")
	out.append("The Hearthstone at each stairway can carry you home. There's no shame in returning with full pockets.")
	return [out[randi() % out.size()]]
