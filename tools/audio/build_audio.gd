## Renders every sound effect, music loop and ambience bed.
## Usage: godot --headless --path . -s res://tools/audio/build_audio.gd [-- only=sfx|music|amb]
## (`sounds=a,b` with only=sfx: render just those, leaving the rest as they are.)
extends SceneTree

const Synth = preload("res://tools/audio/synth.gd")
const SFX := "res://assets/audio/sfx/"
const MUS := "res://assets/audio/music/"

var just: PackedStringArray = []


func _init() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
		elif a.begins_with("sounds="):
			just = a.substr(7).split(",")
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
	if not just.is_empty() and not just.has(name):
		return
	var s := Synth.new(44100, dur, false, seed_v)
	build.call(s)
	s.save(SFX + name + ".wav", 0.85)


## A vessel breaking: a thump of its body, a crack, shards scattering (most
## of them at once, a few late ones skittering), a breath of dust. Clay rings
## bright, a root-bound jar cracks dull and woody, a gilded one rings metal.
static func _shatter(s, mat: String) -> void:
	var rng: RandomNumberGenerator = s.rng
	match mat:
		"root":
			s.tone(0.0, 0.08, 190.0, 90.0, "sine", 0.3, 0.001, 6.0)
			s.noise(0.0, 0.08, 0.8, 4200.0, 1400.0, 450.0, 0.001, 5.0)
			s.tone(0.004, 0.06, 680.0, 500.0, "square", 0.2, 0.0005, 8.0, 0.0, 6.0, 2400.0)
			s.noise(0.03, 0.05, 0.35, 3000.0, 1500.0, 600.0, 0.001, 6.0)
		"gilded":
			s.tone(0.0, 0.08, 230.0, 90.0, "sine", 0.32, 0.001, 6.0)
			s.noise(0.0, 0.045, 0.9, 10000.0, 4000.0, 1500.0, 0.0005, 7.0)
			s.bell(0.0, 0.55, 1760.0 * rng.randf_range(0.95, 1.05), 0.1, [[1.0, 1.0, 4.0], [2.41, 0.6, 6.0], [3.93, 0.4, 9.0], [5.2, 0.25, 13.0]])
		_:
			s.tone(0.0, 0.09, 200.0, 80.0, "sine", 0.32, 0.001, 6.0)
			s.noise(0.0, 0.05, 0.9, 9000.0, 3500.0, 1200.0, 0.0005, 7.0)
	var n: int = {"root": 8, "gilded": 14}.get(mat, 18)
	var lo: float = {"root": 900.0, "gilded": 3000.0}.get(mat, 2400.0)
	var hi: float = {"root": 2200.0, "gilded": 7500.0}.get(mat, 6200.0)
	for k in n:
		var t: float = 0.015 + pow(rng.randf(), 1.6) * 0.42
		var f: float = rng.randf_range(lo, hi)
		var a: float = rng.randf_range(0.14, 0.3) * (1.0 - t * 1.3)
		s.tone(t, rng.randf_range(0.05, 0.12), f, f * 0.97, "sine", maxf(0.02, a), 0.0005, 9.0)
		s.noise(t, 0.012, maxf(0.05, a * 2.0), 9000.0, 6000.0, 3000.0, 0.0003, 9.0)
	s.noise(0.04, 0.35, 0.12, 2500.0, 800.0, 200.0, 0.02, 2.0)


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
	# impacts by what lands (Player._impact_sound), two takes each: a blade's
	# slice, a hammer's crunch, a point punching in, an arrow's thunk, a spell's pop
	for take in 2:
		var sfx2 := "" if take == 0 else "_2"
		var j: float = [1.0, 1.07][take]
		fx("hit_slash" + sfx2, 0.18, func(s):
			s.noise(0.0, 0.06, 0.6, 7000.0 * j, 2500.0, 1500.0, 0.001, 5.0)
			s.tone(0.0, 0.08, 200.0 * j, 85.0, "sine", 0.7, 0.001, 5.0)
			s.bell(0.0, 0.1, 1850.0 * j, 0.06, [[1.0, 1.0, 10.0]]), 61 + take)
		fx("hit_blunt" + sfx2, 0.26, func(s):
			s.tone(0.0, 0.12, 190.0 * j, 70.0, "sine", 0.55, 0.001, 4.0)
			s.noise(0.0, 0.12, 0.9, 2400.0 * j, 500.0, 180.0, 0.001, 4.0)
			s.tone(0.0, 0.05, 520.0 * j, 300.0, "square", 0.12, 0.0005, 7.0, 0.0, 6.0, 1500.0)
			s.noise(0.0, 0.025, 0.45, 5000.0, 2500.0, 1200.0, 0.0005, 8.0), 71 + take)
		fx("hit_pierce" + sfx2, 0.18, func(s):
			s.tone(0.0, 0.07, 240.0 * j, 110.0, "sine", 0.75, 0.001, 5.0)
			s.noise(0.0, 0.04, 0.55, 3200.0 * j, 2000.0, 1300.0, 0.0005, 7.0)
			s.noise(0.02, 0.07, 0.25, 900.0, 500.0, 200.0, 0.002, 4.0, 40.0), 81 + take)
		fx("hit_arrow" + sfx2, 0.18, func(s):
			s.tone(0.0, 0.06, 640.0 * j, 420.0, "square", 0.25, 0.0005, 6.0, 0.0, 6.0, 1800.0)
			s.tone(0.0, 0.08, 170.0 * j, 80.0, "sine", 0.6, 0.001, 5.0)
			s.noise(0.0, 0.02, 0.35, 4000.0, 2000.0, 900.0, 0.0005, 8.0), 91 + take)
		fx("hit_magic" + sfx2, 0.22, func(s):
			s.tone(0.0, 0.12, 900.0 * j, 280.0, "sine", 0.4, 0.001, 4.0)
			s.tone(0.0, 0.08, 160.0, 80.0, "sine", 0.5, 0.001, 5.0)
			s.noise(0.0, 0.08, 0.3, 9000.0, 6000.0, 3500.0, 0.001, 5.0), 101 + take)
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
	# Gloam Knives: a fan of thin blades cut from shadow - quick airy whips
	# with a faint glassy ring, light enough to repeat every half second
	fx("knives", 0.28, func(s):
		for k in 3:
			s.noise(k * 0.03, 0.09, 0.32, 9000.0, 3500.0, 2500.0, 0.002, 4.0)
			s.tone(k * 0.03, 0.12, 1700.0 + k * 260.0, 900.0 + k * 140.0, "sine", 0.12, 0.002, 5.0)
		s.bell(0.0, 0.22, 1568.0, 0.06, [[1.0, 1.0, 9.0], [2.4, 0.4, 12.0]]))
	# Hearth Lantern: a stake driven into stone, then the lantern catching
	fx("lantern", 0.9, func(s):
		s.tone(0.0, 0.12, 140.0, 70.0, "sine", 0.7, 0.001, 5.0)
		s.noise(0.0, 0.08, 0.5, 2500.0, 800.0, 200.0, 0.001, 6.0)
		s.noise(0.12, 0.6, 0.35, 1200.0, 2600.0, 200.0, 0.08, 2.0)
		s.bell(0.18, 0.6, 659.0, 0.12)
		s.bell(0.26, 0.6, 988.0, 0.1))
	# Ember Rush: a roar of flame that streaks past
	fx("ember_rush", 0.5, func(s):
		s.noise(0.0, 0.42, 0.85, 900.0, 4200.0, 200.0, 0.02, 2.4)
		s.tone(0.0, 0.3, 220.0, 520.0, "saw", 0.22, 0.01, 2.5, 0.0, 6.0, 1600.0)
		s.tone(0.02, 0.25, 90.0, 60.0, "sine", 0.5, 0.002, 3.0))
	# Rekindle: a warm swell of hearth-light and a rising chord
	fx("rekindle", 1.2, func(s):
		s.pad(0.0, 1.1, [392.0, 494.0, 587.0, 784.0], 0.3, 2400.0, 0.12, 0.6)
		for k in 3:
			s.bell(0.12 + k * 0.08, 0.6, midi(72 + [0, 4, 7][k]), 0.12)
		s.noise(0.0, 0.6, 0.18, 1500.0, 4500.0, 300.0, 0.15, 2.0))
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
	# a guardian comes: the stone groans and something swells under it (1.6 s),
	# then it is here - a blow on the floor, a burst, a ringing that hangs
	fx("boss_rise", 1.8, func(s):
		s.tone(0.0, 1.7, 65.0, 130.0, "saw", 0.18, 1.2, 0.6, 0.02, 3.0, 600.0)
		s.noise(0.0, 1.7, 0.4, 400.0, 3200.0, 200.0, 1.3, 0.5, 7.0)
		s.tone(0.3, 1.4, midi(62), midi(63), "sine", 0.1, 1.0, 0.6, 0.01, 5.0)
		s.tone(0.3, 1.4, midi(68), midi(69), "sine", 0.08, 1.0, 0.6, 0.01, 4.0)
		for k in 5:
			s.noise(0.2 + k * 0.3, 0.08, 0.25, 1800.0, 600.0, 200.0, 0.002, 6.0))
	fx("boss_arrive", 2.2, func(s):
		s.tone(0.0, 0.3, 140.0, 48.0, "sine", 0.4, 0.001, 3.0)
		s.noise(0.0, 0.35, 0.8, 5000.0, 600.0, 200.0, 0.001, 3.5)
		s.tone(0.0, 0.5, 220.0, 70.0, "saw", 0.25, 0.001, 3.0, 0.0, 6.0, 1200.0)
		s.bell(0.02, 2.0, 523.0, 0.08, [[1.0, 1.0, 2.0], [2.41, 0.6, 3.0], [3.93, 0.4, 5.0], [5.4, 0.2, 8.0]])
		s.bell(0.02, 2.0, 554.0, 0.05, [[1.0, 1.0, 2.0], [2.76, 0.5, 4.0]]))
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
	# a chest: the lid's hinge creaks, the latch knocks, coins and light spill
	fx("chest", 1.1, func(s):
		s.tone(0.0, 0.35, 180.0, 260.0, "saw", 0.16, 0.03, 1.0, 0.06, 26.0, 900.0)
		s.noise(0.0, 0.3, 0.12, 2500.0, 1500.0, 600.0, 0.05, 2.0, 30.0)
		s.tone(0.34, 0.06, 140.0, 90.0, "sine", 0.45, 0.001, 6.0)
		s.noise(0.34, 0.04, 0.5, 3500.0, 1200.0, 400.0, 0.001, 8.0)
		for k in 7:
			var t: float = 0.42 + k * 0.045 + s.rng.randf() * 0.03
			s.bell(t, 0.25, s.rng.randf_range(2600.0, 4200.0), 0.07, [[1.0, 1.0, 9.0], [2.7, 0.5, 13.0]])
		s.bell(0.45, 0.6, 1046.0, 0.1)
		s.bell(0.55, 0.6, 1568.0, 0.06))
	# the Undervault's own sounds, heard from a few tiles off (Dungeon._music_watch)
	fx("amb_drip", 0.6, func(s):
		for k in 2:
			var f: float = s.rng.randf_range(1300.0, 1900.0)
			s.tone(k * 0.28, 0.14, f, f * 0.55, "sine", 0.3 - k * 0.1, 0.001, 8.0))
	fx("amb_chain", 1.2, func(s):
		for k in 9:
			var t: float = k * 0.09 + s.rng.randf() * 0.04
			s.bell(t, 0.3, s.rng.randf_range(1800.0, 3200.0), 0.12 - k * 0.008, [[1.0, 1.0, 10.0], [2.3, 0.6, 14.0], [3.7, 0.3, 18.0]])
			s.noise(t, 0.02, 0.15, 6000.0, 3000.0, 1500.0, 0.001, 9.0))
	fx("amb_stone", 1.6, func(s):
		s.noise(0.0, 1.4, 0.5, 500.0, 180.0, 40.0, 0.2, 1.5, 9.0)
		s.tone(0.0, 1.2, 70.0, 55.0, "saw", 0.08, 0.3, 1.5, 0.0, 6.0, 220.0)
		for k in 4:
			s.noise(0.6 + k * 0.18, 0.05, 0.25, 2500.0, 1000.0, 300.0, 0.001, 6.0))
	fx("amb_whisper", 2.2, func(s):
		for k in 3:
			var t: float = k * 0.55
			s.noise(t, 0.6, 0.22, 2400.0, 1600.0, 700.0, 0.15, 1.5, 7.0 + k))
	fx("amb_creak", 1.4, func(s):
		s.tone(0.0, 1.1, 210.0, 160.0, "saw", 0.12, 0.08, 1.2, 0.04, 22.0, 900.0)
		s.noise(0.0, 1.0, 0.1, 1800.0, 900.0, 300.0, 0.1, 1.5, 22.0))
	fx("amb_bubble", 1.0, func(s):
		for k in 4:
			var t: float = k * 0.17 + s.rng.randf() * 0.05
			var f: float = s.rng.randf_range(260.0, 480.0)
			s.tone(t, 0.12, f, f * 1.9, "sine", 0.22, 0.004, 4.0))
	fx("amb_bell", 3.5, func(s):
		s.bell(0.0, 3.4, 220.0, 0.25, [[1.0, 1.0, 1.2], [2.76, 0.5, 1.8], [5.4, 0.25, 2.6], [8.93, 0.12, 3.5]]))
	fx("amb_gust", 2.6, func(s):
		s.noise(0.0, 2.5, 0.5, 600.0, 1600.0, 120.0, 0.9, 1.2, 0.0))
	# urns shattering, one voice per material, three takes each (Audio picks one)
	for mat in ["clay", "root", "gilded"]:
		var base: String = "urn" if mat == "clay" else "urn_" + String(mat)
		for take in 3:
			var nm: String = base if take == 0 else "%s_%d" % [base, take + 1]
			var m: String = mat
			fx(nm, 0.62, func(s): _shatter(s, m), 11 + take * 17 + mat.length() * 5)
	# the smith at the anvil: the hammer's bite on hot iron, the anvil's long
	# inharmonic ring, the hammer bouncing once - three takes (each a little
	# different strike) - and the bellows breathing on the fire
	for take in 3:
		var nm2: String = "anvil" if take == 0 else "anvil_%d" % (take + 1)
		var base_f: float = [1040.0, 980.0, 1110.0][take]
		var bounce: float = [0.11, 0.13, 0.095][take]
		fx(nm2, 1.1, func(s):
			s.noise(0.0, 0.025, 0.9, 12000.0, 7000.0, 2500.0, 0.0003, 9.0)
			s.tone(0.0, 0.05, 420.0, 260.0, "sine", 0.25, 0.0005, 8.0)
			s.bell(0.0, 1.0, base_f, 0.2, [[1.0, 1.0, 3.5], [2.76, 0.55, 5.0], [5.4, 0.3, 7.0], [8.1, 0.15, 10.0]])
			s.noise(bounce, 0.015, 0.35, 11000.0, 7000.0, 3000.0, 0.0003, 9.0)
			s.bell(bounce, 0.5, base_f * 1.003, 0.07, [[1.0, 1.0, 6.0], [2.76, 0.5, 8.0]]), 41 + take * 13)
	fx("bellows", 1.4, func(s):
		s.noise(0.0, 0.7, 0.5, 700.0, 1400.0, 120.0, 0.25, 1.4)
		s.noise(0.7, 0.6, 0.3, 1200.0, 500.0, 100.0, 0.05, 2.5)
		s.noise(0.45, 0.8, 0.25, 4000.0, 2500.0, 1500.0, 0.2, 2.0, 22.0))
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
	# finds landing, by grade: a rare one taps down with one glassy note; an
	# epic one with a rising pair over a soft shimmer; a legendary (set,
	# unique) one first rises humming into the air (drop_rise), then strikes
	# the floor with a thump, a metal ring and a cascade with a long tail
	# --- weapon forms -------------------------------------------------------------
	# Gravecleaver: a heavy chop biting in; Sunder: the guard of a foe cracks
	fx("cleave_hit", 0.45, func(s):
		s.tone(0.0, 0.12, 150.0, 62.0, "sine", 0.36, 0.001, 5.0)
		s.noise(0.0, 0.09, 0.8, 3200.0, 700.0, 300.0, 0.001, 6.0)
		s.tone(0.005, 0.18, 720.0, 640.0, "square", 0.08, 0.001, 6.0, 0.0, 6.0, 2200.0))
	fx("sunder", 0.8, func(s):
		s.noise(0.0, 0.05, 0.9, 9000.0, 4000.0, 1500.0, 0.0005, 8.0)
		s.tone(0.0, 0.1, 180.0, 70.0, "sine", 0.3, 0.001, 6.0)
		s.bell(0.01, 0.7, 610.0, 0.16, [[1.0, 1.0, 3.0], [2.41, 0.5, 5.0], [3.93, 0.3, 8.0]])
		s.tone(0.03, 0.4, 900.0, 420.0, "saw", 0.06, 0.002, 3.0, 0.0, 6.0, 2400.0))
	# Duelist's Sabre: the riposte - a bright, fast ring of steel
	fx("riposte", 0.55, func(s):
		s.noise(0.0, 0.08, 0.5, 12000.0, 5000.0, 3000.0, 0.002, 5.0)
		s.bell(0.02, 0.5, 1760.0, 0.16, [[1.0, 1.0, 5.0], [2.76, 0.4, 7.0]])
		s.bell(0.05, 0.45, 2637.0, 0.1, [[1.0, 1.0, 6.0]]))
	# Tombmaul: the ground answering a slam
	fx("aftershock", 0.7, func(s):
		s.tone(0.0, 0.32, 110.0, 44.0, "sine", 0.4, 0.004, 3.0)
		s.noise(0.0, 0.5, 0.6, 900.0, 250.0, 120.0, 0.004, 2.5)
		for k in 6:
			s.noise(0.04 + k * 0.05, 0.03, 0.18, 2600.0, 1200.0, 500.0, 0.001, 8.0))
	# Emberforge Mallet: molten sparks, and the heat vented all at once
	fx("sparks", 0.4, func(s):
		for k in 9:
			var t: float = s.rng.randf() * 0.25
			s.noise(t, 0.012, 0.35, 11000.0, 7000.0, 3500.0, 0.0003, 9.0)
			s.tone(t, 0.04, s.rng.randf_range(2600.0, 4200.0), 2000.0, "sine", 0.08, 0.0005, 9.0))
	fx("vent", 1.2, func(s):
		s.noise(0.0, 1.0, 0.8, 400.0, 3400.0, 150.0, 0.03, 1.4, 18.0)
		s.tone(0.0, 0.9, 85.0, 60.0, "saw", 0.22, 0.02, 1.6, 0.04, 9.0, 500.0)
		s.tone(0.0, 0.2, 160.0, 70.0, "sine", 0.3, 0.001, 5.0))
	# Gloam Kris: marks torn open - a rip of shadow
	fx("gloam_tear", 0.6, func(s):
		s.noise(0.0, 0.3, 0.6, 1800.0, 700.0, 300.0, 0.01, 2.5, 26.0)
		s.tone(0.0, 0.35, 880.0, 280.0, "saw", 0.14, 0.004, 2.5, 0.0, 6.0, 1600.0)
		s.bell(0.04, 0.45, 466.0, 0.08, [[1.0, 1.0, 4.0], [2.76, 0.4, 6.0]]))
	# Ember Shivs: a thrown little knife
	fx("shiv", 0.25, func(s):
		s.noise(0.0, 0.1, 0.4, 9000.0, 4000.0, 2500.0, 0.003, 4.0)
		s.bell(0.0, 0.18, 2349.0, 0.08, [[1.0, 1.0, 9.0], [2.4, 0.4, 12.0]]))
	# Rootspear: a root closing round a leg; the spear planted and thorns rising
	fx("root", 0.45, func(s):
		s.tone(0.0, 0.3, 190.0, 130.0, "saw", 0.16, 0.004, 2.5, 0.06, 22.0, 900.0)
		s.noise(0.0, 0.05, 0.5, 2600.0, 1200.0, 500.0, 0.001, 7.0)
		s.noise(0.08, 0.2, 0.2, 1500.0, 700.0, 300.0, 0.01, 3.0, 30.0))
	fx("thornplant", 1.0, func(s):
		s.tone(0.0, 0.14, 160.0, 60.0, "sine", 0.35, 0.001, 5.0)
		s.noise(0.0, 0.06, 0.7, 3000.0, 900.0, 300.0, 0.001, 7.0)
		for k in 7:
			s.noise(0.15 + k * 0.08, 0.05, 0.22, 2400.0, 1200.0, 600.0, 0.002, 6.0)
		s.tone(0.12, 0.7, 140.0, 220.0, "saw", 0.08, 0.1, 1.5, 0.08, 18.0, 800.0))
	# Warden's Partisan: a blow stopped on the shaft
	fx("block", 0.5, func(s):
		s.noise(0.0, 0.04, 0.8, 8000.0, 3000.0, 1200.0, 0.0005, 8.0)
		s.bell(0.0, 0.45, 880.0, 0.18, [[1.0, 1.0, 5.0], [2.41, 0.6, 7.0], [3.93, 0.3, 10.0]])
		s.tone(0.0, 0.08, 240.0, 120.0, "sine", 0.2, 0.001, 6.0))
	# Splitwood Bow: another arrow on the string
	fx("nock", 0.15, func(s):
		s.noise(0.0, 0.015, 0.4, 5000.0, 2500.0, 900.0, 0.0005, 9.0)
		s.tone(0.0, 0.07, 1250.0, 1100.0, "sine", 0.12, 0.001, 8.0))
	# Long Rimebow: the ice spear; Rimewood: shards breaking, the Frost Lance
	fx("ice_spear", 0.9, func(s):
		s.noise(0.0, 0.25, 0.5, 2500.0, 9000.0, 1500.0, 0.01, 3.0)
		s.bell(0.04, 0.8, 1568.0, 0.12, [[1.0, 1.0, 3.0], [2.0, 0.4, 5.0], [3.0, 0.2, 8.0]])
		s.bell(0.06, 0.7, 2093.0, 0.08, [[1.0, 1.0, 4.0]])
		s.tone(0.0, 0.5, 4200.0, 3600.0, "sine", 0.03, 0.02, 3.0, 0.02, 11.0))
	fx("shatter_ice", 0.4, func(s):
		for k in 8:
			var t2: float = s.rng.randf() * 0.12
			var f2: float = s.rng.randf_range(2800.0, 6000.0)
			s.tone(t2, s.rng.randf_range(0.06, 0.14), f2, f2 * 0.98, "sine", 0.1, 0.0005, 8.0)
		s.noise(0.0, 0.04, 0.5, 10000.0, 6000.0, 3000.0, 0.0005, 8.0))
	fx("frost_lance", 1.0, func(s):
		s.noise(0.0, 0.5, 0.45, 6000.0, 2500.0, 1800.0, 0.01, 2.5)
		s.pad(0.0, 0.7, [1046.0, 1318.0, 1568.0], 0.07, 5000.0, 0.01, 0.45)
		s.bell(0.0, 0.8, 2637.0, 0.06, [[1.0, 1.0, 3.0]])
		s.tone(0.0, 0.12, 300.0, 120.0, "sine", 0.18, 0.001, 5.0))
	# Codex of Echoes: a glyph written; spent, the spell answers again
	fx("glyph", 0.5, func(s):
		s.bell(0.0, 0.45, 1318.0, 0.12, [[1.0, 1.0, 4.0], [2.0, 0.35, 6.0]])
		s.tone(0.0, 0.3, 659.0, 990.0, "sine", 0.05, 0.05, 2.0))
	fx("echo_cast", 1.0, func(s):
		s.noise(0.0, 0.35, 0.3, 800.0, 5000.0, 600.0, 0.25, 0.8)
		for k in 4:
			s.bell(0.3 + k * 0.05, 0.6, midi(76 + [0, 3, 7, 12][k]), 0.08)
		s.pad(0.25, 0.7, [midi(64), midi(71)], 0.06, 2600.0, 0.05, 0.4))
	# Grimoire of Ash: a short breath of fire (repeats while reading)
	fx("breath", 0.4, func(s):
		s.noise(0.0, 0.38, 0.6, 700.0, 1600.0, 200.0, 0.03, 1.5, 21.0)
		s.noise(0.0, 0.3, 0.2, 4000.0, 2500.0, 1500.0, 0.03, 2.0, 37.0))
	# --- spells of this pass -------------------------------------------------------
	# Soulfire Beam: the lantern opening, then its pour (repeated while it flows)
	fx("beam_start", 0.6, func(s):
		s.noise(0.0, 0.4, 0.6, 600.0, 4000.0, 300.0, 0.03, 1.8)
		s.tone(0.0, 0.5, 220.0, 440.0, "saw", 0.14, 0.02, 2.0, 0.0, 6.0, 1800.0)
		s.bell(0.05, 0.45, 880.0, 0.08, [[1.0, 1.0, 4.0], [2.0, 0.4, 6.0]]))
	fx("beam_hum", 0.45, func(s):
		s.noise(0.0, 0.42, 0.45, 900.0, 1400.0, 250.0, 0.04, 1.2, 31.0)
		s.tone(0.0, 0.42, 330.0, 335.0, "saw", 0.08, 0.04, 1.2, 0.02, 9.0, 1400.0))
	# Cinder Orb: thrown with a soft whoomp; its burst grows with its age
	fx("orb_throw", 0.5, func(s):
		s.noise(0.0, 0.35, 0.45, 500.0, 1800.0, 150.0, 0.02, 2.0)
		s.tone(0.0, 0.3, 160.0, 260.0, "sine", 0.18, 0.02, 2.5))
	fx("orb_burst", 1.0, func(s):
		s.tone(0.0, 0.16, 150.0, 60.0, "sine", 0.32, 0.001, 4.0)
		s.noise(0.0, 0.6, 0.8, 4000.0, 600.0, 180.0, 0.002, 2.6)
		for k in 6:
			s.noise(0.05 + k * 0.05, 0.03, 0.2, 7000.0, 4000.0, 2000.0, 0.001, 7.0))
	# Rimewall: ice rising with a crackle; and shattering
	fx("icewall_rise", 0.9, func(s):
		s.noise(0.0, 0.5, 0.4, 3000.0, 7000.0, 1200.0, 0.02, 2.5)
		for k in 8:
			var t3: float = 0.03 + k * 0.05
			s.tone(t3, 0.08, s.rng.randf_range(1800.0, 3600.0), 1500.0, "sine", 0.08, 0.001, 7.0)
		s.tone(0.0, 0.3, 120.0, 90.0, "sine", 0.2, 0.01, 3.0))
	fx("icewall_shatter", 0.9, func(s):
		s.noise(0.0, 0.08, 0.9, 10000.0, 5000.0, 2500.0, 0.0005, 6.0)
		for k in 16:
			var t4: float = s.rng.randf() * 0.35
			var f4: float = s.rng.randf_range(2200.0, 6500.0)
			s.tone(t4, s.rng.randf_range(0.06, 0.2), f4, f4 * 0.97, "sine", 0.08, 0.0005, 8.0)
		s.tone(0.0, 0.12, 170.0, 80.0, "sine", 0.25, 0.001, 5.0))
	# Hearthfire Form: the Kindled catching fire; the form ending in a nova
	fx("hearthfire_on", 1.2, func(s):
		s.noise(0.0, 0.9, 0.7, 400.0, 3500.0, 150.0, 0.12, 1.4, 17.0)
		s.tone(0.0, 0.9, 110.0, 220.0, "saw", 0.16, 0.1, 1.5, 0.03, 7.0, 1200.0)
		s.pad(0.2, 0.9, [midi(57), midi(64), midi(69)], 0.07, 2400.0, 0.2, 0.5))
	fx("hearthfire_end", 0.9, func(s):
		s.tone(0.0, 0.2, 180.0, 55.0, "sine", 0.32, 0.001, 4.0)
		s.noise(0.0, 0.7, 0.7, 3000.0, 500.0, 150.0, 0.003, 2.2))
	# elites: a Frenzied foe erupting; a Shepherd's shield washing over its kin
	fx("frenzy", 0.8, func(s):
		s.tone(0.0, 0.6, 140.0, 95.0, "saw", 0.3, 0.02, 1.8, 0.08, 14.0, 900.0)
		s.noise(0.0, 0.5, 0.5, 1500.0, 600.0, 200.0, 0.01, 2.0, 24.0)
		s.tone(0.0, 0.15, 200.0, 80.0, "sine", 0.25, 0.001, 5.0))
	fx("shepherd", 0.9, func(s):
		s.pad(0.0, 0.8, [midi(62), midi(69), midi(74)], 0.08, 2600.0, 0.05, 0.6)
		s.bell(0.0, 0.7, midi(86), 0.08, [[1.0, 1.0, 3.0], [2.0, 0.4, 5.0]])
		s.noise(0.0, 0.5, 0.2, 3000.0, 6000.0, 1500.0, 0.05, 2.0))
	# Ember Rush: a chained rush (its cooldown comes back)
	fx("rush_chain", 0.4, func(s):
		s.bell(0.0, 0.35, 1175.0, 0.1, [[1.0, 1.0, 5.0], [2.0, 0.4, 7.0]])
		s.bell(0.06, 0.3, 1568.0, 0.08, [[1.0, 1.0, 6.0]]))
	# the Bone Colossus wakes: a long breath through an old skull, bone
	# grinding, and the soul-light in its eyes ringing up
	fx("colossus_wake", 2.6, func(s):
		s.noise(0.0, 1.6, 0.4, 500.0, 1100.0, 140.0, 0.5, 1.2, 3.0)
		s.tone(0.0, 1.5, 98.0, 82.0, "saw", 0.12, 0.4, 1.2, 0.02, 2.0, 500.0)
		for k in 6:
			s.noise(0.15 + k * 0.17, 0.06, 0.2, 2200.0, 900.0, 300.0, 0.003, 6.0)
		var notes := [69, 76, 81, 88]
		for k in notes.size():
			s.bell(0.7 + k * 0.16, 1.7 - k * 0.2, midi(notes[k]), 0.1, [[1.0, 1.0, 2.0], [2.0, 0.4, 3.0], [3.0, 0.2, 5.0]])
		s.pad(0.6, 1.9, [midi(57), midi(64), midi(69)], 0.08, 1600.0, 0.6, 0.9))
	fx("drop_rare", 0.7, func(s):
		s.tone(0.0, 0.05, 260.0, 140.0, "sine", 0.25, 0.001, 7.0)
		s.noise(0.0, 0.02, 0.25, 6000.0, 4000.0, 2500.0, 0.0005, 9.0)
		s.bell(0.01, 0.6, midi(88), 0.16, [[1.0, 1.0, 4.0], [2.0, 0.35, 6.0], [3.01, 0.15, 9.0]]))
	fx("drop_epic", 1.1, func(s):
		s.tone(0.0, 0.07, 220.0, 110.0, "sine", 0.32, 0.001, 6.0)
		s.noise(0.0, 0.03, 0.3, 7000.0, 4000.0, 2500.0, 0.0005, 8.0)
		s.bell(0.01, 0.9, midi(81), 0.15, [[1.0, 1.0, 3.0], [2.0, 0.4, 5.0], [3.0, 0.2, 8.0]])
		s.bell(0.11, 0.9, midi(88), 0.14, [[1.0, 1.0, 3.0], [2.0, 0.4, 5.0], [3.0, 0.2, 8.0]])
		s.pad(0.05, 0.95, [midi(69), midi(76)], 0.08, 2600.0, 0.05, 0.6))
	fx("drop_rise", 0.7, func(s):
		s.noise(0.0, 0.62, 0.22, 500.0, 6000.0, 400.0, 0.4, 0.6)
		s.tone(0.0, 0.62, midi(57), midi(69), "sine", 0.14, 0.35, 0.8, 0.012, 7.0)
		s.tone(0.0, 0.62, midi(64), midi(76), "sine", 0.08, 0.4, 0.8))
	fx("drop_legendary", 2.4, func(s):
		s.tone(0.0, 0.1, 160.0, 70.0, "sine", 0.26, 0.001, 6.0)
		s.noise(0.0, 0.05, 0.45, 5000.0, 2000.0, 900.0, 0.0005, 7.0)
		s.bell(0.0, 1.6, 1318.0, 0.12, [[1.0, 1.0, 2.5], [2.41, 0.55, 4.0], [3.93, 0.3, 6.0], [5.4, 0.18, 9.0]])
		var notes := [64, 69, 73, 76, 81, 85]
		for k in notes.size():
			s.bell(0.08 + k * 0.07, 1.8 - k * 0.12, midi(notes[k] + 12), 0.11)
		s.pad(0.05, 2.2, [midi(57), midi(64), midi(69), midi(73)], 0.12, 2200.0, 0.08, 1.4))
	# the Undervault Gate: a slow breathing drone, and the flare as the veil opens
	fx("gate_hum", 2.6, func(s):
		s.pad(0.0, 2.5, [55.0, 82.6, 110.3], 0.2, 420.0, 0.9, 1.2)
		s.tone(0.2, 2.2, 165.0, 164.0, "sine", 0.05, 0.8, 1.2, 0.015, 0.7)
		s.bell(0.9, 1.4, midi(91), 0.025))
	fx("gate_flare", 1.8, func(s):
		s.tone(0.0, 1.2, 70.0, 220.0, "saw", 0.3, 0.3, 1.0, 0.0, 6.0, 900.0)
		s.noise(0.0, 1.4, 0.35, 600.0, 5000.0, 200.0, 0.6, 1.6)
		s.pad(0.5, 1.25, [midi(62), midi(69), midi(74), midi(81)], 0.12, 2600.0, 0.05, 0.9)
		for k in 4:
			s.bell(0.55 + k * 0.07, 1.0, midi(86 + [0, 5, 7, 12][k]), 0.06))
	# room seals: a rising weave of chimes over a thrum, and its release
	fx("seal_close", 0.9, func(s):
		s.tone(0.0, 0.5, 70.0, 95.0, "sine", 0.5, 0.01, 2.5)
		s.noise(0.0, 0.35, 0.18, 2500.0, 6000.0, 900.0, 0.08, 3.0)
		for k in 4:
			s.bell(0.05 + k * 0.06, 0.6, midi(74 + [0, 3, 7, 10][k]), 0.07))
	fx("seal_open", 1.1, func(s):
		for k in 5:
			s.bell(k * 0.05, 0.8, midi(86 - [0, 2, 5, 7, 12][k]), 0.06)
		s.noise(0.0, 0.8, 0.22, 7000.0, 1500.0, 800.0, 0.01, 2.0)
		s.tone(0.0, 0.6, 110.0, 55.0, "sine", 0.35, 0.005, 3.0))
	# the living Undervault's own moments
	fx("ping", 0.5, func(s):
		s.bell(0.0, 0.4, midi(88), 0.22, [[1.0, 1.0, 5.0], [2.0, 0.3, 8.0]])
		s.bell(0.1, 0.38, midi(95), 0.16, [[1.0, 1.0, 6.0], [2.0, 0.25, 9.0]]))
	# a great thing choosing its path: a low swell and a rising chord
	fx("evolve", 1.6, func(s):
		s.pad(0.0, 1.5, [midi(45), midi(52), midi(57)], 0.3, 1200.0, 0.25, 0.8)
		for k in 4:
			s.bell(0.35 + k * 0.16, 1.1, midi([69, 73, 76, 81][k]), 0.18)
		s.noise(0.0, 1.0, 0.12, 2000.0, 6000.0, 600.0, 0.3, 2.0))
	# a blade in time: a short bright ring over a soft tick
	fx("cadence", 0.35, func(s):
		s.noise(0.0, 0.03, 0.4, 7000.0, 4000.0, 1500.0, 0.001, 9.0)
		s.bell(0.0, 0.3, midi(93), 0.14, [[1.0, 1.0, 9.0], [2.76, 0.35, 14.0]]))
	# a flame pinched out, and a breath of smoke
	fx("snuff", 0.7, func(s):
		s.noise(0.0, 0.08, 0.6, 2400.0, 800.0, 500.0, 0.001, 6.0)
		s.tone(0.02, 0.2, 620.0, 210.0, "sine", 0.25, 0.002, 4.0)
		s.noise(0.06, 0.6, 0.22, 3200.0, 1100.0, 500.0, 0.03, 3.0, 5.0))
	# a chain paid out through the air, and the same chain taking weight
	fx("chain_throw", 0.6, func(s):
		for k in 7:
			s.noise(k * 0.045, 0.05, 0.5 - k * 0.04, 5200.0, 3200.0, 1400.0, 0.001, 8.0)
			s.bell(k * 0.045, 0.12, midi(84 + (k % 3) * 2), 0.06, [[1.0, 1.0, 14.0], [2.7, 0.5, 18.0]]))
	fx("chain_haul", 0.7, func(s):
		s.tone(0.0, 0.3, 240.0, 130.0, "saw", 0.26, 0.002, 4.0, 0.0, 6.0, 900.0)
		s.noise(0.0, 0.1, 0.7, 4200.0, 1200.0, 500.0, 0.001, 7.0)
		for k in 4:
			s.noise(0.1 + k * 0.08, 0.06, 0.34 - k * 0.05, 3800.0, 2200.0, 900.0, 0.001, 8.0))
	fx("seal_break", 0.9, func(s):
		s.noise(0.0, 0.12, 0.7, 5000.0, 900.0, 300.0, 0.001, 6.0)     # the stone cracks
		s.tone(0.0, 0.22, 170.0, 70.0, "sine", 0.3, 0.002, 5.0)
		for k in 3:
			s.bell(0.04 + k * 0.07, 0.6, midi(84 - k * 5), 0.16))     # its ward runs out
	fx("altar_kindled", 1.6, func(s):
		s.tone(0.0, 0.9, 165.0, 247.0, "sine", 0.14, 0.1, 2.0)
		s.noise(0.0, 0.9, 0.3, 900.0, 3000.0, 300.0, 0.2, 2.0)        # a flame taking
		for k in 4:
			s.bell(0.35 + k * 0.1, 1.1, midi([62, 69, 74, 78][k]), 0.24))
	fx("altar_broken", 1.4, func(s):
		s.noise(0.0, 0.25, 0.8, 3500.0, 500.0, 120.0, 0.001, 5.0)     # stone gives way
		s.tone(0.0, 0.7, 120.0, 34.0, "saw", 0.4, 0.002, 3.0, 0.0, 6.0, 500.0)
		for k in 5:
			s.noise(0.12 + k * 0.13, 0.12, 0.3 - k * 0.04, 2500.0, 700.0, 300.0, 0.002, 6.0)
		s.bell(0.3, 1.0, midi(49), 0.1, [[1.0, 1.0, 3.0], [1.41, 0.6, 4.0], [2.3, 0.3, 6.0]]))
	fx("altar_pact", 1.5, func(s):
		s.pad(0.0, 1.4, [midi(38), midi(45), midi(51)], 0.4, 800.0, 0.25, 0.7)
		s.tone(0.1, 1.2, 440.0, 430.0, "sine", 0.06, 0.4, 1.5, 0.02, 4.5)
		s.noise(0.0, 1.3, 0.12, 900.0, 1600.0, 250.0, 0.4, 1.5, 3.5))  # a breath drawn in
	fx("blood_pact", 0.9, func(s):
		s.tone(0.0, 0.16, 150.0, 80.0, "sine", 0.5, 0.004, 5.0)
		s.tone(0.2, 0.2, 132.0, 72.0, "sine", 0.4, 0.004, 5.0)
		s.noise(0.0, 0.14, 0.2, 900.0, 400.0, 200.0, 0.004, 5.0)
		s.noise(0.2, 0.16, 0.16, 800.0, 350.0, 180.0, 0.004, 5.0)
		s.pad(0.05, 0.8, [midi(52), midi(58)], 0.22, 900.0, 0.1, 0.5))
	fx("grudge_ward", 0.7, func(s):
		s.bell(0.0, 0.6, 196.0, 0.4, [[1.0, 1.0, 4.0], [1.51, 0.7, 5.0], [2.63, 0.4, 7.0]])
		s.noise(0.0, 0.1, 0.4, 3000.0, 900.0, 400.0, 0.001, 6.0))
	fx("grudge_flee", 0.9, func(s):
		s.noise(0.0, 0.7, 0.45, 900.0, 5000.0, 400.0, 0.03, 3.0)
		s.tone(0.0, 0.6, 220.0, 70.0, "saw", 0.22, 0.01, 3.0, 0.0, 6.0, 900.0))
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
	# the Sunken Throne: wind moaning through a vast hall, embers still
	# crackling in the ash, stone settling, and now and then a far-off bell
	var th := Synth.new(22050, 24.0, true, 14)
	th.noise(0.0, 24.0, 0.32, 260.0, 260.0, 40.0, 1.5, 0.0, 0.05)
	th.noise(0.0, 24.0, 0.14, 900.0, 600.0, 300.0, 3.0, 0.0, 0.12)
	for k in 180:
		var t := th.rng.randf_range(0.0, 23.8)
		th.noise(t, 0.015, th.rng.randf_range(0.05, 0.25), 6000.0, 3000.0, 1500.0, 0.001, 9.0)
	for k in 5:
		var t2 := th.rng.randf_range(0.0, 22.0)
		th.noise(t2, 0.5, 0.18, 300.0, 120.0, 40.0, 0.01, 4.0)
	for k in 2:
		th.bell(4.0 + k * 11.0, 5.0, midi(57 - k * 5), 0.05)
	th.save(MUS + "amb_throne.wav", 0.5)


