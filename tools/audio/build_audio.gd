## Renders every sound effect, music loop and ambience bed.
## Usage: godot --headless --path . -s res://tools/audio/build_audio.gd [-- only=sfx|music|amb]
extends SceneTree

const Synth = preload("res://tools/audio/synth.gd")
const SFX := "res://assets/audio/sfx/"
const MUS := "res://assets/audio/music/"


func _init() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	var t := Time.get_ticks_msec()
	if only == "" or only == "sfx":
		_sfx()
		print("  sfx done %d ms" % (Time.get_ticks_msec() - t))
	if only == "" or only == "amb":
		_ambience()
		print("  ambience done %d ms" % (Time.get_ticks_msec() - t))
	if only == "" or only == "music":
		_music()
		print("  music done %d ms" % (Time.get_ticks_msec() - t))
	quit()


func fx(name: String, dur: float, build: Callable, seed_v := 1) -> void:
	var s := Synth.new(44100, dur, false, seed_v)
	build.call(s)
	s.save(SFX + name + ".wav", 0.85)


static func midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


func _sfx() -> void:
	# --- the Kindled ---
	fx("swing", 0.2, func(s): s.noise(0.0, 0.18, 0.7, 900.0, 3800.0, 350.0, 0.035, 3.0))
	fx("swing_heavy", 0.32, func(s):
		s.noise(0.0, 0.3, 0.8, 400.0, 1800.0, 120.0, 0.06, 2.5)
		s.tone(0.02, 0.25, 130.0, 70.0, "sine", 0.4, 0.03, 3.0))
	fx("whirl", 0.42, func(s): s.noise(0.0, 0.4, 0.8, 600.0, 2600.0, 250.0, 0.04, 1.5, 22.0))
	fx("hit", 0.14, func(s):
		s.tone(0.0, 0.1, 190.0, 60.0, "sine", 0.9, 0.001, 4.0)
		s.noise(0.0, 0.05, 0.6, 3500.0, 1200.0, 200.0, 0.001, 6.0))
	fx("crit", 0.32, func(s):
		s.tone(0.0, 0.12, 220.0, 60.0, "sine", 0.9, 0.001, 4.0)
		s.noise(0.0, 0.06, 0.7, 6000.0, 2000.0, 300.0, 0.001, 6.0)
		s.bell(0.0, 0.3, 1450.0, 0.25))
	fx("slam", 0.5, func(s):
		s.tone(0.0, 0.45, 95.0, 35.0, "sine", 1.0, 0.002, 3.5)
		s.noise(0.0, 0.4, 0.8, 1200.0, 150.0, 0.0, 0.002, 4.0))
	fx("leap", 0.35, func(s): s.noise(0.0, 0.32, 0.6, 400.0, 2800.0, 200.0, 0.08, 1.5))
	fx("hurt", 0.25, func(s):
		s.tone(0.0, 0.2, 320.0, 120.0, "square", 0.35, 0.002, 5.0, 0.0, 6.0, 1800.0)
		s.noise(0.0, 0.08, 0.5, 2500.0, 600.0))
	fx("dodge", 0.16, func(s): s.noise(0.0, 0.14, 0.5, 2400.0, 700.0, 500.0, 0.01, 3.0))
	fx("ward", 0.35, func(s):
		s.tone(0.0, 0.3, 880.0, 900.0, "sine", 0.35, 0.01, 4.0)
		s.tone(0.0, 0.3, 1320.0, 1340.0, "sine", 0.2, 0.01, 5.0))
	fx("parry", 0.7, func(s):
		s.bell(0.0, 0.65, 523.0, 0.45, [[1.0, 1.0, 4.0], [2.02, 0.6, 5.0], [2.98, 0.4, 7.0], [4.1, 0.3, 9.0]])
		s.noise(0.0, 0.04, 0.8, 8000.0, 3000.0, 1000.0, 0.001, 6.0))
	fx("perfect", 0.6, func(s):
		for k in 3:
			s.bell(k * 0.05, 0.5, [660.0, 990.0, 1320.0][k], 0.3))
	fx("flask", 0.6, func(s):
		for k in 3:
			s.tone(k * 0.09, 0.08, 300.0 + k * 40.0, 520.0 + k * 60.0, "sine", 0.4, 0.005, 3.0)
		s.bell(0.3, 0.3, 880.0, 0.2))
	fx("deny", 0.14, func(s): s.tone(0.0, 0.12, 110.0, 100.0, "square", 0.3, 0.002, 2.0, 0.0, 6.0, 900.0))
	fx("kindle_full", 0.5, func(s):
		s.bell(0.0, 0.4, 784.0, 0.2)
		s.bell(0.08, 0.4, 1175.0, 0.2))
	fx("charged", 0.25, func(s):
		s.tone(0.0, 0.2, 600.0, 950.0, "sine", 0.35, 0.01, 2.0)
		s.noise(0.0, 0.15, 0.2, 9000.0, 6000.0, 4000.0))
	fx("bolt", 0.14, func(s):
		s.tone(0.0, 0.1, 950.0, 380.0, "square", 0.25, 0.001, 4.0, 0.0, 6.0, 2500.0)
		s.noise(0.0, 0.08, 0.35, 4000.0, 1500.0, 600.0))
	fx("fireball", 0.5, func(s):
		s.noise(0.0, 0.45, 0.7, 400.0, 1400.0, 100.0, 0.03, 2.0)
		s.tone(0.0, 0.4, 200.0, 110.0, "saw", 0.25, 0.02, 2.5, 0.0, 6.0, 600.0))
	fx("explode", 0.8, func(s):
		s.noise(0.0, 0.75, 1.0, 2600.0, 120.0, 0.0, 0.001, 3.5)
		s.tone(0.0, 0.6, 85.0, 32.0, "sine", 1.0, 0.002, 3.0))
	fx("flare", 0.7, func(s):
		s.noise(0.0, 0.6, 0.9, 1400.0, 250.0, 0.0, 0.01, 2.8)
		s.tone(0.0, 0.5, 160.0, 55.0, "sine", 0.8, 0.002, 3.0)
		s.noise(0.05, 0.4, 0.3, 9000.0, 5000.0, 3000.0, 0.02, 3.0))
	fx("lance", 0.35, func(s):
		s.tone(0.0, 0.3, 1300.0, 300.0, "saw", 0.3, 0.002, 2.5, 0.0, 6.0, 3000.0)
		s.noise(0.0, 0.3, 0.4, 7000.0, 2000.0, 1500.0, 0.005, 2.5))
	fx("frost", 0.4, func(s):
		for k in 3:
			s.tone(k * 0.03, 0.3, [2000.0, 2600.0, 3150.0][k], [1900.0, 2500.0, 3000.0][k], "sine", 0.18, 0.002, 6.0)
		s.noise(0.0, 0.2, 0.3, 9000.0, 7000.0, 3000.0, 0.002, 5.0))
	fx("sigil", 0.7, func(s):
		var notes := [64, 68, 71, 76]
		for k in notes.size():
			s.bell(k * 0.06, 0.5, midi(notes[k]), 0.2))
	fx("blink", 0.3, func(s):
		s.tone(0.0, 0.18, 380.0, 1700.0, "sine", 0.35, 0.002, 2.0)
		s.noise(0.0, 0.25, 0.4, 800.0, 3000.0, 300.0, 0.15, 1.0))
	fx("shade", 0.5, func(s):
		s.tone(0.0, 0.4, 140.0, 50.0, "sine", 0.8, 0.002, 3.5)
		s.noise(0.0, 0.4, 0.5, 1500.0, 300.0, 100.0, 0.002, 3.0, 16.0))
	fx("aegis", 0.8, func(s): s.pad(0.0, 0.75, [523.0, 659.0, 784.0], 0.4, 3000.0, 0.15, 0.4))
	fx("wisp", 0.6, func(s):
		for k in 4:
			s.bell(k * 0.05, 0.4, midi(84 + [0, 4, 7, 12][k]), 0.14))
	fx("steam", 0.6, func(s): s.noise(0.0, 0.55, 0.6, 9000.0, 4000.0, 1500.0, 0.01, 2.5))
	fx("shatter", 0.6, func(s):
		for k in 8:
			s.tone(k * 0.025, 0.2, 2200.0 + k * 310.0, 2000.0 + k * 300.0, "sine", 0.12, 0.001, 6.0)
		s.noise(0.0, 0.3, 0.6, 10000.0, 3000.0, 2000.0, 0.001, 5.0))
	# --- enemies ---
	fx("enemy_die", 0.45, func(s):
		for k in 9:
			s.noise(k * 0.035 + s.rng.randf() * 0.02, 0.025, 0.6, 3500.0, 1500.0, 800.0, 0.001, 6.0)
		s.tone(0.0, 0.3, 160.0, 60.0, "sine", 0.4, 0.002, 4.0))
	fx("husk_windup", 0.5, func(s): s.tone(0.0, 0.45, 95.0, 70.0, "saw", 0.4, 0.06, 1.5, 0.03, 5.0, 500.0))
	fx("spikes", 0.25, func(s):
		s.noise(0.0, 0.06, 0.6, 9000.0, 4000.0, 2000.0, 0.001, 6.0)
		s.bell(0.0, 0.2, 1900.0, 0.15, [[1.0, 1.0, 9.0], [2.3, 0.5, 12.0]]))
	fx("claw", 0.16, func(s): s.noise(0.0, 0.14, 0.6, 3000.0, 1200.0, 600.0, 0.01, 4.0))
	fx("skitter", 0.3, func(s):
		for k in 7:
			s.noise(k * 0.04, 0.012, 0.6, 5000.0, 3000.0, 1500.0, 0.001, 5.0))
	# a soul-arrow loosed: a dull knock (no ringing string), the arrow tearing
	# the air, and a thin cold whistle riding it
	fx("bow", 0.32, func(s):
		s.tone(0.0, 0.07, 160.0, 90.0, "sine", 0.6, 0.001, 6.0)
		s.noise(0.005, 0.24, 0.75, 5200.0, 1200.0, 600.0, 0.012, 2.6)
		s.tone(0.01, 0.2, 1900.0, 1100.0, "sine", 0.12, 0.01, 3.5))
	# Hearthcall: the hearth's chord swelling from far away, crackle and bells
	# rising, then a rush of warm air carrying the Kindled home (or a fizzle)
	fx("hearthcall", 3.2, func(s):
		s.pad(0.0, 3.2, [midi(55), midi(62), midi(67), midi(71)], 0.2, 1800.0, 2.6, 0.4)
		s.tone(0.0, 3.1, 220.0, 660.0, "sine", 0.07, 2.6, 0.6)
		s.noise(0.0, 3.1, 0.22, 1500.0, 6000.0, 400.0, 2.4, 0.6, 30.0)
		for k in 6:
			s.bell(0.4 + k * 0.45, 1.2, midi(79 + [0, 2, 4, 7, 9, 12][k]), 0.05))
	fx("hearthcall_go", 1.6, func(s):
		s.noise(0.0, 0.9, 0.7, 800.0, 7000.0, 300.0, 0.05, 2.0)
		s.tone(0.0, 0.6, 196.0, 784.0, "sine", 0.3, 0.01, 2.0)
		for f in [67, 71, 74, 79]:
			s.bell(0.05, 1.5, midi(f), 0.12))
	fx("hearthcall_break", 0.5, func(s):
		s.noise(0.0, 0.45, 0.5, 3000.0, 300.0, 100.0, 0.005, 3.0, 25.0)
		s.tone(0.0, 0.35, 660.0, 180.0, "sine", 0.2, 0.005, 3.0))
	# the satchel: leather creak, the buckle's clink, the flap's swish (and back)
	fx("satchel_open", 0.45, func(s):
		s.noise(0.0, 0.16, 0.35, 700.0, 1200.0, 200.0, 0.02, 1.6, 26.0)
		s.bell(0.1, 0.18, 2650.0, 0.12, [[1.0, 1.0, 22.0], [2.7, 0.5, 30.0]])
		s.noise(0.2, 0.22, 0.45, 1800.0, 600.0, 250.0, 0.03, 2.5))
	fx("satchel_close", 0.35, func(s):
		s.noise(0.0, 0.1, 0.45, 600.0, 1600.0, 250.0, 0.01, 3.0)
		s.tone(0.08, 0.1, 120.0, 70.0, "sine", 0.5, 0.002, 6.0)
		s.bell(0.16, 0.15, 2400.0, 0.1, [[1.0, 1.0, 22.0], [2.7, 0.5, 30.0]]))
	# drawing the bow: a low creak of sinew under strain
	fx("bow_draw", 0.5, func(s):
		s.noise(0.0, 0.48, 0.35, 500.0, 1300.0, 150.0, 0.2, 1.2, 28.0)
		s.tone(0.0, 0.45, 70.0, 95.0, "tri", 0.12, 0.25, 1.0))
	# a lance of dead sunlight: a bright rushing hiss with a crackling edge
	fx("sunlance", 0.4, func(s):
		s.noise(0.0, 0.32, 0.7, 6000.0, 1500.0, 800.0, 0.01, 2.2)
		s.tone(0.0, 0.3, 880.0, 1320.0, "tri", 0.15, 0.01, 2.5, 0.01, 18.0)
		s.noise(0.0, 0.3, 0.25, 9000.0, 7000.0, 4000.0, 0.005, 3.0, 40.0))
	fx("clank", 0.35, func(s): s.bell(0.0, 0.3, 310.0, 0.5, [[1.0, 1.0, 7.0], [2.45, 0.6, 9.0], [3.84, 0.4, 11.0]]))
	fx("guard_roar", 0.6, func(s):
		s.tone(0.0, 0.55, 75.0, 55.0, "saw", 0.5, 0.05, 1.5, 0.04, 9.0, 700.0)
		s.noise(0.0, 0.5, 0.3, 900.0, 400.0, 100.0, 0.05, 2.0))
	fx("chant", 0.9, func(s):
		s.tone(0.0, 0.85, 220.0, 220.0, "sine", 0.3, 0.25, 1.5, 0.01, 5.0)
		s.tone(0.0, 0.85, 330.0, 329.0, "sine", 0.2, 0.3, 1.5, 0.012, 4.0)
		s.tone(0.0, 0.85, 261.6, 262.0, "tri", 0.1, 0.35, 1.8, 0.01, 6.0))
	fx("orb", 0.4, func(s): s.tone(0.0, 0.35, 520.0, 440.0, "sine", 0.35, 0.01, 3.0, 0.06, 14.0))
	fx("bloat", 0.5, func(s):
		s.tone(0.0, 0.45, 160.0, 70.0, "saw", 0.4, 0.02, 2.0, 0.08, 18.0, 500.0)
		s.noise(0.0, 0.4, 0.4, 600.0, 300.0, 0.0, 0.02, 2.0, 12.0))
	fx("boss_roar", 1.4, func(s):
		s.tone(0.0, 1.3, 62.0, 40.0, "saw", 0.6, 0.1, 1.2, 0.05, 7.0, 600.0)
		s.tone(0.0, 1.3, 93.0, 60.0, "saw", 0.4, 0.1, 1.2, 0.05, 6.0, 900.0)
		s.noise(0.0, 1.2, 0.5, 800.0, 300.0, 60.0, 0.1, 1.5, 9.0))
	fx("boss_windup", 0.6, func(s): s.tone(0.0, 0.55, 60.0, 130.0, "saw", 0.5, 0.05, 0.8, 0.0, 6.0, 700.0))
	fx("thrust", 0.2, func(s): s.noise(0.0, 0.18, 0.7, 4000.0, 1500.0, 600.0, 0.005, 4.0))
	fx("sweep", 0.5, func(s):
		s.noise(0.0, 0.45, 0.9, 500.0, 2500.0, 150.0, 0.05, 2.0)
		s.tone(0.0, 0.4, 120.0, 60.0, "sine", 0.4, 0.02, 3.0))
	fx("rush", 0.8, func(s):
		s.noise(0.0, 0.75, 0.8, 600.0, 2000.0, 100.0, 0.05, 1.5)
		s.tone(0.0, 0.7, 70.0, 45.0, "saw", 0.4, 0.05, 2.0, 0.0, 6.0, 400.0))
	fx("boss_hurt", 0.9, func(s): s.tone(0.0, 0.85, 110.0, 50.0, "saw", 0.6, 0.02, 2.0, 0.06, 8.0, 800.0))
	fx("boss_death", 3.0, func(s):
		s.tone(0.0, 2.8, 90.0, 25.0, "saw", 0.6, 0.05, 1.2, 0.05, 5.0, 500.0)
		s.noise(0.0, 2.8, 0.7, 2000.0, 80.0, 0.0, 0.01, 1.4)
		for k in 6:
			s.bell(0.3 + k * 0.25, 1.4, midi(76 - k * 3), 0.15))
	fx("spawn", 0.7, func(s):
		s.tone(0.0, 0.6, 200.0, 620.0, "sine", 0.3, 0.2, 1.5, 0.02, 7.0)
		s.noise(0.0, 0.6, 0.25, 6000.0, 3000.0, 2000.0, 0.2, 1.5))
	fx("gate_close", 0.6, func(s):
		s.tone(0.0, 0.5, 90.0, 180.0, "saw", 0.4, 0.05, 1.5, 0.0, 6.0, 600.0)
		s.bell(0.35, 0.25, 260.0, 0.3, [[1.0, 1.0, 9.0], [2.4, 0.5, 11.0]]))
	fx("gate_open", 0.7, func(s):
		s.tone(0.0, 0.5, 180.0, 90.0, "saw", 0.35, 0.03, 2.0, 0.0, 6.0, 600.0)
		s.bell(0.1, 0.5, 880.0, 0.15))
	fx("room_clear", 1.2, func(s):
		var notes := [57, 64, 69, 71, 76]
		for k in notes.size():
			s.bell(k * 0.08, 1.0, midi(notes[k]), 0.16))
	fx("relic", 1.0, func(s):
		var notes := [72, 76, 79, 84, 88]
		for k in notes.size():
			s.bell(k * 0.06, 0.8, midi(notes[k]), 0.14)
		s.pad(0.0, 0.9, [midi(60), midi(67)], 0.25, 2000.0, 0.1, 0.5))
	fx("chest", 0.7, func(s):
		s.tone(0.0, 0.3, 110.0, 150.0, "saw", 0.3, 0.02, 1.0, 0.05, 20.0, 700.0)
		s.bell(0.25, 0.4, 1046.0, 0.2))
	fx("urn", 0.4, func(s):
		s.noise(0.0, 0.3, 0.8, 6000.0, 1500.0, 800.0, 0.001, 5.0)
		for k in 4:
			s.tone(k * 0.03, 0.12, 1400.0 + k * 400.0, 1300.0 + k * 380.0, "sine", 0.15, 0.001, 8.0))
	fx("ignite", 0.6, func(s):
		s.noise(0.0, 0.5, 0.8, 600.0, 3000.0, 200.0, 0.02, 2.0)
		s.tone(0.0, 0.4, 180.0, 90.0, "sine", 0.4, 0.01, 3.0))
	fx("crumble", 0.9, func(s):
		for k in 10:
			s.noise(k * 0.07 + s.rng.randf() * 0.04, 0.12, 0.6, 1500.0, 400.0, 60.0, 0.002, 5.0)
		s.tone(0.0, 0.6, 80.0, 40.0, "sine", 0.6, 0.002, 3.0))
	# --- loot / ui ---
	fx("pickup_ember", 0.08, func(s): s.tone(0.0, 0.07, 1300.0, 1750.0, "sine", 0.4, 0.001, 4.0))
	fx("pickup_xp", 0.1, func(s): s.tone(0.0, 0.09, 880.0, 1100.0, "tri", 0.3, 0.002, 4.0))
	fx("pickup_heal", 0.25, func(s):
		s.tone(0.0, 0.1, 660.0, 700.0, "sine", 0.35, 0.002, 3.0)
		s.tone(0.08, 0.14, 990.0, 1040.0, "sine", 0.35, 0.002, 3.0))
	fx("pickup_sunshard", 0.9, func(s):
		for k in 4:
			s.bell(k * 0.07, 0.8, midi(79 + [0, 4, 7, 12][k]), 0.16))
	fx("squeak", 0.16, func(s):
		s.tone(0.0, 0.07, 900.0, 1500.0, "square", 0.25, 0.002, 3.0, 0.0, 6.0, 3000.0)
		s.tone(0.07, 0.08, 1400.0, 1000.0, "square", 0.2, 0.002, 4.0, 0.0, 6.0, 3000.0))
	fx("learn", 1.2, func(s):
		for k in 5:
			s.bell(k * 0.09, 1.0, midi(72 + [0, 4, 7, 11, 14][k]), 0.18)
		s.pad(0.0, 1.1, [midi(60), midi(67), midi(72)], 0.12, 1400.0, 0.05, 0.6))
	fx("heartbeat", 0.5, func(s):
		s.tone(0.0, 0.14, 70.0, 42.0, "sine", 0.8, 0.004, 5.0)
		s.tone(0.17, 0.16, 62.0, 38.0, "sine", 0.6, 0.004, 5.0))
	# footsteps: a heel thud under a short scuff; four stone variants, three soft moss ones
	for k in 4:
		fx("step_stone_%d" % k, 0.12, func(s):
			s.tone(0.0, 0.06, 150.0 - k * 12.0, 55.0, "sine", 0.55, 0.002, 7.0)
			s.noise(0.003, 0.07, 0.32, 4200.0 - k * 450.0, 1200.0, 500.0 + k * 60.0, 0.002, 7.5)
			s.noise(0.035 + k * 0.004, 0.035, 0.12, 2600.0, 1400.0, 900.0, 0.002, 6.0), 31 + k)
	for k in 3:
		fx("step_moss_%d" % k, 0.14, func(s):
			s.tone(0.0, 0.07, 105.0 - k * 9.0, 48.0, "sine", 0.45, 0.004, 6.0)
			s.noise(0.0, 0.1, 0.28, 1300.0 - k * 120.0, 380.0, 70.0, 0.006, 5.0), 47 + k)
	fx("player_death", 1.8, func(s):
		for k in 4:
			s.bell(k * 0.22, 1.2, midi(64 - k * 4), 0.2)
		s.tone(0.0, 1.6, 80.0, 30.0, "sine", 0.6, 0.01, 2.0)
		s.noise(0.0, 1.5, 0.3, 1200.0, 100.0, 0.0, 0.01, 2.0))
	fx("buy", 0.3, func(s):
		s.tone(0.0, 0.08, 1500.0, 1500.0, "square", 0.15, 0.001, 4.0, 0.0, 6.0, 4000.0)
		s.tone(0.07, 0.15, 2000.0, 2000.0, "square", 0.15, 0.001, 4.0, 0.0, 6.0, 4000.0))
	fx("pact", 1.0, func(s): s.pad(0.0, 0.95, [midi(38), midi(44), midi(49)], 0.5, 700.0, 0.05, 0.5))
	fx("forge", 0.8, func(s):
		s.bell(0.0, 0.7, 820.0, 0.4, [[1.0, 1.0, 5.0], [1.93, 0.6, 6.0], [2.9, 0.4, 8.0]])
		s.noise(0.0, 0.5, 0.3, 9000.0, 4000.0, 2000.0, 0.01, 3.0))
	fx("build", 1.0, func(s):
		for k in 3:
			s.tone(k * 0.18, 0.12, 180.0, 90.0, "sine", 0.6, 0.001, 4.0)
			s.noise(k * 0.18, 0.05, 0.4, 2500.0, 800.0)
		s.bell(0.6, 0.4, 880.0, 0.2))
	fx("hearth_feed", 1.2, func(s):
		s.noise(0.0, 0.8, 0.6, 500.0, 2000.0, 100.0, 0.1, 1.5)
		s.pad(0.1, 1.0, [midi(55), midi(59), midi(62)], 0.4, 1500.0, 0.2, 0.5))
	fx("respec", 0.6, func(s): s.noise(0.0, 0.55, 0.5, 3000.0, 300.0, 100.0, 0.4, 0.5))
	fx("skill_unlock", 0.8, func(s):
		var notes := [67, 71, 74, 79]
		for k in notes.size():
			s.bell(k * 0.05, 0.6, midi(notes[k]), 0.18)
		s.noise(0.0, 0.3, 0.2, 8000.0, 4000.0, 2500.0, 0.02, 3.0))
	fx("skill_refund", 0.4, func(s):
		for k in 3:
			s.tone(k * 0.06, 0.1, 900.0 - k * 200.0, 800.0 - k * 200.0, "tri", 0.25, 0.002, 4.0))
	fx("ui_click", 0.04, func(s): s.tone(0.0, 0.03, 1200.0, 900.0, "square", 0.18, 0.001, 6.0, 0.0, 6.0, 3000.0))
	fx("ui_hover", 0.03, func(s): s.tone(0.0, 0.02, 1800.0, 1700.0, "sine", 0.08, 0.001, 6.0))
	fx("ui_open", 0.2, func(s): s.noise(0.0, 0.18, 0.25, 800.0, 3000.0, 300.0, 0.05, 2.0))
	fx("ui_close", 0.2, func(s): s.noise(0.0, 0.18, 0.2, 3000.0, 800.0, 300.0, 0.01, 3.0))


