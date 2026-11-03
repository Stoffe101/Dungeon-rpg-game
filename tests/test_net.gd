## Co-op netcode pieces that can be checked inside one process: the client's
## prediction against the host's simulation, reconciliation, lag compensation
## for a remote Kindled's dodge, the bow's hold sync and the network simulator.
## (Real separate processes: tools/dev/coop_local.sh and netsim_matrix.sh.)
extends TestCase

var tree_root: Node


func setup_tree(n: Node) -> void:
	tree_root = n


func _dungeon(seed_v: int) -> Dungeon:
	var lay := DungeonGen.generate(seed_v, 1, "ossuary", false)
	var d := Dungeon.new()
	d.process_mode = Node.PROCESS_MODE_DISABLED
	tree_root.add_child(d)
	d.build(lay, RunState.create(seed_v, "ossuary", "sword", 0, ["flare", ""]), null)
	return d


## A predicting copy of the dungeon's Kindled on a second (identical) floor.
func _predictor(d: Dungeon) -> Player:
	var p := Player.new()
	p.peer_id = 2
	p.controller = Player.Ctrl.REPLICA
	p.replica = true
	p.predicting = true
	p.pos = d.player.pos
	d.add_actor(p)
	p.setup_from(RunState.create(7, "ossuary", "sword", 0, ["flare", ""]))
	return p


func test_prediction_follows_the_host_simulation() -> void:
	Profile.data = Profile.fresh()
	var host := _dungeon(7)
	var client := _dungeon(7)
	var real := host.player
	var pred := _predictor(client)
	pred.pos = real.pos
	check(pred.weapon.predicting, "the predicting Kindled's weapon only predicts")
	var dt := 1.0 / 60.0
	# walk, turn, swing while walking (the swing slows the walk), dodge, walk on
	var script := [[Vector2.RIGHT, ""], [Vector2.RIGHT, ""], [Vector2(1, 1).normalized(), "attack"], [Vector2.DOWN, ""],
		[Vector2.DOWN, "dodge"], [Vector2.LEFT, ""], [Vector2.LEFT, ""], [Vector2.UP, ""]]
	var worst := 0.0
	for step in script:
		for f in 12:
			real.move_in = step[0]
			pred.pred_move = step[0]
			real.aim = Vector2.RIGHT
			pred.aim = Vector2.RIGHT
			if f == 0 and String(step[1]) != "":
				real.press(step[1])
				pred.press(step[1])
			real.think(dt)
			real._move(dt)
			pred.replica_present(dt)
			worst = maxf(worst, real.pos.distance_to(pred.pos))
	check(worst < 0.02, "prediction tracks the host's movement (worst %.4f tiles)" % worst)
	check(pred.dodge_charges < pred.stats.v("dodge_charges"), "the predicted dodge spent a charge")
	check(real.alive and pred.alive, "nobody was hurt by a predicted swing")
	host.queue_free()
	client.queue_free()


func test_reconcile_moves_by_the_error_and_smooths_the_picture() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var p := _predictor(d)
	d.player = p
	var nr := NetRun.new()
	nr.stage = d
	# the record: input 5 sent at t=1.0 from here, walking right at 6 tiles/s
	var start := p.pos
	for k in 7:
		nr._traj.append([1.0 + k * 0.05, start + Vector2(0.3 * k, 0)])
	nr._seq_t[5] = 1.0
	p.pos = start + Vector2(1.8, 0)
	# the host had it 0.2 tiles further down after input 5 drove it for 100 ms
	var host_at := start + Vector2(0.6, 0.2)
	nr._reconcile([5, 100, host_at.x, host_at.y])
	check(p.pos.distance_to(start + Vector2(1.8, 0.2)) < 0.01, "the Kindled moved by the error (%s)" % str(p.pos - start))
	check(p.draw_off.distance_to(Vector2(0, -0.2)) < 0.01, "and the picture stays put, to catch up smoothly")
	check(not nr._seq_t.has(4), "older inputs are forgotten")
	# a big disagreement (a pull into a room) is a jump, not a slide
	nr._seq_t[6] = 1.05
	nr._reconcile([6, 0, start.x + 6.0, start.y + 0.2])
	eq(p.draw_off, Vector2.ZERO, "a jump is not smoothed")
	d.queue_free()
	nr.free()