func _music() -> void:
	_crypt()
	_rootmire()
	_throne()
	_boss()
	_hearth()
	_victory()
	# layers that play in step with the walking music and swell in a fight
	_combat_layer("crypt", 70.0, 8, 38, 121)
	_combat_layer("rootmire", 76.0, 8, 40, 161)
	_combat_layer("throne", 62.0, 8, 33, 171)
	_hollow()
	_combat_layer("hollow", 60.0, 8, 37, 181)
	_boss_bloom()
	_boss_king()
	_stings()


## A fight's layer for a walking loop: the same tempo and length, so the two
## play in step (Audio swells it with the fight). Low drums, a driving
## ostinato on the root with a half-step of dread every fourth bar, and a
## tremolo of high strings.
func _combat_layer(base: String, bpm: float, bars: int, root: int, seed_v: int) -> void:
	var beat := 60.0 / bpm
	var L := bars * 4 * beat
	var s := Synth.new(22050, L, true, seed_v)
	var throne := base == "throne"
	var root_wood := base == "rootmire"
	for b in bars:
		var t0 := b * 4 * beat
		# drums: a heavy pulse, a push before the bar, a roll into each fourth bar
		s.kick(t0, 0.75)
		s.kick(t0 + 1.5 * beat, 0.45)
		s.kick(t0 + 2.0 * beat, 0.6)
		if root_wood:
			for k in 6:
				s.noise(t0 + k * beat * 0.66, 0.03, 0.22, 3000.0, 1500.0, 500.0, 0.001, 8.0)
		else:
			s.snare(t0 + 3.0 * beat, 0.18 if not throne else 0.26)
		if b % 4 == 3:
			for k in 6:
				s.kick(t0 + 3.0 * beat + k * beat / 6.0, 0.25 + 0.06 * k)
		# the ostinato: eighths on the root, a half-step up every fourth bar
		var n := root + 12 + (1 if b % 4 == 3 else 0)
		for k in 8:
			var f := midi(n + (12 if k % 4 == 2 else 0))
			s.tone(t0 + k * beat * 0.5, beat * 0.42, f, f, "saw", 0.16, 0.004, 3.0, 0.0, 6.0, 900.0)
		# high strings trembling on a fifth (on the dread bar, a tritone)
		var top := root + 24
		var pair := [top, top + (6 if b % 4 == 3 else 7)]
		for k in 16:
			for p in pair:
				var fh := midi(p)
				s.tone(t0 + k * beat * 0.25, beat * 0.22, fh, fh, "saw", 0.03, 0.01, 2.0, 0.0, 6.0, 2200.0)
		if throne and b % 2 == 0:
			# brass stabs for the drowned court
			var ch := [root + 12, root + 15, root + 19]
			for c in ch:
				s.tone(t0, beat * 0.6, midi(c), midi(c), "saw", 0.07, 0.01, 2.0, 0.0, 6.0, 1300.0)
	s.echo(beat * 0.5, 0.2, 1.0)
	s.save(MUS + base + "_combat.wav", 0.8)