func _ambience() -> void:
	var a := Synth.new(22050, 24.0, true, 11)
	# low cave rumble, gusts of air, water drips, a distant moan
	a.noise(0.0, 24.0, 0.5, 120.0, 120.0, 20.0, 1.0, 0.0)
	a.noise(0.0, 24.0, 0.18, 500.0, 500.0, 100.0, 2.0, 0.0, 0.08)
	for k in 26:
		var t := a.rng.randf_range(0.0, 23.5)
		var f := a.rng.randf_range(1100.0, 2100.0)
		a.tone(t, 0.12, f, f * 0.6, "sine", 0.12, 0.001, 9.0)
	for k in 3:
		var t2 := a.rng.randf_range(0.0, 20.0)
		a.tone(t2, 3.5, 110.0, 98.0, "sine", 0.06, 1.2, 1.0, 0.03, 0.7)
	a.save(MUS + "amb_crypt.wav", 0.5)
	var h := Synth.new(22050, 20.0, true, 12)
	h.noise(0.0, 20.0, 0.2, 400.0, 400.0, 60.0, 1.0, 0.0, 0.1)
	for k in 260:
		var t := h.rng.randf_range(0.0, 20.0)
		h.noise(t, 0.02, h.rng.randf_range(0.1, 0.5), 5000.0, 2000.0, 800.0, 0.001, 8.0)
	h.save(MUS + "amb_hearth.wav", 0.5)
	var rt := Synth.new(22050, 24.0, true, 13)
	rt.noise(0.0, 24.0, 0.35, 160.0, 160.0, 30.0, 1.0, 0.0)
	# insects: fast chirps in short bursts
	for k in 40:
		var t := rt.rng.randf_range(0.0, 23.5)
		var f := rt.rng.randf_range(3200.0, 4600.0)
		for c in 4:
			rt.tone(t + c * 0.045, 0.03, f, f * 1.02, "sine", 0.05, 0.002, 4.0)
	# slow drips and creaking roots
	for k in 18:
		var t2 := rt.rng.randf_range(0.0, 23.5)
		var f2 := rt.rng.randf_range(900.0, 1500.0)
		rt.tone(t2, 0.15, f2, f2 * 0.55, "sine", 0.1, 0.001, 8.0)
	for k in 4:
		var t3 := rt.rng.randf_range(0.0, 21.0)
		rt.tone(t3, 2.0, 70.0, 64.0, "saw", 0.05, 0.4, 1.5, 0.02, 3.0, 300.0)
	rt.save(MUS + "amb_root.wav", 0.5)


