## Sound effects (pooled players with per-sound rate limiting), music with
## cross-fades, and ambience loops. Buses: Music, SFX, Ambience, UI.
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
## Sounds from licensed packs (gitignored; tools/audio/import_licensed.py).
## A name found here wins over the generated one in SFX_DIR.
const LICENSED_DIR := "res://assets/audio/licensed/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL := 24

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play: Dictionary = {}
var _variants: Dictionary = {}
## Dev `audiolog`: print every sound as it plays (and any name with no file).
var log_sounds := "audiolog" in Dev.args()
var in_sim := false   # the host's world is simulating (its sounds go to the clients too)
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cur: AudioStreamPlayer
var _music_name := ""
var _amb: AudioStreamPlayer
var _amb_name := ""
# a fight's layer, in step with the walking music (`<name>_combat`), and how
# much of it plays (set_intensity: 0 walking, 1 fighting)
var _layer_a: AudioStreamPlayer
var _layer_b: AudioStreamPlayer
var _layer_cur: AudioStreamPlayer
var _intensity := 0.0
var _intensity_to := 0.0
var _sting: AudioStreamPlayer
# warnings that must be heard over everything (enemy wind-ups, guardians,
# Wards): their own voices, never stolen by a crowd of hits
var _prio_players: Array[AudioStreamPlayer] = []
var _prio_next := 0
const PRIO_POOL := 6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX", "Ambience", "UI"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	# a little room reverb on effects sells the crypt
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.55
		rv.damping = 0.6
		rv.wet = 0.12
		rv.dry = 1.0
		AudioServer.add_bus_effect(sfx, rv)
	var mus := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(mus) == 0:
		var mrv := AudioEffectReverb.new()
		mrv.room_size = 0.8
		mrv.damping = 0.4
		mrv.wet = 0.18
		AudioServer.add_bus_effect(mus, mrv)
		# no sub-rumble under the instruments (it masks the fight's thumps)
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 48.0
		AudioServer.add_bus_effect(mus, hp)
	# effects: a gentle compressor so a four-player brawl stays one sound
	if AudioServer.get_bus_effect_count(sfx) == 1:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 3.0
		comp.attack_us = 4000.0
		comp.release_ms = 140.0
		AudioServer.add_bus_effect(sfx, comp)
	# the master never clips, however much happens at once
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, lim)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		add_child(m)
	_layer_a = AudioStreamPlayer.new()
	_layer_b = AudioStreamPlayer.new()
	for m in [_layer_a, _layer_b]:
		m.bus = "Music"
		m.volume_db = -60.0
		add_child(m)
	_sting = AudioStreamPlayer.new()
	_sting.bus = "Music"
	add_child(_sting)
	for i in PRIO_POOL:
		var pp := AudioStreamPlayer.new()
		pp.bus = "SFX"
		add_child(pp)
		_prio_players.append(pp)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Ambience"
	add_child(_amb)
	apply_volumes()
	for a in Dev.args():
		if a.begins_with("audiorec="):
			_record(float(a.substr(9)))


## Dev (`-- audiorec=SECONDS`): records what each bus plays (and the final
## mix) for that long, then writes user://audio_rec/<bus>.wav - stems to
## measure the real mix with tools/audio/analyze.py.
func _record(secs: float) -> void:
	var recs := {}
	for b in ["Master", "Music", "SFX", "Ambience"]:
		var idx := AudioServer.get_bus_index(b)
		var r := AudioEffectRecord.new()
		AudioServer.add_bus_effect(idx, r)
		r.set_recording_active(true)
		recs[b] = r
	print("[audio] recording %d s of every bus" % int(secs))
	get_tree().create_timer(secs, true, false, true).timeout.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://audio_rec"))
		for b in recs:
			var r: AudioEffectRecord = recs[b]
			var w := r.get_recording()
			r.set_recording_active(false)
			if w:
				w.save_to_wav("user://audio_rec/%s.wav" % b)
		print("[audio] stems written to ", ProjectSettings.globalize_path("user://audio_rec")))