## The Hollow Below: no region's music, its own - whole-tone bells drifting
## over a beating drone, slow breaths of a far choir. Unsettling, not loud.
func _hollow() -> void:
	var bpm := 60.0
	var beat := 60.0 / bpm
	var bars := 8
	var L := bars * 4 * beat
	var s := Synth.new(22050, L, true, 191)
	var d1: float = roundf(midi(37) * L) / L
	var d2: float = roundf((midi(37) + 0.9) * L) / L
	s.tone(0.0, L, d1, d1, "sine", 0.07, 0.0001, 0.0)
	s.tone(0.0, L, d2, d2, "sine", 0.04, 0.0001, 0.0)
	var whole := [61, 63, 65, 67, 69, 71, 73]
	for b in bars * 4:
		if s.rng.randf() < 0.4:
			var n: int = whole[s.rng.randi_range(0, whole.size() - 1)]
			s.bell(b * beat + s.rng.randf() * 0.4, 3.5, midi(n + 12), 0.09)
	for c in 4:
		var fr: Array = []
		for n in [[49, 55, 61], [51, 57, 63], [47, 53, 59], [49, 55, 61]][c]:
			fr.append(midi(n))
		s.pad(c * 8 * beat, 8 * beat + 1.0, fr, 0.11, 600.0, 3.0, 2.5)
	s.echo(beat * 0.75, 0.45, 1.0)
	s.save(MUS + "hollow.wav", 0.75)


