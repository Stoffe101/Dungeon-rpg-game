## Weapons as loot: weapon items are variants of an archetype, the forge's
## levels still apply, finds lean to the finder's arm, saves migrate.
extends TestCase


func test_weapon_bases_are_whole() -> void:
	var icons: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/items.json")).icons
	var per_arch := {}
	for id in ItemDB.BASES:
		var b: Dictionary = ItemDB.BASES[id]
		if b.get("slot", "") != "weapon":
			continue
		var arch := String(b.get("arch", ""))
		check(GearDB.WEAPONS.has(arch), "%s fights as a real archetype (%s)" % [id, arch])
		check(icons.has(String(b.icon)), "%s has an item icon (%s)" % [id, b.icon])
		per_arch[arch] = int(per_arch.get(arch, 0)) + 1
	for arch in GearDB.WEAPONS:
		check(int(per_arch.get(arch, 0)) >= 4, "%s has its plain form, variants and a unique (%d)" % [arch, int(per_arch.get(arch, 0))])
		check(not ItemDB.weapon_bases(arch).is_empty(), "%s weapons can drop" % arch)
	for region in ItemDB.BOSS_WEAPONS:
		var w := String(ItemDB.BOSS_WEAPONS[region])
		check(ItemDB.base(w).get("legendary", false), "%s's boss weapon %s is legendary" % [region, w])


func test_equipping_a_weapon_item() -> void:
	Profile.data = Profile.fresh()
	eq(Profile.equipped_weapon(), "sword", "a fresh Kindled holds the sword")
	check(not Profile.weapon_unlocked("bow"), "the bow is not yet learned")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var it := Profile.add_item(ItemDB.make_item("splitwood_bow", "rare", 1, rng, 1))
	check(Profile.equip(int(it.uid)), "a found bow can be wielded")
	eq(Profile.equipped_weapon(), "bow", "wielding it takes up its archetype")
	check(Profile.weapon_unlocked("bow"), "and teaches it")
	# its stats are the Kindled's: one more arrow with every shot
	var st := Stats.for_player()
	Profile.apply_gear(st)
	eq(int(round(st.v("projectiles"))), 1, "Splitwood Bow: +1 projectile")
	check(st.v("weapon_damage") < 1.0, "and its arrows are lighter (%.2f)" % st.v("weapon_damage"))
	# taking up another archetype at the forge puts the bow back in the bag
	Profile.choose_weapon("sword")
	eq(Profile.equipped_weapon(), "sword", "back to the sword")
	check(Profile.weapon_item().is_empty(), "the bow is off")
	check(Profile.bag().any(func(x): return int(x.uid) == int(it.uid)), "and in the bag")


func test_weapon_might_and_forge_together() -> void:
	Profile.data = Profile.fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var it := Profile.add_item(ItemDB.make_item("gravecleaver", "common", 1, rng, 1))
	Profile.equip(int(it.uid))
	var pl := Player.new()
	pl.input_enabled = false
	pl.stats = Stats.for_player()
	Profile.apply_gear(pl.stats)
	var w := Weapon.new()
	w.player = pl
	w.level = 0
	near(w.damage_scale(), 1.14, 0.001, "a Gravecleaver hits 14% harder")
	w.level = 5
	near(w.damage_scale(), (1.0 + 5 * GearDB.FORGE_DAMAGE_PER_LEVEL) * 1.14, 0.001, "and the forge's +5 still counts")
	pl.free()


func test_whole_number_stats_stay_whole() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var it := ItemDB.make_item("long_rimebow", "common", 5, rng, 6)
	var pierce := 0.0
	for m in ItemDB.mods_of(it):
		if m[0] == "pierce":
			pierce += float(m[2])
	near(pierce, 1.0, 0.0001, "pierce +1 stays +1 at level 5, Tier VI")
	# a rolled +1 chain too
	it.affixes = [["chain", "add", 1.0]]
	var chain := 0.0
	for m in ItemDB.mods_of(it):
		if m[0] == "chain":
			chain += float(m[2])
	near(chain, 1.0, 0.0001, "a chain affix stays whole")
	# weapons roll from the weapon pool: ranged ones may roll pierce/chain, melee ones never do
	var seen_ranged := false
	for i in 200:
		var bow := ItemDB.make_item("hearthbow", "epic", 1, rng, 1)
		var sword := ItemDB.make_item("hearthblade", "epic", 1, rng, 1)
		for a in bow.affixes:
			if a[0] in ["pierce", "chain"]:
				seen_ranged = true
		for a in sword.affixes:
			check(not a[0] in ["pierce", "chain"], "a sword never rolls %s" % a[0])
	check(seen_ranged, "bows can roll pierce or chain")


func test_weapon_drops_lean_to_the_finders_arm() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var weapons := 0
	var bows := 0
	var n := 3000
	for i in n:
		var it := ItemDB.random_drop("ossuary", 2, rng, 0.0, 1, "bow")
		if ItemDB.arch_of(it) != "":
			weapons += 1
			if ItemDB.arch_of(it) == "bow":
				bows += 1
	var share := float(weapons) / n
	check(share > 0.11 and share < 0.21, "about one find in six is a weapon (%.2f)" % share)
	check(float(bows) / maxf(1.0, weapons) > 0.45, "half or more of them are bows for a bow-wielder (%d of %d)" % [bows, weapons])


func test_old_save_gains_the_third_slot() -> void:
	var old := Profile.fresh()
	old["version"] = 10
	old.equipped["slots"] = ["flare", "wisp"]
	var m := Profile.migrate(old)
	eq(int(m.version), Profile.VERSION, "migrated to the current version")
	eq((m.equipped.slots as Array).size(), 3, "three spell slots")
	eq(String(m.equipped.slots[1]), "wisp", "the spells kept")
	check(not (m.inventory.equipped as Dictionary).has("weapon"), "no weapon item appears from nowhere")