func apply_volumes() -> void:
	var map := {"Master": "master_volume", "Music": "music_volume", "SFX": "sfx_volume", "Ambience": "ambience_volume", "UI": "sfx_volume"}
	for bus in map:
		var idx := AudioServer.get_bus_index(bus)
		if idx < 0:
			continue
		var v := float(Settings.get_value(map[bus], 0.8))
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.001)


func _stream(dir: String, sname: String) -> AudioStream:
	var key := dir + sname
	if _cache.has(key):
		return _cache[key]
	var s: AudioStream = null
	for d in ([LICENSED_DIR, dir] if dir == SFX_DIR else [dir]):
		var path: String = d + sname + ".wav"
		if ResourceLoader.exists(path):
			s = load(path)
			break
	_cache[key] = s
	return s


func has_sound(sname: String) -> bool:
	return _stream(SFX_DIR, sname) != null


## How many takes a sound has: "<name>", "<name>_2", "<name>_3"...
func _takes(sname: String) -> int:
	if not _variants.has(sname):
		var n := 1
		while n < 8 and _stream(SFX_DIR, "%s_%d" % [sname, n + 1]) != null:
			n += 1
		_variants[sname] = n
	return _variants[sname]


## Plays a one-shot sound, picking one of its takes at random. `gap_ms` keeps a
## crowd from stacking the same sound (voices use a longer gap).
func play(sname: String, volume_db := 0.0, pitch := 1.0, bus := "SFX", gap_ms := 30) -> void:
	if Net.recording and bus == "SFX" and in_sim:
		Net.rec(["snd", sname, null, volume_db, pitch, Net.actor_peer])
		if Net.actor_peer != 0 and Net.actor_peer != Net.my_id():
			# another Kindled's own sound: heard from where they stand
			volume_db = _volume_at(Net.actor_pos, volume_db - 3.0)
			if is_nan(volume_db):
				return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sname, -100000)) < gap_ms:
		return
	_last_play[sname] = now
	var take := randi() % _takes(sname)
	var s := _stream(SFX_DIR, sname if take == 0 else "%s_%d" % [sname, take + 1])
	if log_sounds:
		print("[audio] %.2f %s%s" % [now / 1000.0, sname, "" if s else " MISSING"])
	if s == null:
		# creature voices are optional (licensed pack); anything else is a bug
		if not sname.begins_with("v_") and not _last_play.has("!" + sname):
			_last_play["!" + sname] = now
			push_warning("Audio: no sound named '%s'" % sname)
		return
	var p := _players[_next]
	if _is_warning(sname):
		p = _prio_players[_prio_next]
		_prio_next = (_prio_next + 1) % PRIO_POOL
	else:
		_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()


## How loud a sound from `at` is where this machine's Kindled stands (NAN: out of earshot).
func _volume_at(at: Vector2, volume_db: float) -> float:
	var st = Game.stage
	if st and st.player:
		var d: float = (st.player.pos as Vector2).distance_to(at)
		if d > 16.0:
			return NAN
		volume_db -= clampf((d - 4.0) * 1.4, 0.0, 18.0)
	return volume_db


## A sound from a place in the world: quieter with distance from the Kindled,
## silent beyond earshot.
func play_at(sname: String, at: Vector2, volume_db := 0.0, pitch := 1.0, gap_ms := 30) -> void:
	if Net.recording:
		Net.rec(["snd", sname, at, volume_db, pitch])
	volume_db = _volume_at(at, volume_db)
	if is_nan(volume_db):
		return
	var was := in_sim
	in_sim = false
	play(sname, volume_db, pitch, "SFX", gap_ms)
	in_sim = was


func ui(sname: String) -> void:
	play(sname, -4.0, 1.0, "UI")


## Sounds that must cut through (they get their own voices).
static func _is_warning(sname: String) -> bool:
	return sname.ends_with("_windup") or sname.begins_with("boss") or sname in ["parry", "perfect", "telegraph", "warden_call", "eclipse"]


static func _loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)


