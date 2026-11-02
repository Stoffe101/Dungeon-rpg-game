## Short fragments of world lore found on lorestones and spoken by residents.
class_name Lore
extends RefCounted

const OSSUARY := [
	["The Day the Sun Went Out", "We did not see it die. We only noticed, one morning, that morning had not come."],
	["Hearthkeeper's Note", "Carry the flame down and bring the embers back. The Hearth grows on what you return. So do you."],
	["Scratched into Bone", "IT REMEMBERS. IT REMEMBERS WHO HURT IT. IT SENDS THEM BACK."],
	["The Hollow Choir", "The priests sang to keep the dead asleep. Then the singing changed key."],
	["Warden's Oath", "No flame shall pass the lightless heart. No flame. Not even mine."],
	["A Lost Kindled", "If you find this, my lantern went out on the second stair. Tell the Hearth I tried."],
	["On Embers", "Every ember is a sliver of the old sun. Gather enough, and maybe it remembers how to rise."],
	["Ossuary Ledger", "Interred: 11,402. Risen: 11,402. Ledger closed by order of the Warden."],
]


static func random_ossuary(rng: RandomNumberGenerator) -> Array:
	return OSSUARY[rng.randi_range(0, OSSUARY.size() - 1)]
