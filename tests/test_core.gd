## Damage resolution, stats, status effects and run settlement.
extends TestCase


func test_resolve_basic() -> void:
	var h := Hit.make(null, 20.0, ["melee"])
	h.can_crit = false
	var r := Combat.resolve(h, StatusSet.new(), 0.0, 1.0, 0.0)
	eq(r.amount, 20.0)
	check(not r.crit, "no crit when can_crit is false")


func test_resolve_crit_and_armor() -> void:
	var h := Hit.make(null, 20.0, ["melee"])
	h.crit_chance = 0.5
	h.crit_mult = 2.0
	var r := Combat.resolve(h, null, 0.25, 1.0, 0.1)
	check(r.crit, "roll below chance crits")
	eq(r.amount, 30.0, "20 * 2 * 0.75")
	var r2 := Combat.resolve(h, null, 0.25, 1.0, 0.9)
	check(not r2.crit, "roll above chance does not crit")
	# armor is capped
	var r3 := Combat.resolve(Hit.make(null, 100.0, []), null, 5.0, 1.0, 0.99)
	eq(r3.amount, 25.0, "armor caps at 75%")


func test_resolve_min_damage_and_block() -> void:
	var h := Hit.make(null, 0.2, [])
	h.can_crit = false
	eq(Combat.resolve(h, null, 0.0, 1.0, 0.5).amount, 1.0, "positive damage rounds up to at least 1")
	var b := Combat.resolve(Hit.make(null, 40.0, []), null, 0.0, 1.0, 0.99, false, 0.25)
	check(b.blocked, "block flag")
	eq(b.amount, 10.0)


func test_status_multipliers() -> void:
	var s := StatusSet.new()
	s.frozen_t = 1.0
	near(s.damage_taken_mult(false), 1.5, 0.001)
	near(s.damage_taken_mult(true), 2.0, 0.001, "shatter doubles the frozen bonus")
	s.frozen_t = 0.0
	s.stagger_t = 1.0
	s.exposed_t = 1.0
	near(s.damage_taken_mult(), 1.55, 0.001)


func test_burn_ticks_and_expires() -> void:
	var s := StatusSet.new()
	s.apply_burn(2, 3.0, 3)
	var dmg := 0.0
	for i in 40:
		dmg += s.tick(0.1)
	# 2 stacks * 3 dps * 3s
	near(dmg, 18.0, 0.01)
	check(not s.burning(), "burn expires")
	s.apply_burn(10, 3.0, 3)
	eq(s.burn_stacks, 3, "stacks are capped")


func test_chill_freezes_then_immunity() -> void:
	var s := StatusSet.new()
	check(not s.apply_chill(0.5), "half chill does not freeze")
	near(s.speed_mult(), 0.75, 0.001)
	check(s.apply_chill(0.6), "reaching 1.0 freezes")
	check(s.is_frozen(), "frozen")
	eq(s.speed_mult(), 0.0)
	for i in 20:
		s.tick(0.1)
	check(not s.is_frozen(), "thaws")
	check(not s.apply_chill(1.0), "brief immunity after thawing")


func test_stats_formula() -> void:
	var st := Stats.for_player()
	st.add_mod("max_hp", "add", 20.0)
	st.add_mod("max_hp", "inc", 0.5)
	st.add_mod("max_hp", "more", 0.1)
	near(st.v("max_hp"), (100.0 + 20.0) * 1.5 * 1.1, 0.001)
	st.add_mod("fire_damage", "add", 0.2)
	st.add_mod("damage", "add", 0.1)
	near(st.damage_mult(["fire"]), 1.3, 0.001)
	near(st.damage_mult(["melee"]), 1.1, 0.001)
	st.add_flag("riposte")
	check(st.has("riposte"), "flag")
	st.clear_mods()
	check(not st.has("riposte"), "flags cleared")
	near(st.v("max_hp"), 100.0, 0.001)


func test_living_pyre_adds_fire_tag() -> void:
	var st := Stats.for_player()
	st.add_flag("living_pyre")
	var h := Combat.player_hit(null, st, 10.0, ["melee"])
	check(h.has_tag("fire"), "Living Pyre makes every hit fire")


func test_xp_curve_increases() -> void:
	var prev := 0
	for l in range(1, 40):
		var n := Combat.xp_to_next(l)
		check(n > prev, "xp requirement grows at level %d" % l)
		prev = n


func test_run_settlement() -> void:
	var r := RunState.new()
	r.embers = 101
	r.sunshards = 2
	var died := r.settle("died")
	eq(died.embers_kept, 50)
	eq(died.embers_lost, 51)
	eq(died.sunshards, 2, "sunshards are never lost")
	var ext := r.settle("extracted")
	eq(ext.embers_kept, 101)
	var win := r.settle("victory")
	eq(win.embers_kept, 101 + 25)