func play_music(mname: String, fade := 1.5) -> void:
	if mname == _music_name:
		return
	_music_name = mname
	var s := _stream(MUSIC_DIR, mname)
	var layer := _stream(MUSIC_DIR, mname + "_combat")
	var old := _music_cur
	var old_layer := _layer_cur
	var nxt := _music_b if _music_cur == _music_a else _music_a
	var nxt_layer := _layer_b if _layer_cur == _layer_a else _layer_a
	if s:
		_loop(s)
		nxt.stream = s
		nxt.volume_db = -40.0
		nxt.play()
		var tw := create_tween()
		tw.tween_property(nxt, "volume_db", 0.0, fade)
		# the fight's layer starts on the same frame (in step) at the
		# intensity of the moment
		if layer:
			_loop(layer)
			nxt_layer.stream = layer
			nxt_layer.volume_db = -60.0
			nxt_layer.play()
	if old and old.playing:
		var tw2 := create_tween()
		tw2.tween_property(old, "volume_db", -40.0, fade)
		tw2.tween_callback(old.stop)
	if old_layer and old_layer.playing:
		var tw3 := create_tween()
		tw3.tween_property(old_layer, "volume_db", -60.0, fade)
		tw3.tween_callback(old_layer.stop)
	_music_cur = nxt
	_layer_cur = nxt_layer if layer else null


## How much of the fight's layer plays over the walking music (0..1). Rises
## in about a second, falls away over a few.
func set_intensity(v: float) -> void:
	_intensity_to = clampf(v, 0.0, 1.0)


## A short phrase over the music (an elite arrives, a room falls quiet).
func sting(sname: String, volume_db := -2.0) -> void:
	var s := _stream(MUSIC_DIR, sname)
	if s == null:
		return
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	_sting.stream = s
	_sting.volume_db = volume_db
	_sting.play()
	if log_sounds:
		print("[audio] %.2f sting %s" % [Time.get_ticks_msec() / 1000.0, sname])


var _duck := 0.0


func _process(delta: float) -> void:
	var rate := 0.9 if _intensity_to > _intensity else 0.3
	_intensity = move_toward(_intensity, _intensity_to, rate * delta)
	# the music steps back (up to 4 dB) while the fight is loud, so blows and
	# warnings sit on top of it; it comes back over a second
	var sfx := AudioServer.get_bus_index("SFX")
	var mus := AudioServer.get_bus_index("Music")
	if sfx >= 0 and mus >= 0:
		var peak := maxf(AudioServer.get_bus_peak_volume_left_db(sfx, 0), AudioServer.get_bus_peak_volume_right_db(sfx, 0))
		var want := clampf((peak + 20.0) / 12.0, 0.0, 1.0) * 4.0
		_duck = move_toward(_duck, want, (30.0 if want > _duck else 4.0) * delta)
		var v := float(Settings.get_value("music_volume", 0.8))
		if v > 0.001:
			AudioServer.set_bus_volume_db(mus, linear_to_db(v) - _duck)
	if _layer_cur and _layer_cur.playing and _music_cur:
		# follows the walking music's own fade too
		var base := db_to_linear(_music_cur.volume_db)
		_layer_cur.volume_db = linear_to_db(maxf(0.0001, _intensity * base))


func stop_music(fade := 1.0) -> void:
	_music_name = ""
	if _layer_cur and _layer_cur.playing:
		var tl := create_tween()
		tl.tween_property(_layer_cur, "volume_db", -60.0, fade)
		tl.tween_callback(_layer_cur.stop)
		_layer_cur = null
	if _music_cur and _music_cur.playing:
		var tw := create_tween()
		tw.tween_property(_music_cur, "volume_db", -40.0, fade)
		tw.tween_callback(_music_cur.stop)


func play_ambience(aname: String) -> void:
	if aname == _amb_name:
		return
	_amb_name = aname
	var s := _stream(MUSIC_DIR, aname)
	if s == null:
		_amb.stop()
		return
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
	_amb.stream = s
	_amb.volume_db = -6.0
	_amb.play()
