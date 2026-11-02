## Sound effects (pooled players with per-sound rate limiting), music with
## cross-fades, and ambience loops. Buses: Music, SFX, Ambience, UI.
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL := 24

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cur: AudioStreamPlayer
var _music_name := ""
var _amb: AudioStreamPlayer
var _amb_name := ""


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
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Ambience"
	add_child(_amb)
	apply_volumes()


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
	var path := dir + sname + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[key] = s
	return s


## Plays a one-shot sound. Variants "<name>_2", "<name>_3"... are picked at random.
func play(sname: String, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sname, -1000)) < 30:
		return
	_last_play[sname] = now
	var s := _stream(SFX_DIR, sname)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()


func ui(sname: String) -> void:
	play(sname, -4.0, 1.0, "UI")


func play_music(mname: String, fade := 1.5) -> void:
	if mname == _music_name:
		return
	_music_name = mname
	var s := _stream(MUSIC_DIR, mname)
	var old := _music_cur
	var nxt := _music_b if _music_cur == _music_a else _music_a
	if s:
		if s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
		nxt.stream = s
		nxt.volume_db = -40.0
		nxt.play()
		var tw := create_tween()
		tw.tween_property(nxt, "volume_db", 0.0, fade)
	if old and old.playing:
		var tw2 := create_tween()
		tw2.tween_property(old, "volume_db", -40.0, fade)
		tw2.tween_callback(old.stop)
	_music_cur = nxt


func stop_music(fade := 1.0) -> void:
	_music_name = ""
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