func _music() -> void:
	_crypt()
	_rootmire()
	_throne()
	_boss()
	_hearth()
	_victory()


## Exploration: slow, cold, D minor. A drone, shifting pads, a sparse plucked motif.
func _crypt() -> void:
	var bpm := 70.0
	var beat := 60.0 / bpm
	var bars := 8
	var L := bars * 4 * beat
	var s := Synth.new(22050, L, true, 21)
	var dr: float = roundf(midi(38) * L) / L
	s.tone(0.0, L, dr, dr, "sine", 0.22, 0.0001, 0.0)
	var dr5: float = roundf(midi(45) * L) / L
	s.tone(0.0, L, dr5, dr5, "sine", 0.1, 0.0001, 0.0)
	var chords := [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52]]
	for c in 4:
		var fr: Array = []
		for n in chords[c]:
			fr.append(midi(n))
		s.pad(c * 2 * 4 * beat, 2 * 4 * beat + 1.0, fr, 0.16, 700.0, 1.6, 1.6)
	var scale := [62, 65, 67, 69, 72, 74, 77]
	for b in bars * 4:
		if s.rng.randf() < 0.55:
			var n: int = scale[s.rng.randi_range(0, scale.size() - 1)]
			s.pluck(b * beat + (0.5 * beat if s.rng.randf() < 0.3 else 0.0), 2.4, midi(n), 0.32, 0.997, 0.45)
	for b in range(0, bars, 2):
		s.bell(b * 4 * beat + 2 * beat, 3.0, midi(86 if b % 4 == 0 else 81), 0.05)
	s.echo(beat * 0.75, 0.35, 1.0)
	s.save(MUS + "crypt.wav", 0.8)


