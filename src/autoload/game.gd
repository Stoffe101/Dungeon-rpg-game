## Game flow: main menu -> sanctuary -> expedition depths -> settlement -> sanctuary.
extends Node

signal stage_changed(stage: Stage)

var main: Control
var view: PixelView
var ui: UIRoot
var stage: Stage
var run: RunState
var debug_seed := -1
var transitioning := false
## Co-op host: every other Kindled's run, by peer id (this machine's is `run`).
var coop_runs := {}
var _playtime_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# co-op lives at /root/Net on every machine (RPCs need the same path)
	var n := Net.new()
	n.name = "Net"
	get_tree().root.add_child.call_deferred(n)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			debug_seed = int(a.substr(5))
	Profile.changed.connect(_check_feats, CONNECT_DEFERRED)


## Feats are granted the moment they are reached (forging, learning, building...).
func _check_feats() -> void:
	for id in Feats.check():
		var f: Dictionary = Feats.FEATS[id]
		Events.toast.emit("Feat: %s  -  %s" % [f.name, Feats.describe_reward(f.reward)], Color(1.0, 0.85, 0.45))
		Audio.play("skill_unlock", -2.0)


func _process(delta: float) -> void:
	if stage and not get_tree().paused:
		_playtime_t += delta
		if _playtime_t >= 10.0:
			Profile.data.playtime = float(Profile.data.get("playtime", 0.0)) + _playtime_t
			_playtime_t = 0.0


func attach(m: Control, v: PixelView, u: UIRoot) -> void:
	main = m
	view = v
	ui = u


func _clear_stage() -> void:
	if stage:
		stage.queue_free()
		stage = null
	view.clear_world()


func goto_menu() -> void:
	_clear_stage()
	run = null
	get_tree().paused = false
	var hub := Hub.new()
	hub.menu_mode = true
	view.world.add_child(hub)
	hub.build(view)
	stage = hub
	ui.show_main_menu()
	Audio.play_music("hearth")


func goto_hub() -> void:
	_clear_stage()
	run = null
	get_tree().paused = false
	var hub := Hub.new()
	view.world.add_child(hub)
	hub.build(view)
	stage = hub
	_check_feats()
	ui.show_hud(false)
	stage_changed.emit(stage)
	Audio.play_music("hearth")
	Audio.play_ambience("amb_hearth")
	if Profile.dirty:
		Profile.save_profile()


func start_run(region := "ossuary", seed_v := -1) -> void:
	if seed_v < 0:
		seed_v = debug_seed if debug_seed >= 0 else int(Time.get_unix_time_from_system()) % 1000000
	run = RunState.create(seed_v, region, Profile.equipped_weapon(), Profile.weapon_level(Profile.equipped_weapon()), Profile.slots())
	run.tier = Difficulty.selected()
	run.omens = (Profile.data.descent.get("omens", []) as Array).filter(func(o): return Omens.unlocked(String(o)))
	coop_runs.clear()
	if Net.is_host():
		# every other Kindled gets a run of their own (settled on their machine)
		for pid in Net.i.roster:
			if int(pid) != Net.my_id():
				var sh: Dictionary = Net.i.roster[pid].sheet
				var r := RunState.create(seed_v, region, String(sh.get("weapon", "sword")), int(sh.get("weapon_level", 0)), sh.get("slots", ["flare", ""]))
				r.tier = run.tier
				r.omens = run.omens.duplicate()
				coop_runs[int(pid)] = r
	Profile.data.descent.region = region
	Profile.stat_add("runs")
	Profile.save_profile()
	_enter_depth(1)


func _enter_depth(depth: int) -> void:
	run.depth = depth
	var region: Dictionary = EnemyDB.REGIONS[run.region]
	var boss_depth := depth >= int(region.depths)
	var lay := DungeonGen.generate(run.seed, depth, run.region, boss_depth)
	_clear_stage()
	var d := Dungeon.new()
	d.replica = Net.is_client()
	view.world.add_child(d)
	d.build(lay, run, view)
	if Net.active():
		var nr := NetRun.new()
		d.add_child(nr)
		nr.setup(d, Net.is_host())
	stage = d
	ui.show_hud(true)
	stage_changed.emit(stage)
	Profile.data.world.deepest = maxi(int(Profile.data.world.get("deepest", 0)), depth)
	print("[game] entered depth %d (seed %d): %d rooms" % [depth, run.seed, lay.rooms.size()])