func test_a_late_dodge_turns_a_waiting_blow() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var p := d.player
	p.controller = Player.Ctrl.REMOTE
	p.lag_grace = 0.15
	var e := d._make_enemy("husk")
	e.pos = p.pos + Vector2(1.0, 0)
	e.alive = false
	var hp0 := p.hp
	var h := Hit.make(e, 20.0, ["melee"])
	h.can_crit = false
	p.take_enemy_hit(h, e)
	eq(p.hp, hp0, "the blow waits for the owner's answer")
	# the owner's dodge arrives 80 ms later (they pressed it as the blow showed)
	p.press("dodge")
	p.think(0.08)
	eq(p.hp, hp0, "the late dodge turned it")
	eq(p.lag_saves, 1, "counted as saved by lag compensation")
	check(p.perfect_done, "and it was a perfect dodge, as it looked to its owner")
	# without an answer the blow lands once the grace runs out
	p.dodge_t = 0.0
	p.invuln_t = 0.0
	p.dodge_age = 9.0
	var h2 := Hit.make(e, 20.0, ["melee"])
	h2.can_crit = false
	p.take_enemy_hit(h2, e)
	eq(p.hp, hp0, "still waiting")
	for k in 12:
		d.elapsed += 1.0 / 60.0
		p.think(1.0 / 60.0)
	check(p.hp < hp0, "no dodge came: the blow lands")
	d.queue_free()


func test_bow_lines_up_the_owners_hold() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var p := d.player
	p.set_weapon("bow", 0)
	var w := p.weapon
	w.press()
	for k in 30:
		w.update(1.0 / 60.0)    # 0.5 s on the host's clock: not yet drawn
	check(not w.charged, "half a second is short of a full draw")
	w.sync_hold(0.62)            # the owner held a little longer (packets came unevenly)
	check(w.charged, "the owner's hold counts: drawn")
	w.sync_hold(2.0)
	check(w.hold_t < 0.62 + 0.16, "but never more than a small nudge at a time")
	d.queue_free()


func test_network_simulator_keeps_order_and_loses_packets() -> void:
	var n := Net.new()
	n.set_netsim("100:50:20")
	var got: Array = []
	for k in 200:
		n._through("u", false, func() -> void: got.append(k), float(k))
	var rel: Array = []
	for k in 50:
		n._through("r", true, func() -> void: rel.append(k), float(k))
	n._deliver(20.0)
	eq(got.size(), 0, "nothing arrives before half the round trip (less the jitter)")
	n._deliver(100000.0)
	check(got.size() > 60 and got.size() < 140, "about half the unreliable packets are lost (%d of 200)" % got.size())
	var ordered := true
	for k in range(1, got.size()):
		ordered = ordered and int(got[k]) > int(got[k - 1])
	check(ordered, "what arrives arrives in order")
	eq(rel.size(), 50, "every reliable message arrives")
	var rel_ordered := true
	for k in range(1, rel.size()):
		rel_ordered = rel_ordered and int(rel[k]) == int(rel[k - 1]) + 1
	check(rel_ordered, "reliable messages keep their order through resends")
	n.free()


func _two(d: Dungeon) -> Player:
	var p2 := Player.new()
	p2.peer_id = 2
	p2.controller = Player.Ctrl.REMOTE
	p2.pos = d.player.pos + Vector2(1.0, 0)
	d.add_actor(p2)
	p2.setup_from(RunState.create(7, "ossuary", "sword", 0, ["flare", ""]))
	return p2


func test_merchant_is_personal_and_sells_once() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var p1 := d.player
	var p2 := _two(d)
	var shop := Prop.make(d, "merchant", Vector2i(p1.pos) + Vector2i(2, 0))
	var s1 := Party.shop_stock(d, p1, shop)
	var s2 := Party.shop_stock(d, p2, shop)
	check(s1 != s2 or s1.size() == s2.size(), "each Kindled has a stock of their own")
	p1.run.embers = 500
	p2.run.embers = 30
	var heal_i := s2.size() - 1
	check(Party.buy(d, p2, shop, heal_i), "a guest buys broth with their own Embers")
	eq(p2.run.embers, 5, "paid from the buyer's purse")
	eq(p1.run.embers, 500, "and nobody else's")
	check(not Party.buy(d, p2, shop, heal_i), "sold is sold (a repeated request buys nothing)")
	check(not Party.buy(d, p2, shop, 0), "and nobody buys on credit")
	check(not bool(s1[heal_i].get("sold", false)), "the host's broth is still for sale")
	d.queue_free()


