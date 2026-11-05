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
	for a in Dev.args():
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
	Profile.visiting = {}     # (a visited camp's facilities stay in that camp)
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
	if Net.i:
		Net.i.set_where("menu")


func goto_hub(at := Vector2(-1, -1)) -> void:
	_clear_stage()
	run = null
	get_tree().paused = false
	var hub := Hub.new()
	view.world.add_child(hub)
	hub.build(view, at)
	stage = hub
	if Net.i:
		Net.i.set_where("hub")
	_check_feats()
	ui.show_hud(false)
	stage_changed.emit(stage)
	if "showcol" in Dev.args():
		ColView.attach(hub)
	Audio.play_music("hearth")
	Audio.play_ambience("amb_hearth")
	if Profile.dirty:
		Profile.save_profile()


## The sanctuary again, as it now should look (a guest who joined or left a
## party walks the host's camp, or their own), the Kindled where it stood.
func reload_hub() -> void:
	if not (stage is Hub) or (stage as Hub).menu_mode or transitioning:
		return
	var at: Vector2 = stage.player.pos if stage.player else Vector2(-1, -1)
	transitioning = true
	ui.fade(func() -> void:
		transitioning = false
		goto_hub(at), 0.3)


## A new expedition's settlement id (co-op guests bank it once).
static func new_run_id() -> String:
	return "%d-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec() % 1000000, randi() % 100000]


func start_run(region := "ossuary", seed_v := -1, run_id := "", tier := -1, omens: Variant = null) -> void:
	if seed_v < 0:
		seed_v = debug_seed if debug_seed >= 0 else int(Time.get_unix_time_from_system()) % 1000000
	run = RunState.create(seed_v, region, Profile.equipped_weapon(), Profile.weapon_level(Profile.equipped_weapon()), Profile.slots())
	run.run_id = run_id if run_id != "" else new_run_id()
	run.tier = Difficulty.selected() if tier < 1 else tier
	if omens is Array:
		run.omens = (omens as Array).duplicate()     # the party's agreed expedition
	else:
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
				r.run_id = run.run_id
				coop_runs[int(pid)] = r
	Profile.data.descent.region = region
	Profile.stat_add("runs")
	Profile.save_profile()
	_enter_depth(1)


func _enter_depth(depth: int) -> void:
	run.depth = depth
	# the XP ledger (Ledger): where this Kindled stood, and each floor
	if depth == 1 or Ledger._run != run.run_id:
		Ledger.begin(run.run_id, String(Settings.get_value("player_name", "Kindled")))
	Ledger.note("floor", {"xp_gained": run.xp_gained, "embers": run.embers})
	Ledger.flush()
	if run.delve:
		# the Hollow Below: the region turns every three depths, a guardian's
		# Echo every third, and each new depth reads another Omen
		run.region = Delve.region_for(depth)
		if depth > 1 and not Net.is_client():
			var om := Delve.next_omen(run.rng, run.omens)
			if om != "":
				run.omens.append(om)
				for cr in coop_runs.values():
					(cr as RunState).omens.append(om)
				get_tree().create_timer(3.2, true).timeout.connect(func() -> void:
					Events.banner.emit("The Deep Stirs", "A new Omen: %s" % Omens.get_def(om).name))
	var region: Dictionary = EnemyDB.REGIONS[run.region]
	var boss_depth := Delve.is_boss_depth(depth) if run.delve else depth >= int(region.depths)
	DungeonGen.force_landmark = "landmark" in Dev.args()
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
	if "showcol" in Dev.args():
		ColView.attach(d)
	Profile.data.world.deepest = maxi(int(Profile.data.world.get("deepest", 0)), depth)
	if Net.i:
		Net.i.set_where("below")
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
	var next := run.depth + 1
	var reg_id: String = Delve.region_for(next) if run.delve else run.region
	var reg: Dictionary = EnemyDB.REGIONS[reg_id]
	var words := Delve.depth_title(reg_id, next, run.delve)
	ui.title_card(Delve.NAME if run.delve else String(reg.name), words[0], func() -> void:
		transitioning = false
		if run != null and run.result == "":
			_enter_depth(run.depth + 1), words[1])


## From the Descent screen (or, in a party, once everyone agreed to the
## expedition - see Expedition): the gate flares, the Kindled steps into the
## light, and a title card covers the walk down. `tier` and `omens` are the
## party's agreed ones (otherwise this profile's choice).
func begin_descent(region: String, tier := -1, omens: Variant = null) -> void:
	if transitioning:
		return
	transitioning = true
	var wait := 0.0
	if stage is Hub:
		wait = (stage as Hub).flare_gate()
	var reg: Dictionary = {"name": Delve.NAME} if region == "delve" else EnemyDB.REGIONS[region]
	var oms: Array = (omens as Array).duplicate() if omens is Array else (Profile.data.descent.get("omens", []) as Array).filter(func(o): return Omens.unlocked(String(o)))
	var t := tier if tier >= 1 else Difficulty.selected()
	var seed_v := debug_seed if debug_seed >= 0 else int(Time.get_unix_time_from_system()) % 1000000
	var rid := new_run_id()
	var sub := String(Delve.depth_title(Delve.region_for(1) if region == "delve" else region, 1, region == "delve")[0])
	if Net.is_host():
		Net.i.proposal = {}
		Net.i.expedition += 1
		# the party goes down together: same seed, region, tier and Omens
		Net.i.rpc("_begin", {"seed": seed_v, "region": region, "tier": t, "omens": oms, "run_id": rid, "exp": Net.i.expedition})
		if Net.party_size() > 1:
			sub += "  -  with %s" % party_names()
	get_tree().create_timer(wait, true).timeout.connect(func() -> void:
		ui.title_card(String(reg.name), sub, func() -> void:
			transitioning = false
			start_run(region, seed_v, rid, t, oms), ("Omens: " + Omens.names(oms)) if not oms.is_empty() else ""))