## The Sunken Throne: a ruined court's processional. A harmonic minor, slow
## timpani, low brass-like pads, a tolling bell and a proud, broken fanfare.
func _throne() -> void:
	var bpm := 62.0
	var beat := 60.0 / bpm
	var bars := 8
	var L := bars * 4 * beat
	var s := Synth.new(22050, L, true, 71)
	var dr: float = roundf(midi(33) * L) / L
	s.tone(0.0, L, dr, dr, "sine", 0.2, 0.0001, 0.0)
	var chords := [[45, 48, 52], [41, 45, 48], [44, 47, 50], [45, 48, 52]]
	for c in 4:
		var fr: Array = []
		for n in chords[c]:
			fr.append(midi(n))
		s.pad(c * 2 * 4 * beat, 2 * 4 * beat + 1.0, fr, 0.15, 900.0, 1.2, 1.4)
	for b in bars:
		s.kick(b * 4 * beat, 0.55)
		s.kick(b * 4 * beat + 3.5 * beat, 0.3)
		if b % 2 == 1:
			s.bell(b * 4 * beat + 2 * beat, 4.0, midi(69), 0.05)
	var fan := [69, 72, 76, 75, 76, 72, 71, 68]
	for k in fan.size():
		var t := 4 * 4 * beat + k * 2 * beat
		s.tone(t, 1.8 * beat, midi(fan[k]), midi(fan[k]), "saw", 0.06, 0.06, 1.4, 0.004, 4.5, 1500.0)
	s.echo(beat * 0.75, 0.4, 1.0)
	s.save(MUS + "throne.wav", 0.8)


