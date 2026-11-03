## Tiny offline synthesizer used to author the game's sound effects and music.
## Everything renders into PackedFloat32Array buffers (mono) and is written as
## 16-bit WAV. Loops mix into a circular buffer so tails wrap seamlessly.
extends RefCounted

var sr := 44100
var buf := PackedFloat32Array()
var loop := false
var rng := RandomNumberGenerator.new()


func _init(sample_rate: int, seconds: float, looping := false, seed_v := 1) -> void:
	sr = sample_rate
	loop = looping
	buf.resize(int(seconds * sr))
	rng.seed = seed_v


func length() -> int:
	return buf.size()


func _add(i: int, v: float) -> void:
	if loop:
		buf[posmod(i, buf.size())] += v
	elif i >= 0 and i < buf.size():
		buf[i] += v


static func osc(wave: String, ph: float) -> float:
	var p := ph - floorf(ph)
	match wave:
		"sine":
			return sin(p * TAU)
		"square":
			return 1.0 if p < 0.5 else -1.0
		"pulse":
			return 1.0 if p < 0.25 else -1.0
		"saw":
			return 2.0 * p - 1.0
		"tri":
			return 4.0 * absf(p - 0.5) - 1.0
	return 0.0


## Tone with exponential pitch sweep, attack and exponential decay.
func tone(start: float, dur: float, f0: float, f1: float, wave := "sine", amp := 0.5, attack := 0.005, curve := 4.0, vibrato := 0.0, vib_rate := 6.0, lp := 0.0) -> void:
	var n := int(dur * sr)
	var s0 := int(start * sr)
	var ph := 0.0
	var y := 0.0
	var a := 1.0 - exp(-TAU * lp / sr) if lp > 0.0 else 1.0
	for i in n:
		var t := float(i) / n
		var f := f0 * pow(f1 / f0, t)
		if vibrato > 0.0:
			f *= 1.0 + vibrato * sin(TAU * vib_rate * i / sr)
		ph += f / sr
		var env := minf(1.0, (i / float(sr)) / maxf(attack, 0.0001)) * exp(-curve * t)
		var v := osc(wave, ph) * env * amp
		y += a * (v - y)
		_add(s0 + i, y)


## Filtered white noise; lowpass cutoff sweeps from lp0 to lp1.
func noise(start: float, dur: float, amp := 0.5, lp0 := 4000.0, lp1 := 1000.0, hp := 0.0, attack := 0.005, curve := 5.0, am_rate := 0.0) -> void:
	var n := int(dur * sr)
	var s0 := int(start * sr)
	var y := 0.0
	var yh := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / n
		var fc := lp0 * pow(lp1 / lp0, t)
		var a := 1.0 - exp(-TAU * fc / sr)
		var x := rng.randf_range(-1.0, 1.0)
		y += a * (x - y)
		var v := y
		if hp > 0.0:
			var ah := exp(-TAU * hp / sr)
			yh = ah * (yh + v - prev)
			prev = v
			v = yh
		var env := minf(1.0, (i / float(sr)) / maxf(attack, 0.0001)) * exp(-curve * t)
		if am_rate > 0.0:
			env *= 0.5 + 0.5 * sin(TAU * am_rate * i / sr)
		_add(s0 + i, v * env * amp)


## Plucked string (Karplus-Strong).
func pluck(start: float, dur: float, freq: float, amp := 0.4, damp := 0.996, bright := 0.5) -> void:
	var period := maxi(2, int(sr / freq))
	var line := PackedFloat32Array()
	line.resize(period)
	for i in period:
		line[i] = rng.randf_range(-1.0, 1.0)
	var s0 := int(start * sr)
	var n := int(dur * sr)
	var idx := 0
	var last := 0.0
	for i in n:
		var cur := line[idx]
		var nxt := line[(idx + 1) % period]
		var v := (cur * bright + nxt * (1.0 - bright)) * damp
		line[idx] = v
		idx = (idx + 1) % period
		var fade := 1.0 if i < n - 400 else float(n - i) / 400.0
		_add(s0 + i, cur * amp * fade)
		last = cur


## Bell / metal: inharmonic sine partials with individual decays.
func bell(start: float, dur: float, freq: float, amp := 0.3, partials: Array = [[1.0, 1.0, 3.0], [2.76, 0.5, 5.0], [5.4, 0.25, 8.0], [8.93, 0.12, 12.0]]) -> void:
	for p in partials:
		tone(start, dur, freq * p[0], freq * p[0], "sine", amp * p[1], 0.002, p[2])


## Soft pad: detuned saws through a lowpass with slow attack/release.
func pad(start: float, dur: float, freqs: Array, amp := 0.12, cutoff := 900.0, attack := 0.8, release := 0.8) -> void:
	var n := int(dur * sr)
	var s0 := int(start * sr)
	var phs := []
	for f in freqs:
		for d in [-0.004, 0.0, 0.005]:
			phs.append([f * (1.0 + d), rng.randf()])
	var y := 0.0
	var a := 1.0 - exp(-TAU * cutoff / sr)
	for i in n:
		var t := i / float(sr)
		var env := minf(1.0, t / attack) * minf(1.0, (dur - t) / release)
		var v := 0.0
		for p in phs:
			p[1] += p[0] / sr
			v += 2.0 * (p[1] - floorf(p[1])) - 1.0
		v /= phs.size()
		y += a * (v - y)
		_add(s0 + i, y * env * amp)


func kick(start: float, amp := 0.8) -> void:
	tone(start, 0.35, 110.0, 38.0, "sine", amp, 0.002, 5.0)
	noise(start, 0.02, amp * 0.4, 3000.0, 1000.0)


func snare(start: float, amp := 0.4) -> void:
	noise(start, 0.22, amp, 6000.0, 1500.0, 400.0, 0.001, 9.0)
	tone(start, 0.1, 220.0, 160.0, "tri", amp * 0.5, 0.001, 8.0)


func hat(start: float, amp := 0.15) -> void:
	noise(start, 0.05, amp, 12000.0, 8000.0, 6000.0, 0.001, 10.0)


## Feedback echo. For loops the echo is computed circularly over two passes
## so tails from the end of the loop spill correctly into its start.
func echo(delay: float, feedback: float, mix: float) -> void:
	var d := int(delay * sr)
	var n := buf.size()
	var e := PackedFloat32Array()
	e.resize(n)
	for pass_i in (2 if loop else 1):
		for i in n:
			var j := i - d
			if j < 0:
				if not loop:
					continue
				j += n
			e[i] = (buf[j] + e[j]) * feedback
	for i in n:
		buf[i] += e[i] * mix


func lowpass(cutoff: float) -> void:
	var a := 1.0 - exp(-TAU * cutoff / sr)
	var y := 0.0
	for i in buf.size():
		y += a * (buf[i] - y)
		buf[i] = y


## Normalises to `peak` with gentle saturation, then writes a 16-bit WAV.
func save(path: String, peak := 0.9) -> void:
	var mx := 0.0001
	for v in buf:
		mx = maxf(mx, absf(v))
	var g := peak / mx
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := tanh(buf[i] * g * 1.1) / tanh(1.1)
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	# short fade at the edges of one-shots avoids clicks
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = buf.size()
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	w.save_to_wav(abs_path)