## Everyone else in the party, by name ("Ash and Wren").
func party_names() -> String:
	var names: Array = []
	var seats: Array = Net.i.roster.keys()
	seats.sort_custom(func(a, b): return int(Net.i.roster[a].slot) < int(Net.i.roster[b].slot))
	for pid in seats:
		if int(pid) != Net.my_id():
			names.append(Net.name_of(int(pid)))
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return ", ".join(PackedStringArray(names.slice(0, names.size() - 1))) + " and " + String(names.back())


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
		r.run_id = run.run_id
		coop_runs[peer_id] = r
	return coop_runs[peer_id]


## Client: the host is taking the party down.
func begin_coop_client(params: Dictionary) -> void:
	ui.close_all()
	Net.i._early.clear()     # a new expedition: nothing from an old one carries over
	Net.i.expedition = int(params.get("exp", Net.i.expedition + 1))
	var reg: Dictionary = {"name": Delve.NAME} if String(params.region) == "delve" else EnemyDB.REGIONS[String(params.region)]
	var wait := 0.0
	if stage is Hub:
		wait = (stage as Hub).flare_gate()
	var omens: Array = params.get("omens", [])
	var first := String(Delve.depth_title(Delve.region_for(1) if String(params.region) == "delve" else String(params.region), 1, String(params.region) == "delve")[0])
	get_tree().create_timer(wait, true).timeout.connect(func() -> void:
		ui.title_card(String(reg.name), first + "  -  with %s" % party_names(), func() -> void:
			run = RunState.create(int(params.seed), String(params.region), Profile.equipped_weapon(), Profile.weapon_level(Profile.equipped_weapon()), Profile.slots())
			run.run_id = String(params.get("run_id", ""))
			run.tier = int(params.tier)
			run.omens = omens.duplicate()
			Profile.stat_add("runs")
			_enter_depth(1), ("Omens: " + Omens.names(omens)) if not omens.is_empty() else ""))


func descend_client(depth: int) -> void:
	if run == null:
		return
	var reg_id: String = Delve.region_for(depth) if run.delve else run.region
	var reg: Dictionary = EnemyDB.REGIONS[reg_id]
	var words := Delve.depth_title(reg_id, depth, run.delve)
	ui.title_card(Delve.NAME if run.delve else String(reg.name), words[0], func() -> void:
		if run != null:
			_enter_depth(depth), words[1])


## Client: the host settled the expedition; bank this Kindled's share here
## (once: a run id already banked is ignored).
func end_coop_client(outcome: String, killer: String, data: Dictionary) -> void:
	if run == null:
		return
	var r := RunState.from_dict(data)
	if not Profile.first_settlement(r.run_id):
		print("[game] settlement %s already banked" % r.run_id)
		return
	r.result = ""
	run = r
	coop_checkpoint = {}
	# kills, guardians and Grudges were never banked live on this machine;
	# experience was, as it came (Profile.live_xp): only the rest is added
	Profile.add_xp(Profile.xp_still_owed(r.run_id, r.xp_gained), "settle")
	Profile.bank_shared(r)
	end_run(outcome, killer)


## Client: what this Kindled carried at the start of the current depth (the
## host sends it as each floor begins), in case the host's fire goes out.
var coop_checkpoint := {}


## Client: the link to the host dropped mid-expedition. The floor stays (frozen)
## while Net reaches for the host again; giving up banks the checkpoint.
func coop_link_lost() -> void:
	if stage and stage.player:
		stage.player.input_enabled = false
	ui.close_all()
	ui.open(Screens.link_lost(ui), false)


## Client: back in the party after losing the link: rebuild the depth the party
## is on, as this Kindled's run stands on the host.
func rejoin_coop_client(params: Dictionary, data: Dictionary) -> void:
	ui.close_all()
	var r := RunState.from_dict(data)
	r.result = ""
	run = r
	Net.i.expedition = int(params.get("exp", Net.i.expedition))
	Events.toast.emit("Back with the party.", Color(0.75, 0.95, 0.9))
	print("[game] rejoined the party at depth %d (run %s, %d Embers carried)" % [int(params.depth), r.run_id, r.embers])
	_enter_depth(int(params.depth))