## The Hollow Bloom: a rolling 6/8, marimba-wood riff in E minor over a
## growling drone, swelling roots.
func _boss_bloom() -> void:
	var bpm := 112.0
	var eighth := 60.0 / bpm / 2.0
	var bars := 16
	var L := bars * 6 * eighth
	var s := Synth.new(22050, L, true, 201)
	var dr: float = roundf(midi(28) * L) / L
	s.tone(0.0, L, dr, dr, "saw", 0.12, 0.0001, 0.0, 0.0, 6.0, 260.0)
	var riff := [52, 55, 59, 57, 55, 50]
	for b in bars:
		var t0 := b * 6 * eighth
		s.kick(t0, 0.75)
		s.kick(t0 + 3 * eighth, 0.55)
		s.noise(t0 + 2 * eighth, 0.04, 0.25, 4000.0, 2000.0, 600.0, 0.001, 8.0)
		s.noise(t0 + 5 * eighth, 0.04, 0.25, 4000.0, 2000.0, 600.0, 0.001, 8.0)
		for k in 6:
			var n: int = riff[k] + (2 if b % 4 == 3 and k > 2 else 0) + (12 if b >= 8 and k % 3 == 0 else 0)
			s.bell(t0 + k * eighth, 0.8, midi(n), 0.14, [[1.0, 1.0, 7.0], [3.99, 0.3, 12.0], [9.2, 0.08, 18.0]])
		if b % 2 == 0:
			var fr: Array = []
			for n in [[40, 47, 52], [36, 43, 48], [38, 45, 50], [35, 42, 47]][(b / 2) % 4]:
				fr.append(midi(n + 12))
			s.pad(t0, 12 * eighth + 0.4, fr, 0.09, 900.0, 0.6, 0.8)
	s.save(MUS + "boss_bloom.wav", 0.85)


