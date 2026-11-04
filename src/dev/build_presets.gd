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
	Profile.data.equipped.slots = (p.slots as Array).duplicate()
	Profile._changed()
	print("[dev] build=%s: level %d, %d nodes, spells %s, %s" % [preset, Profile.level(), tree.size(), str(Profile.slots()), p.weapon])
	return true