## Client: the host vanished mid-expedition. What this Kindled carried at the
## start of the depth comes home with it (as from a Hearthcall); the rest of
## the depth is lost.
func abandon_coop_run() -> void:
	ui.close_all()
	if run != null and not coop_checkpoint.is_empty():
		var r := RunState.from_dict(coop_checkpoint)
		coop_checkpoint = {}
		if Profile.first_settlement(r.run_id):
			r.result = ""
			run = r
			Profile.add_xp(Profile.xp_still_owed(r.run_id, r.xp_gained), "checkpoint")
			Profile.bank_shared(r)
			print("[game] the host is gone: banking the checkpoint from depth %d" % r.depth)
			end_run("extracted")
			Events.toast.emit("The host's fire went out. What you carried into this depth came home with you.", Color(1.0, 0.75, 0.5))
			return
	run = null
	ui.title_card("The Sanctuary", "The party's fire went out", goto_hub)


func grant_relic_to(pl: Player, id: String) -> void:
	if stage and pl == stage.player:
		grant_relic(id)
		return
	pl.run.add_relic(id)
	pl.rebuild_stats()
	var r := RelicDB.relic(id)
	if r.get("refill_flask", false):
		pl.flask = int(pl.stats.v("flask_charges"))
	pl.stage.fx.motes(pl.pos, 0.6, RelicDB.RARITY_COLOR.get("cursed" if r.get("cursed", false) else r.rarity, Color.WHITE), 16, 1.5, 1.0, 0.5)


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


## What the party did together counts for everyone.
func _shared_into(cr: RunState) -> RunState:
	cr.depth = run.depth
	cr.elapsed = run.elapsed
	cr.kills = run.kills
	cr.rooms_cleared = run.rooms_cleared
	cr.elites_slain = run.elites_slain
	cr.grudges_settled = run.grudges_settled.duplicate()
	return cr


## Host: the checkpoints sent as the current floor began, by player identity.
var checkpoints := {}


## Host: each guest's run as it stands, sent as a floor begins (their checkpoint
## if the host's fire goes out).
func send_checkpoints() -> void:
	if not Net.is_host() or run == null or not (stage is Dungeon):
		return
	for pl in stage.players:
		if pl != stage.player and pl.run:
			pl.store_to(pl.run)
	checkpoints.clear()
	for pid in coop_runs:
		var cp := _shared_into(coop_runs[pid]).to_dict()
		# kept by identity: a guest who drops and comes back gets it again
		checkpoints[String(Net.i.roster.get(pid, {}).get("id", str(pid)))] = cp
		if Net.i.present().has(pid):
			Net.i.rpc_id(int(pid), "_checkpoint", cp)


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
			var cr: RunState = _shared_into(coop_runs[pid])
			# each Kindled's own end: the foe that felled *them* takes their Embers
			var own_killer := ""
			if outcome == "died":
				for pl in stage.players:
					if pl.peer_id == int(pid):
						own_killer = pl.last_attacker_id
			if Net.i.present().has(pid):
				# finds still on their way first (banked once by drop id)
				if Net.i.run_sync:
					Net.i.run_sync.resend_gifts(int(pid))
				Net.i.rpc_id(int(pid), "_run_end", outcome, own_killer, cr.to_dict())
	run.result = outcome
	run.killer_id = killer_id
	Profile.data["last_run"] = run.run_id     # (the Satchel marks this run's finds)
	var delve_best := Delve.best()
	if run.delve:
		Profile.data.world["delve_best"] = maxi(delve_best, run.depth)
	var s := run.settle(outcome)
	# Omens pay on what is carried home, and on all the experience earned
	var omen_embers := int(round(int(s.embers_kept) * Omens.bonus(run.omens, "embers")))
	var omen_xp := int(round(run.xp_gained * Omens.bonus(run.omens, "xp")))
	s.embers_kept = int(s.embers_kept) + omen_embers
	if omen_xp > 0:
		Profile.add_xp(omen_xp, "omens")
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
	Ledger.note("settled", {"xp_gained": run.xp_gained, "omen_xp": omen_xp, "embers_kept": int(s.embers_kept)})
	Ledger.finish(outcome)
	Profile.save_profile()
	var summary := {
		"loot": spoils, "loot_found": run.found_summary(),
		"outcome": outcome, "depth": run.depth, "kills": run.kills, "rooms": run.rooms_cleared,
		"time": run.elapsed, "xp": run.xp_gained, "relics": run.relics.duplicate(),
		"embers_kept": s.embers_kept, "embers_lost": s.embers_lost, "bonus": s.bonus,
		"sunshards": s.sunshards, "grudge": s.get("grudge", {}), "settled": run.grudges_settled,
		"unlocked": s.get("unlocked", ""), "tier": run.tier, "tiers": s.get("tiers", []), "region": run.region,
		"feats": feats, "omens": run.omens.duplicate(), "omen_embers": omen_embers, "omen_xp": omen_xp, "grudges_grew": grew,
		"delve": run.delve, "delve_best": delve_best,
	}
	Events.run_ended.emit(summary)
	print("[game] run ended: ", JSON.stringify(summary))
	if ui:
		ui.show_summary(summary)
	if Net.i:
		Net.i.set_where("summary")
