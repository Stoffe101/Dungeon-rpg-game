## Dev: whole builds to test with (`-- build=<name>`, debug builds only), and
## the builds the party-scaling evaluation sends its bots down with
## (`src/dev/scaling_eval.gd`). A preset names the nodes it wants; the cheapest
## paths to them are filled in, and the Kindled is levelled until the points
## cover them.
class_name BuildPresets
extends RefCounted

const PRESETS := {
	"starter": {"desc": "A fresh Kindled: level 1, sword, Flare", "weapon": "sword", "level": 1,
		"nodes": [], "slots": ["flare", "", ""]},
	"knives": {"desc": "Gloam knife-caster: a fan of knives that ricochet", "weapon": "tome", "level": 12,
		"nodes": ["gk", "g_fan", "g_ric", "g4r"], "slots": ["knives", "flare", "gloamstep"]},
	"lantern": {"desc": "Hearth-keeper: lanterns, Hearthbond and Spellblade", "weapon": "sword", "level": 12,
		"nodes": ["k_lan", "k_lw", "k_hb", "k8", "k3"], "slots": ["lantern", "flare", "wisp"]},
	"rush": {"desc": "Ember duelist: Ember Rush, Momentum, Thousand Cuts", "weapon": "daggers", "level": 12,
		"nodes": ["b_rush", "b_mo", "b8", "b3"], "slots": ["rush", "flare", ""]},
	"hail": {"desc": "Pyre archer: splintering flame and Ember Hail", "weapon": "bow", "level": 12,
		"nodes": ["p3l", "p_fork", "p8", "p3"], "slots": ["cinder_lance", "flare", ""]},
	"bulwark": {"desc": "Last Light warden: Rekindle, Retribution, Last Light", "weapon": "hammer", "level": 12,
		"nodes": ["w_rk", "w_ret", "w8", "w3"], "slots": ["rekindle", "flare", ""]},
	"frost": {"desc": "Rime staff: returning frost", "weapon": "staff", "level": 12,
		"nodes": ["r3r", "r_ret", "r3"], "slots": ["frost_sigil", "flare", ""]},
	# builds of the combat-identity pass: a weapon form and the new spells
	"beam": {"desc": "Soulfire channeler: a steered beam, a cinder orb and the Grimoire of Ash's breath", "weapon": "tome", "item": "grimoire_of_ash", "level": 14,
		"nodes": ["p_beam", "k_orb", "p3"], "slots": ["beam", "orb", "flare"]},
	"wall": {"desc": "Glacial marksman: Rimewall, Frost Sigil and the Long Rimebow's ice spears", "weapon": "bow", "item": "long_rimebow", "level": 12,
		"nodes": ["r_wall", "r3r", "r3"], "slots": ["rimewall", "frost_sigil", "flare"]},
	"pyreblade": {"desc": "Hearthfire smith: Hearthfire Form, Ember Rush chains and the Emberforge Mallet's heat", "weapon": "hammer", "item": "emberforge_mallet", "level": 12,
		"nodes": ["b_form", "b_rush", "p3"], "slots": ["hearthfire", "rush", "flare"]},
	"shadow": {"desc": "Gloam cutter: lodged knives torn open by the Gloam Kris's marks", "weapon": "daggers", "item": "gloam_kris", "level": 12,
		"nodes": ["gk", "g_fan", "g4r"], "slots": ["knives", "gloamstep", "flare"]},
	# builds of the deepening pass: a technique made into a way of fighting
	"cadence": {"desc": "Swordsman in time: Cadence, Perfect Cadence, Riposte", "weapon": "sword", "level": 14,
		"nodes": ["s_cadence", "b3", "b_rush"], "slots": ["rush", "flare", ""]},
	"vanguard": {"desc": "Hammer of the line: Breaking Blow, Vanguard's Weight, Unbreakable", "weapon": "hammer", "level": 14,
		"nodes": ["s_vanguard", "w6", "w3"], "slots": ["aegis", "flare", ""]},
	"lanternedge": {"desc": "Lantern adept: The Lantern's Edge, Overcharge, Hearth Lantern", "weapon": "staff", "level": 14,
		"nodes": ["s_lantern", "t_overcharge", "k_lan"], "slots": ["lantern", "flare", ""]},
	"unblinking": {"desc": "Marksman: Steady Eye, Unblinking, Splintering Flame", "weapon": "bow", "level": 14,
		"nodes": ["s_unblinking", "p_fork", "p3l"], "slots": ["cinder_lance", "flare", ""]},
	"backstab": {"desc": "Knife in the dark: daggers, Ambush, Gloamstep, Phantom", "weapon": "daggers", "level": 14,
		"nodes": ["t_behind", "g5", "g4r"], "slots": ["gloamstep", "flare", ""]},
	"point": {"desc": "Spear at arm's length: The Point, Rimewall, Glacial Ward", "weapon": "spear", "level": 14,
		"nodes": ["t_point", "r_wall", "r5"], "slots": ["rimewall", "flare", ""]},
}


static func names() -> Array:
	return PRESETS.keys()


## The nodes a preset ends up with (paths included), from the root.
static func nodes_of(preset: String) -> Array:
	var have: Array = ["hearth"]
	for id in (PRESETS.get(preset, {}) as Dictionary).get("nodes", []):
		var path := SkillDB.path_to(String(id), have)
		have.append_array(path.get("nodes", []))
	return have


## Makes this profile the preset: level, Hearthtree, spells and weapon.
static func apply(preset: String) -> bool:
	if not PRESETS.has(preset):
		push_warning("build=%s: no such preset (%s)" % [preset, ", ".join(PRESETS.keys())])
		return false
	var p: Dictionary = PRESETS[preset]
	var tree := nodes_of(preset)
	var need := maxi(int(p.level), SkillDB.spent(tree) + 1)
	while Profile.level() < need:
		Profile.add_xp(Combat.xp_to_next(Profile.level()))
	Profile.data.skills = tree
	Profile.unlock_weapon(String(p.weapon))
	Profile.choose_weapon(String(p.weapon))
	if p.has("item"):
		# the weapon form the build is made around
		var it := Profile.add_item(ItemDB.make_item(String(p.item), "rare", 1, RandomNumberGenerator.new(), 1))
		Profile.equip(int(it.uid))
	Profile.data.equipped.slots = (p.slots as Array).duplicate()
	Profile._changed()
	print("[dev] build=%s: level %d, %d nodes, spells %s, %s" % [preset, Profile.level(), tree.size(), str(Profile.slots()), p.weapon])
	return true