func test_bargains_are_one_each_and_picks_are_once() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var p1 := d.player
	var p2 := _two(d)
	var shrine := Prop.make(d, "shrine", Vector2i(p1.pos) + Vector2i(2, 0))
	var hp0 := p2.hp
	Party.shrine_choice(d, p2, shrine, "blood")
	check(p2.hp < hp0, "the blood pact takes the guest's health")
	var offer: Array = shrine.data.get("offer_2", [])
	check(not offer.is_empty(), "and offers them a relic of their own")
	check(Party.spent(shrine, p2) and not Party.spent(shrine, p1), "their bargain is spent, the host's is not")
	check(not shrine.used, "the shrine stays open for the others")
	var hp1 := p2.hp
	Party.shrine_choice(d, p2, shrine, "blood")
	eq(p2.hp, hp1, "a second pact is refused")
	var relics := p2.run.relics.size()
	d.coop_relic_pick(p2, shrine.net_idx, String(offer[0]))
	eq(p2.run.relics.size(), relics + 1, "the pick is granted to the guest")
	d.coop_relic_pick(p2, shrine.net_idx, String(offer[0]))
	eq(p2.run.relics.size(), relics + 1, "a repeated pick finds nothing")
	Party.shrine_choice(d, p1, shrine, "curse")
	check(shrine.used, "once everyone has bargained, the shrine is spent")
	d.queue_free()


func test_party_votes_need_everyone() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var p2 := _two(d)
	var had := Net.i
	var net := Net.new()
	Net.i = net
	net.roster = {1: {"name": "Host", "slot": 0}, 2: {"name": "Guest", "slot": 1}}
	var nr := NetRun.new()
	nr.stage = d
	nr.start_vote("test", 3, d.player)
	eq(nr._votes.size(), 1, "the host's ask opens a vote")
	nr.start_vote("test", 3, d.player)
	eq(nr._votes.size(), 1, "asking again is the same vote")
	nr.cast_vote(2, 1, true)
	eq(nr._votes.size(), 0, "everyone agreed: done")
	nr.start_vote("test", 4, p2)
	nr.cast_vote(1, 2, false)
	eq(nr._votes.size(), 0, "one 'not yet' ends it")
	nr.start_vote("test", 5, p2)
	nr.cast_vote(9, 3, true)
	eq(nr._votes.size(), 1, "a stranger's answer does not count")
	Net.i = had
	net.free()
	nr.free()
	d.queue_free()


func test_the_old_floor_does_not_stop_the_new_floors_recording() -> void:
	Profile.data = Profile.fresh()
	var had := Net.i
	var net := Net.new()
	Net.i = net
	var d1 := _dungeon(7)
	var d2 := _dungeon(8)
	var old := NetRun.new()
	d1.add_child(old)
	old.setup(d1, true)
	var new := NetRun.new()
	d2.add_child(new)
	new.setup(d2, true)
	check(Net.recording and net.run_sync == new, "the new floor records")
	d1.free()     # the old floor goes after the new one is up (as Game does it)
	check(Net.recording, "and keeps recording once the old floor is gone")
	Net.rec(["toast", "x", Color.WHITE])
	check(not new.events.is_empty(), "events reach the new floor's batch")
	d2.free()
	check(not Net.recording, "the last floor going stops it")
	Net.i = had
	net.free()


func test_a_settlement_banks_once_with_the_partys_deeds() -> void:
	Profile.data = Profile.fresh()
	var r := RunState.create(7, "ossuary", "sword", 0, ["flare", ""])
	r.run_id = "run-a"
	r.kill_counts = {"husk": 3, "archer": 1}
	r.elites_slain = 1
	r.bosses = ["warden"]
	Profile.data.grudges = [{"id": "g1", "enemy": "husk", "level": 1, "embers": 10, "depth": 1}]
	r.grudges_won = ["g1"]
	var back := RunState.from_dict(r.to_dict())
	eq(back.run_id, "run-a", "the run id crosses the wire")
	eq(back.kill_counts, r.kill_counts, "and the party's kills")
	check(Profile.first_settlement(back.run_id), "the first settlement banks")
	check(not Profile.first_settlement(back.run_id), "the same run id never banks twice")
	Profile.bank_shared(back)
	eq(int(Profile.data.stats.kills), 4, "kills counted")
	eq(int(Profile.data.stats.get("k_husk", 0)), 3, "per kind, for the bestiary")
	check((Profile.data.seen.enemies as Array).has("archer"), "the bestiary saw what the party fought")
	eq(int(Profile.data.world.get("warden_kills", 0)), 1, "a guardian felled with the party counts")
	check(Profile.active_grudges().is_empty(), "the guest's own Grudge is settled on their profile")