func descend() -> void:
	if transitioning or run == null or run.result != "":
		return
	transitioning = true
	if Net.is_host():
		for pl in stage.players:
			if pl != stage.player and pl.run:
				pl.store_to(pl.run)
		Net.i.rpc("_descend", run.depth + 1)
	if stage and stage.player:
		stage.player.store_to(run)
		stage.player.input_enabled = false
		# the Kindled goes down into the dark
		var pl := stage.player
		var tw := pl.create_tween()
		pl.hide_gear()
		tw.tween_method(pl.sprite.set_dissolve, 0.0, 1.0, 0.45)
		stage.fx.motes(pl.pos, 0.2, Color(1.0, 0.75, 0.4), 10, 1.2, 0.8, 0.4)
		Audio.play("gate_flare", -10.0, 1.3)
	var reg: Dictionary = EnemyDB.REGIONS[run.region]
	var next := run.depth + 1
	var sub := "Depth %d" % next
	if next >= int(reg.depths):
		sub += "  -  %s waits below" % String(EnemyDB.get_def(String(reg.boss)).name)
	ui.title_card(String(reg.name), sub, func() -> void:
		transitioning = false
		if run != null and run.result == "":
			_enter_depth(run.depth + 1))


## From the Descent screen: the gate flares, the Kindled steps into the light,
## and a title card covers the walk down.
func begin_descent(region: String) -> void:
	if transitioning:
		return
	transitioning = true
	var wait := 0.0
	if stage is Hub:
		wait = (stage as Hub).flare_gate()
	var reg: Dictionary = EnemyDB.REGIONS[region]
	var omens := (Profile.data.descent.get("omens", []) as Array).filter(func(o): return Omens.unlocked(String(o)))
	var seed_v := debug_seed if debug_seed >= 0 else int(Time.get_unix_time_from_system()) % 1000000
	if Net.is_host():
		# the party goes down together: same seed, region, tier and Omens
		Net.i.rpc("_begin", {"seed": seed_v, "region": region, "tier": Difficulty.selected(), "omens": omens})
	get_tree().create_timer(wait, true).timeout.connect(func() -> void:
		ui.title_card(String(reg.name), "Depth 1", func() -> void:
			transitioning = false
			start_run(region, seed_v), ("Omens: " + Omens.names(omens)) if not omens.is_empty() else ""))


# --- co-op ----------------------------------------------------------------------------

## A Kindled's run on this machine: its own, or (host) a party member's.
func run_of(peer_id: int) -> RunState:
	if peer_id == Net.my_id() or not Net.active():
		return run
	if not coop_runs.has(peer_id):
		var sh: Dictionary = Net.i.roster.get(peer_id, {}).get("sheet", {})
		var r := RunState.create(run.seed, run.region, String(sh.get("weapon", "sword")), int(sh.get("weapon_level", 0)), sh.get("slots", ["flare", ""]))
		r.tier = run.tier
		r.omens = run.omens.duplicate()
		coop_runs[peer_id] = r
	return coop_runs[peer_id]


## Client: the host is taking the party down.
func begin_coop_client(params: Dictionary) -> void:
	ui.close_all()
	var reg: Dictionary = EnemyDB.REGIONS[String(params.region)]
	var wait := 0.0
	if stage is Hub:
		wait = (stage as Hub).flare_gate()
	var omens: Array = params.get("omens", [])
	get_tree().create_timer(wait, true).timeout.connect(func() -> void:
		ui.title_card(String(reg.name), "Depth 1  -  with %s" % Net.name_of(1), func() -> void:
			run = RunState.create(int(params.seed), String(params.region), Profile.equipped_weapon(), Profile.weapon_level(Profile.equipped_weapon()), Profile.slots())
			run.tier = int(params.tier)
			run.omens = omens.duplicate()
			Profile.stat_add("runs")
			_enter_depth(1), ("Omens: " + Omens.names(omens)) if not omens.is_empty() else ""))


func descend_client(depth: int) -> void:
	if run == null:
		return
	var reg: Dictionary = EnemyDB.REGIONS[run.region]
	var sub := "Depth %d" % depth
	if depth >= int(reg.depths):
		sub += "  -  %s waits below" % String(EnemyDB.get_def(String(reg.boss)).name)
	ui.title_card(String(reg.name), sub, func() -> void:
		if run != null:
			_enter_depth(depth))


## Client: the host settled the expedition; bank this Kindled's share here.
func end_coop_client(outcome: String, killer: String, data: Dictionary) -> void:
	if run == null:
		return
	var r := RunState.from_dict(data)
	r.result = ""
	run = r
	# memories were never banked live on this machine
	Profile.add_xp(r.xp_gained)
	end_run(outcome, killer)


## Client: the host vanished mid-expedition. Nothing comes home.
func abandon_coop_run() -> void:
	run = null
	ui.close_all()
	ui.title_card("The Sanctuary", "The party's fire went out", goto_hub)


func grant_relic_to(pl: Player, id: String) -> void:
	if pl == stage.player:
		grant_relic(id)
		return
	pl.run.add_relic(id)
	pl.rebuild_stats()
	var r := RelicDB.relic(id)
	if r.get("refill_flask", false):
		pl.flask = int(pl.stats.v("flask_charges"))
	stage.fx.motes(pl.pos, 0.6, RelicDB.RARITY_COLOR.get("cursed" if r.get("cursed", false) else r.rarity, Color.WHITE), 16, 1.5, 1.0, 0.5)