## The Ashen King: a dead court's war march - timpani, brass chords on the
## harmonic minor, a snare that never rests, a broken fanfare above.
func _boss_king() -> void:
	var bpm := 118.0
	var beat := 60.0 / bpm
	var bars := 16
	var L := bars * 4 * beat
	var s := Synth.new(22050, L, true, 211)
	var chords := [[45, 48, 52], [41, 45, 48], [44, 47, 50], [45, 48, 52]]
	for b in bars:
		var t0 := b * 4 * beat
		s.kick(t0, 0.8)
		s.kick(t0 + 2 * beat, 0.6)
		for k in 8:
			s.snare(t0 + k * beat * 0.5, 0.1 + (0.12 if k % 2 == 1 else 0.0))
		var ch: Array = chords[(b / 2) % 4]
		for c in ch:
			s.tone(t0, beat * 1.6, midi(c + 12), midi(c + 12), "saw", 0.07, 0.02, 1.6, 0.0, 6.0, 1500.0)
			s.tone(t0 + 2.5 * beat, beat * 0.5, midi(c + 12), midi(c + 12), "saw", 0.06, 0.01, 2.0, 0.0, 6.0, 1500.0)
		s.tone(t0, beat * 3.8, midi(ch[0] - 12), midi(ch[0] - 12), "saw", 0.14, 0.01, 1.2, 0.0, 6.0, 400.0)
	var fan := [69, 72, 76, 75, 72, 71, 68, 69, 76, 77, 76, 72, 71, 72, 69, 68]
	for k in fan.size():
		var t := 8 * 4 * beat + k * 2 * beat
		s.tone(t, 1.7 * beat, midi(fan[k]), midi(fan[k]), "square", 0.07, 0.02, 1.4, 0.005, 5.0, 2000.0)
	s.save(MUS + "boss_king.wav", 0.85)


