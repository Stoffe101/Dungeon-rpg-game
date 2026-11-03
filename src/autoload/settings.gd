## Player-facing options, persisted to user://settings.cfg, plus the default
## input bindings (defined in code so they can be rebound and reset).
extends Node

signal changed(key: String)
signal device_changed(pad: bool)

const PATH := "user://settings.cfg"
const DEV_PATH := "user://settings_dev.cfg"   # dev runs (profile=...) never touch the player's settings

var path := PATH

const DEFAULTS := {
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"ambience_volume": 0.7,
	"ui_scale": 0,           # 0 = automatic
	"pixel_scale": 0,        # 0 = automatic (world pixel size)
	"window_mode": "windowed",
	"vsync": true,
	"max_fps": 0,
	"screen_shake": 1.0,
	"hitstop": true,
	"reduce_flashes": false,
	"effects_intensity": 1.0,
	"damage_numbers": true,
	"show_fps": false,
	"aim_assist": 0.5,
	"rumble": 1.0,
}

## action -> list of default events
var DEFAULT_BINDINGS := {
	"move_up": [_key(KEY_W), _key(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)],
	"move_down": [_key(KEY_S), _key(KEY_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)],
	"move_left": [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)],
	"move_right": [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)],
	"aim_up": [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0)],
	"aim_down": [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)],
	"aim_left": [_joy_axis(JOY_AXIS_RIGHT_X, -1.0)],
	"aim_right": [_joy_axis(JOY_AXIS_RIGHT_X, 1.0)],
	"attack": [_mouse(MOUSE_BUTTON_LEFT), _joy_button(JOY_BUTTON_RIGHT_SHOULDER), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
	"ward": [_mouse(MOUSE_BUTTON_RIGHT), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
	"dodge": [_key(KEY_SPACE), _key(KEY_SHIFT), _joy_button(JOY_BUTTON_A)],
	"ability_1": [_key(KEY_Q), _joy_button(JOY_BUTTON_X)],
	"ability_2": [_key(KEY_E), _joy_button(JOY_BUTTON_Y)],
	"flask": [_key(KEY_R), _joy_button(JOY_BUTTON_LEFT_SHOULDER)],
	"interact": [_key(KEY_F), _joy_button(JOY_BUTTON_B)],
	"map": [_key(KEY_TAB), _joy_button(JOY_BUTTON_BACK)],
	"pause": [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_START)],
	"inventory": [_key(KEY_I), _joy_button(JOY_BUTTON_RIGHT_STICK)],
	"hearthcall": [_key(KEY_H), _joy_button(JOY_BUTTON_LEFT_STICK)],
	"debug_menu": [_key(KEY_F1)],
	"screenshot": [_key(KEY_F12)],
}

var values: Dictionary = {}
var bindings_override: Dictionary = {}
var using_pad := false   # last meaningful input came from a gamepad


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("profile="):
			path = DEV_PATH
	values = DEFAULTS.duplicate(true)
	load_settings()
	apply_bindings()
	get_window().size_changed.connect(_on_window_resized)
	apply_all.call_deferred()


## Tracks whether the player is on a gamepad or keyboard/mouse so prompts and
## menus can follow the device in hand.
func _input(e: InputEvent) -> void:
	var pad := using_pad
	if e is InputEventJoypadButton and e.pressed:
		pad = true
	elif e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) > 0.5:
		pad = true
	elif (e is InputEventKey and e.pressed) or (e is InputEventMouseButton and e.pressed):
		pad = false
	elif e is InputEventMouseMotion and (e as InputEventMouseMotion).relative.length() > 6.0:
		pad = false
	if pad != using_pad:
		using_pad = pad
		device_changed.emit(pad)


## Controller vibration, scaled by the rumble setting; only while a pad is in use.
func rumble(weak: float, strong: float, seconds: float) -> void:
	var k := float(values.get("rumble", 1.0))
	if k <= 0.0 or not using_pad or (weak <= 0.0 and strong <= 0.0):
		return
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, clampf(weak * k, 0.0, 1.0), clampf(strong * k, 0.0, 1.0), seconds)


func get_value(key: String, fallback: Variant = null) -> Variant:
	return values.get(key, DEFAULTS.get(key, fallback))


