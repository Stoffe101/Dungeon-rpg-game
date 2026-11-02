## Game flow: main menu -> sanctuary -> expedition depths -> settlement -> sanctuary.
extends Node

signal stage_changed(stage: Stage)

var main: Control
var view: PixelView
var ui: UIRoot
var stage: Stage
var run: RunState
var debug_seed := -1
var _playtime_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			debug_seed = int(a.substr(5))


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
	ui.show_hud(false)
	stage_changed.emit(stage)
	Audio.play_music("hearth")
	Audio.play_ambience("amb_hearth")
	if Profile.dirty:
		Profile.save_profile()


func start_run(region := "ossuary") -> void:
	var seed_v := debug_seed if debug_seed >= 0 else int(Time.get_unix_time_from_system()) % 1000000
	run = RunState.create(seed_v, region, Profile.equipped_weapon(), Profile.weapon_level(Profile.equipped_weapon()), Profile.slots())
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
	view.world.add_child(d)
	d.build(lay, run, view)
	stage = d
	ui.show_hud(true)
	stage_changed.emit(stage)
	Profile.data.world.deepest = maxi(int(Profile.data.world.get("deepest", 0)), depth)
	print("[game] entered depth %d (seed %d): %d rooms" % [depth, run.seed, lay.rooms.size()])


func descend() -> void:
	if stage and stage.player:
		stage.player.store_to(run)
	ui.fade(func() -> void:
		_enter_depth(run.depth + 1))


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
	run.result = outcome
	run.killer_id = killer_id
	var s := run.settle(outcome)
	Profile.add_currency("embers", int(s.embers_kept))
	if int(s.sunshards) > 0:
		Profile.add_currency("sunshards", int(s.sunshards))
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
			var best := float(Profile.data.stats.get("best_time", 0.0))
			if best <= 0.0 or run.elapsed < best:
				Profile.data.stats.best_time = run.elapsed
	Profile.save_profile()
	var summary := {
		"outcome": outcome, "depth": run.depth, "kills": run.kills, "rooms": run.rooms_cleared,
		"time": run.elapsed, "xp": run.xp_gained, "relics": run.relics.duplicate(),
		"embers_kept": s.embers_kept, "embers_lost": s.embers_lost, "bonus": s.bonus,
		"sunshards": s.sunshards, "grudge": s.get("grudge", {}), "settled": run.grudges_settled,
		"unlocked": s.get("unlocked", ""),
	}
	Events.run_ended.emit(summary)
	print("[game] run ended: ", JSON.stringify(summary))
	ui.show_summary(summary)