## Stings over the music: an elite comes (a timpani blow, a brass cluster
## rising, a cymbal swell) and a room is quiet again (a resolving chord).
func _stings() -> void:
	var e := Synth.new(22050, 2.4, false, 221)
	e.kick(0.0, 1.0)
	e.kick(0.12, 0.6)
	for k in 3:
		var n := 50 + k * 1
		e.tone(0.05, 1.8, midi(n), midi(n + 2), "saw", 0.12, 0.25, 1.5, 0.0, 6.0, 1600.0)
	e.noise(0.2, 1.6, 0.3, 2500.0, 9000.0, 2000.0, 1.2, 1.0)
	e.save(MUS + "sting_elite.wav", 0.8)
	var c := Synth.new(22050, 3.2, false, 222)
	c.pad(0.0, 3.0, [midi(57), midi(62), midi(64)], 0.18, 1400.0, 0.3, 1.6)
	c.pad(0.9, 2.2, [midi(57), midi(61), midi(64)], 0.18, 1400.0, 0.5, 1.6)
	c.bell(0.9, 2.2, midi(81), 0.06)
	c.save(MUS + "sting_clear.wav", 0.6)


## Exploration: slow, cold, D minor. A drone, shifting pads, a sparse plucked motif.
func _crypt() -> void:
	var bpm := 70.0
	var beat := 60.0 / bpm
	var bars := 8
	var L := bars * 4 * beat
	var s := Synth.new(22050, L, true, 21)
	# (drones kept low: the pads and the plucked line carry the piece, and a
	# loud sub drone masks the fight - measured with tools/audio/analyze.py)
	var dr: float = roundf(midi(38) * L) / L
	s.tone(0.0, L, dr, dr, "sine", 0.09, 0.0001, 0.0)
	var dr5: float = roundf(midi(45) * L) / L
	s.tone(0.0, L, dr5, dr5, "sine", 0.05, 0.0001, 0.0)
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
	s.tone(0.0, L, dr, dr, "sine", 0.08, 0.0001, 0.0)
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
	s.tone(0.0, L, dr, dr, "sine", 0.08, 0.0001, 0.0)
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