func test_guests_grudges_hunt_the_party_and_settle_for_their_owner() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var p2 := _two(d)
	p2.sheet = {"skills": ["hearth"], "grudges": [{"id": "gg", "enemy": "husk", "name": "Old Bones", "level": 1, "embers": 40, "depth": 1, "traits": []}]}
	var gs := d.party_grudges()
	eq(gs.size(), 1, "the guest's Grudge is among the party's")
	eq(int(gs[0].owner), 2, "with its owner")
	d._grudge = gs[0]
	var room: Room = null
	for r in d.layout.rooms:
		if r.is_combat() and r.id != d.layout.start_id:
			room = r
			break
	d._spawn_grudge(room)
	var foe: Enemy = null
	for a in d.actors:
		if a is Enemy and a.has_meta("grudge_id"):
			foe = a
	check(foe != null and foe.id == "husk", "it comes for the party")
	foe.hp = 0.0
	foe.die(d.player)
	check(p2.run.grudges_won.has("gg"), "settled in its owner's run")
	check(d.run.grudges_settled.size() == 1, "and the party saw it settled")
	d.queue_free()


func test_a_returning_guest_takes_its_seat_back() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var p2 := _two(d)
	var nr := NetRun.new()
	nr.stage = d
	var shop := Prop.make(d, "merchant", Vector2i(d.player.pos) + Vector2i(2, 0))
	Party.shop_stock(d, p2, shop)
	Party.spend(d, shop, p2)
	var gift := Pickup.spawn(d, "gear", p2.pos, 1, {"item": ItemDB.make_item("grave_iron_helm", "rare", 1, RandomNumberGenerator.new(), 1)})
	gift.owner_peer = 2
	nr.on_peer_away(2)
	check(p2.away and not p2.targetable, "a Kindled whose owner lost the link waits, untouchable")
	check(not d.active_players().has(p2), "foes look elsewhere")
	var h := Hit.make(null, 50.0, ["melee"])
	var hp0 := p2.hp
	p2.take_enemy_hit(h, null)
	eq(p2.hp, hp0, "nothing hurts it while it waits")
	nr.on_rejoin(2, 7)
	eq(p2.peer_id, 7, "the seat moves to the new link")
	check(not p2.away and p2.targetable, "and the Kindled is back in the fight")
	check(shop.data.has("stock_7") and shop.data.has("used_7") and not shop.data.has("stock_2"), "its stock and bargains follow it")
	eq(gift.owner_peer, 7, "so does its gear on the ground")
	nr.free()
	d.queue_free()


func test_the_host_leads_once_everyone_is_ready() -> void:
	var net := Net.new()
	net.roster = {1: {"name": "Host", "slot": 0}, 2: {"name": "A", "slot": 1, "ready": true}, 3: {"name": "B", "slot": 2, "ready": false}}
	check(not net.all_ready(), "B is not ready yet")
	net.roster[3]["ready"] = true
	check(net.all_ready(), "everyone is ready")
	net.roster[2]["away"] = true
	eq(net.present(), [1, 3], "an away seat is not counted as present")
	net.unready_all()
	check(not net.all_ready(), "a new descent asks again")
	net.free()


func test_without_godotsteam_the_game_offers_lan_play() -> void:
	if SteamLink.installed():
		return     # this build has GodotSteam: covered by docs/STEAM.md's manual checks
	var s := SteamLink.new()
	tree_root.add_child(s)
	check(not s.online, "no Steam without the extension")
	check(s.status.contains("LAN"), "and the player is told LAN and direct IP still work")
	s.join_lobby(123)     # asking anyway is harmless
	check(not s.online, "still offline, nothing broke")
	s.queue_free()
	check(not Net.identity().begins_with("steam:"), "identity falls back to the profile's")


func test_allies_particles_follow_their_own_setting() -> void:
	Profile.data = Profile.fresh()
	var d := _dungeon(7)
	var fx := d.fx
	fx.intensity = 1.0
	fx.ally = 0.25
	eq(fx._who_k(), 1.0, "your own and the world's effects at full strength")
	fx.ally_k = 0.25
	var n := 0
	for k in 200:
		n += fx._scaled(4)
	check(n > 120 and n < 280, "another Kindled's burst of 4 draws about 1 (%d over 200)" % n)
	fx.ally_k = 1.0
	d.queue_free()


func test_steam_invites_and_app_ids() -> void:
	eq(SteamLink.lobby_in(PackedStringArray(["--path", ".", "+connect_lobby", "109775241022380843"])), 109775241022380843, "a launch from an invite names the lobby")
	eq(SteamLink.lobby_in("+connect_lobby 42".split(" ", false)), 42, "so does a friend's Join game connect string")
	eq(SteamLink.lobby_in(PackedStringArray(["--path", "."])), 0, "no invite, no lobby")
	check(SteamLink.configured_app_id() != SteamLink.SPACEWAR or Dev.enabled(), "Spacewar only ever in a debug build")
	if SteamLink.installed():
		check(ClassDB.class_has_method("SteamMultiplayerPeer", "create_host") and ClassDB.class_has_method("SteamMultiplayerPeer", "create_client"), "the installed GodotSteam has the transport we use")
