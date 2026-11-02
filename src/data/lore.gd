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


const ROOTMIRE := [
	["The World-Tree", "Its crown held the sun. When the sun went out, the tree died from the top down. The roots never noticed."],
	["Mycologist's Warning", "The caps glow because they are eating something. Do not ask what. Do not stand still."],
	["Carved in Bark", "BURN THE BRAMBLES. THEY REMEMBER FIRE AND THEY FEAR IT."],
	["The Bloom", "It sprouted where the last seed of sunlight fell. It is very, very hungry for more."],
	["Moth Song", "Cover your lantern, they said. As if the dark were any kinder than the moths."],
	["A Rootweaver's Hymn", "Grow, grow, around the bones; grow, grow, through the stones; drink the light the stranger brings."],
]


static func random_ossuary(rng: RandomNumberGenerator) -> Array:
	return OSSUARY[rng.randi_range(0, OSSUARY.size() - 1)]


static func random_for(region: String, rng: RandomNumberGenerator) -> Array:
	var pool: Array = ROOTMIRE if region == "rootmire" else OSSUARY
	return pool[rng.randi_range(0, pool.size() - 1)]