## Boss: driving phrygian riff, drums, choir stabs.
func _boss() -> void:
	var bpm := 132.0
	var beat := 60.0 / bpm
	var bars := 16
	var L := bars * 4 * beat
	var s := Synth.new(22050, L, true, 31)
	for b in bars * 4:
		var t := b * beat
		if b % 4 == 0 or b % 4 == 2 or (b % 8 == 7):
			s.kick(t, 0.7)
		if b % 4 == 1 or b % 4 == 3:
			s.snare(t, 0.32)
		s.hat(t + beat * 0.5, 0.12)
	var riff := [40, 40, 41, 40, 43, 40, 41, 38]
	for k in bars * 8:
		var n: int = riff[k % riff.size()]
		if (k / 32) % 2 == 1:
			n += 0 if k % 8 < 6 else -2
		s.tone(k * beat * 0.5, beat * 0.45, midi(n), midi(n), "saw", 0.28, 0.005, 3.0, 0.0, 6.0, 420.0)
	var ch := [[52, 55, 59], [48, 52, 55], [45, 48, 52], [47, 51, 54]]
	for c in bars / 2:
		var fr: Array = []
		for n in ch[c % 4]:
			fr.append(midi(n + 12))
		s.pad(c * 8 * beat, 8 * beat, fr, 0.1, 1400.0, 0.05, 0.4)
	var lead := [76, 77, 76, 74, 72, 71, 72, 74, 76, 79, 77, 76, 74, 72, 71, 69]
	for k in lead.size():
		var t2 := (bars / 2) * 4 * beat + k * 2 * beat
		s.tone(t2, 1.8 * beat, midi(lead[k]), midi(lead[k]), "square", 0.09, 0.02, 1.2, 0.006, 5.5, 2200.0)
	s.save(MUS + "boss.wav", 0.85)