func grant_relic(id: String) -> void:
	if run == null:
		return
	run.add_relic(id)
	Profile.note_seen("relics", id)
	var r := RelicDB.relic(id)
	if stage and stage.player:
		stage.player.rebuild_stats()
		if r.get("refill_flask", false):
			stage.player.flask = int(stage.player.stats.v("flask_charges"))
		stage.fx.motes(stage.player.pos, 0.6, RelicDB.RARITY_COLOR.get("cursed" if r.get("cursed", false) else r.rarity, Color.WHITE), 16, 1.5, 1.0, 0.5)
	Audio.play("relic", 0.0)
	Events.relic_gained.emit(id)


## Ends the expedition and settles what the profile keeps.
func end_run(outcome: String, killer_id := "") -> void:
	if run == null or run.result != "":
		return
	if Net.is_host() and stage is Dungeon:
		# every other Kindled settles their own share on their own machine
		for pl in stage.players:
			if pl != stage.player and pl.run:
				pl.store_to(pl.run)
		for pid in coop_runs:
			var cr: RunState = coop_runs[pid]
			# what the party did together counts for everyone
			cr.depth = run.depth
			cr.elapsed = run.elapsed
			cr.kills = run.kills
			cr.rooms_cleared = run.rooms_cleared
			cr.elites_slain = run.elites_slain
			cr.grudges_settled = run.grudges_settled.duplicate()
			Net.i.rpc_id(int(pid), "_run_end", outcome, killer_id, cr.to_dict())
	run.result = outcome
	run.killer_id = killer_id
	var s := run.settle(outcome)
	# Omens pay on what is carried home, and on all the experience earned
	var omen_embers := int(round(int(s.embers_kept) * Omens.bonus(run.omens, "embers")))
	var omen_xp := int(round(run.xp_gained * Omens.bonus(run.omens, "xp")))
	s.embers_kept = int(s.embers_kept) + omen_embers
	if omen_xp > 0:
		Profile.add_xp(omen_xp)
	Profile.add_currency("embers", int(s.embers_kept))
	if int(s.sunshards) > 0:
		Profile.add_currency("sunshards", int(s.sunshards))
	# Grudges not settled this time grow in the dark (before a new one is made)
	var grew := Profile.age_grudges(run.rng)
	match outcome:
		"died":
			Profile.stat_add("deaths")
			if killer_id != "" and int(s.embers_lost) > 0:
				var g := Profile.record_grudge(killer_id, int(s.embers_lost), run.depth, run.rng)
				s["grudge"] = g
		"extracted":
			Profile.stat_add("extractions")
		"victory":
			Profile.stat_add("victories")
			Profile.data.world.memory = int(Profile.data.world.get("memory", 0)) + 1
			if not Profile.weapon_unlocked("staff"):
				Profile.unlock_weapon("staff")
				s["unlocked"] = "Ashwood Staff"
			var opened := Difficulty.on_victory(run.region, run.tier)
			if not opened.is_empty():
				s["tiers"] = opened
			var best := float(Profile.data.stats.get("best_time", 0.0))
			if best <= 0.0 or run.elapsed < best:
				Profile.data.stats.best_time = run.elapsed
	# bank the materials and gear carried out (half the materials on a death)
	var spoils := run.settle_loot(outcome)
	for k in spoils.materials:
		if int(spoils.materials[k]) > 0:
			Profile.add_material(k, int(spoils.materials[k]))
	for it in spoils.gear:
		Profile.add_item(it)
	for b in spoils.get("blueprints", []):
		if not Profile.scrolls().has(b) and not Profile.known_blueprints().has(b):
			Profile.scrolls().append(b)
	for r in spoils.get("runes", []):
		Profile.add_rune(String(r))
	var feats := Feats.check()
	Profile.save_profile()
	var summary := {
		"loot": spoils, "loot_found": run.loot.duplicate(true),
		"outcome": outcome, "depth": run.depth, "kills": run.kills, "rooms": run.rooms_cleared,
		"time": run.elapsed, "xp": run.xp_gained, "relics": run.relics.duplicate(),
		"embers_kept": s.embers_kept, "embers_lost": s.embers_lost, "bonus": s.bonus,
		"sunshards": s.sunshards, "grudge": s.get("grudge", {}), "settled": run.grudges_settled,
		"unlocked": s.get("unlocked", ""), "tier": run.tier, "tiers": s.get("tiers", []), "region": run.region,
		"feats": feats, "omens": run.omens.duplicate(), "omen_embers": omen_embers, "omen_xp": omen_xp, "grudges_grew": grew,
	}
	Events.run_ended.emit(summary)
	print("[game] run ended: ", JSON.stringify(summary))
	if ui:
		ui.show_summary(summary)
