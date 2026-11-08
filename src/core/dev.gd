## Development switches. Dev command-line arguments (`-- scene=dungeon godmode
## rich unlock=all netsim=...`) and the testing stockpile only work in debug
## builds (the editor, `--path .` runs, debug exports): a release export
## ignores them, so nothing meant for testing reaches players.
class_name Dev
extends RefCounted


static func enabled() -> bool:
	return OS.is_debug_build()


## Dev (src/dev/scenario.gd): where the scenario's pointer is, in the root's
## canvas coordinates (the window reads the real OS cursor, which a scripted
## click does not move). Unset (x < 0) everywhere else.
static var mouse := Vector2(-1, -1)


## The mouse over the world: the real pointer, or the scenario's.
static func mouse_at(view: Control) -> Vector2:
	return mouse if mouse.x >= 0.0 and enabled() else view.get_global_mouse_position()


## Dev (`stallog`): what happened this frame, for StallProbe to name beside a
## slow one. Off (and free) unless the probe is running.
static var marking := false
static var _marks: Array = []


static func mark(what: String) -> void:
	if marking and _marks.size() < 16:
		_marks.append(what)


## A timed mark: what took `since` (ticks usec) this long, if it was long enough
## to matter. Use: `var t := Dev.tick()` ... `Dev.lap("what", t)`.
static func tick() -> int:
	return Time.get_ticks_usec() if marking else 0


static func lap(what: String, since: int, min_ms := 2.0) -> void:
	if marking and since > 0:
		var ms := (Time.get_ticks_usec() - since) / 1000.0
		if ms >= min_ms:
			mark("%s %.0fms" % [what, ms])


static func take_marks() -> Array:
	var out := _marks
	_marks = []
	return out


## The dev arguments after `--` (none in a release build).
## A background run (tools/dev/bg.py): never touch the window, the real cursor or focus.
static func background() -> bool:
	return args().has("bg")


static func args() -> PackedStringArray:
	return OS.get_cmdline_user_args() if enabled() else PackedStringArray()