## Sanctuary: warm harp arpeggios in G, a soft pad, a gentle flute line.
func _hearth() -> void:
	var bpm := 84.0
	var beat := 60.0 / bpm
	var bars := 16
	var L := bars * 4 * beat
	var s := Synth.new(22050, L, true, 41)
	var prog := [[55, 59, 62, 67], [52, 55, 59, 64], [48, 52, 55, 60], [50, 54, 57, 62]]
	for bar in bars:
		var c: Array = prog[(bar / 2) % 4]
		for k in 8:
			var n: int = c[[0, 1, 2, 3, 2, 1, 2, 3][k]]
			s.pluck(bar * 4 * beat + k * beat * 0.5, 2.0, midi(n + 12), 0.22, 0.996, 0.5)
		if bar % 2 == 0:
			var fr: Array = []
			for n in c:
				fr.append(midi(n))
			s.pad(bar * 4 * beat, 8 * beat + 0.5, fr, 0.07, 900.0, 1.0, 1.0)
	var mel := [74, 76, 79, 78, 76, 74, 71, 74, 76, 74, 72, 71, 69, 71, 74, 74]
	for k in mel.size():
		s.tone(8 * 4 * beat + k * 2 * beat, 1.9 * beat, midi(mel[k]), midi(mel[k]), "sine", 0.08, 0.08, 1.5, 0.008, 5.0)
	s.echo(beat * 0.5, 0.3, 1.0)
	s.save(MUS + "hearth.wav", 0.75)