func set_value(key: String, v: Variant, persist := true) -> void:
	values[key] = v
	_apply(key)
	changed.emit(key)
	if persist:
		save_settings()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	for k in DEFAULTS:
		if cf.has_section_key("options", k):
			var v: Variant = cf.get_value("options", k)
			if typeof(v) == typeof(DEFAULTS[k]) or (typeof(DEFAULTS[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				values[k] = v
	if cf.has_section("bindings"):
		for action in cf.get_section_keys("bindings"):
			var evs: Variant = cf.get_value("bindings", action)
			if evs is Array:
				bindings_override[action] = evs


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("options", k, values[k])
	for a in bindings_override:
		cf.set_value("bindings", a, bindings_override[a])
	cf.save(path)


func apply_all() -> void:
	for k in values:
		_apply(k)


func _apply(key: String) -> void:
	match key:
		"master_volume", "music_volume", "sfx_volume", "ambience_volume":
			if has_node("/root/Audio"):
				get_node("/root/Audio").apply_volumes()
		"window_mode":
			if DisplayServer.get_name() == "headless":
				return
			match String(values.window_mode):
				"fullscreen":
					get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
				"borderless":
					get_window().mode = Window.MODE_FULLSCREEN
				_:
					if get_window().mode != Window.MODE_WINDOWED:
						get_window().mode = Window.MODE_WINDOWED
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
		"max_fps":
			Engine.max_fps = int(values.max_fps)
		"ui_scale", "pixel_scale":
			_on_window_resized()


## UI scale: integer factor applied to all 2D interface content.
func effective_ui_scale() -> int:
	var forced := int(values.get("ui_scale", 0))
	if forced > 0:
		return forced
	var h := get_window().size.y
	return maxi(1, int(floor(h / 360.0)))


func _on_window_resized() -> void:
	var s := effective_ui_scale()
	if get_window().content_scale_factor != s:
		get_window().content_scale_factor = s
	var pv := get_tree().get_first_node_in_group("pixel_view")
	if pv:
		pv.relayout()


# --- Input bindings ---------------------------------------------------------

func apply_bindings() -> void:
	for action in DEFAULT_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.35)
		InputMap.action_erase_events(action)
		var evs: Array = DEFAULT_BINDINGS[action]
		if bindings_override.has(action):
			evs = []
			for d in bindings_override[action]:
				var e := _deserialize(d)
				if e:
					evs.append(e)
		for e in evs:
			InputMap.action_add_event(action, e)
	# Godot's built-in menu actions have no face buttons: A confirms, B backs out
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var jb := _joy_button(pair[1])
		if not InputMap.action_has_event(pair[0], jb):
			InputMap.action_add_event(pair[0], jb)


## Replaces the action's first binding of the same device family as `ev`
## (keyboard/mouse or gamepad), keeping the other family untouched.
func rebind(action: String, ev: InputEvent) -> void:
	var pad := is_pad_event(ev)
	var cur: Array = []
	var replaced := false
	for e in InputMap.action_get_events(action):
		if not replaced and is_pad_event(e) == pad:
			cur.append(_serialize(ev))
			replaced = true
		else:
			cur.append(_serialize(e))
	if not replaced:
		cur.append(_serialize(ev))
	bindings_override[action] = cur.filter(func(d): return not d.is_empty())
	apply_bindings()
	save_settings()


func reset_bindings() -> void:
	bindings_override.clear()
	apply_bindings()
	save_settings()


## Short label for an action's binding on the given device family
## (default: the device currently in use), falling back to the other family.
func describe_action(action: String, pad: Variant = null) -> String:
	var want: bool = using_pad if pad == null else bool(pad)
	var fallback := "-"
	if not InputMap.has_action(action):
		return fallback
	for e in InputMap.action_get_events(action):
		var s := event_label(e)
		if s == "":
			continue
		if is_pad_event(e) == want:
			return s
		if fallback == "-":
			fallback = s
	return fallback


static func is_pad_event(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or e is InputEventJoypadMotion


const PAD_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_GUIDE: "Home",
	JOY_BUTTON_DPAD_UP: "D-Up", JOY_BUTTON_DPAD_DOWN: "D-Down",
	JOY_BUTTON_DPAD_LEFT: "D-Left", JOY_BUTTON_DPAD_RIGHT: "D-Right",
}


static func event_label(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		return OS.get_keycode_string(k.physical_keycode if k.physical_keycode != 0 else k.keycode)
	if e is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}.get((e as InputEventMouseButton).button_index, "Mouse")
	if e is InputEventJoypadButton:
		return PAD_BUTTONS.get((e as InputEventJoypadButton).button_index, "Btn %d" % (e as InputEventJoypadButton).button_index)
	if e is InputEventJoypadMotion:
		match (e as InputEventJoypadMotion).axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return "L-Stick"
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				return "R-Stick"
	return ""


# Bindings match every device (-1), so a pad that registers as device 1 works too.
static func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.device = -1
	return e


static func _mouse(b: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	e.device = -1
	return e


static func _joy_button(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.device = -1
	return e


static func _joy_axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	e.device = -1
	return e


static func _serialize(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		return {"t": "key", "k": int(e.physical_keycode)}
	if e is InputEventMouseButton:
		return {"t": "mouse", "b": int(e.button_index)}
	if e is InputEventJoypadButton:
		return {"t": "jb", "b": int(e.button_index)}
	if e is InputEventJoypadMotion:
		return {"t": "ja", "a": int(e.axis), "v": float(e.axis_value)}
	return {}


static func _deserialize(d: Dictionary) -> InputEvent:
	match d.get("t", ""):
		"key":
			return _key(int(d.k))
		"mouse":
			return _mouse(int(d.b))
		"jb":
			return _joy_button(int(d.b))
		"ja":
			return _joy_axis(int(d.a), float(d.v))
	return null