## Victory: a slow, bright hymn.
func _victory() -> void:
	var bpm := 72.0
	var beat := 60.0 / bpm
	var L := 8 * 4 * beat
	var s := Synth.new(22050, L, true, 51)
	var prog := [[60, 64, 67], [65, 69, 72], [67, 71, 74], [60, 64, 67]]
	for c in 4:
		var fr: Array = []
		for n in prog[c]:
			fr.append(midi(n))
		s.pad(c * 8 * beat, 8 * beat + 0.8, fr, 0.15, 1600.0, 0.8, 0.8)
		for k in 4:
			s.bell(c * 8 * beat + k * 2 * beat, 2.5, midi(prog[c][k % 3] + 24), 0.06)
	s.save(MUS + "victory.wav", 0.75)


## Rootmire: humid and alive. E dorian, woody marimba plucks, breathing pads.
func _rootmire() -> void:
	var bpm := 76.0
	var beat := 60.0 / bpm
	var bars := 8
	var L := bars * 4 * beat
	var s := Synth.new(22050, L, true, 61)
	var dr: float = roundf(midi(40) * L) / L
	s.tone(0.0, L, dr, dr, "sine", 0.18, 0.0001, 0.0)
	var chords := [[52, 55, 59, 62], [50, 54, 57, 61], [48, 52, 55, 59], [50, 54, 57, 62]]
	for c in 4:
		var fr: Array = []
		for n in chords[c]:
			fr.append(midi(n))
		s.pad(c * 2 * 4 * beat, 2 * 4 * beat + 0.8, fr, 0.12, 1100.0, 1.2, 1.2)
	# marimba-like ostinato (wooden bell partials)
	var pattern := [64, 67, 71, 69, 67, 64, 62, 64]
	for b in bars * 8:
		if b % 8 in [0, 3, 5] or s.rng.randf() < 0.25:
			var n: int = pattern[b % pattern.size()] + (12 if (b / 16) % 2 == 1 and b % 8 == 0 else 0)
			s.bell(b * beat * 0.5, 0.9, midi(n), 0.12, [[1.0, 1.0, 7.0], [3.99, 0.3, 12.0], [9.2, 0.08, 18.0]])
	# breathy gusts
	for b in range(0, bars, 2):
		s.noise(b * 4 * beat, 3.0, 0.08, 900.0, 600.0, 200.0, 1.2, 1.0)
	s.echo(beat * 0.75, 0.3, 1.0)
	s.save(MUS + "rootmire.wav", 0.8)
