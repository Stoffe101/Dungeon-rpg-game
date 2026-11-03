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


## The dev arguments after `--` (none in a release build).
static func args() -> PackedStringArray:
	return OS.get_cmdline_user_args() if enabled() else PackedStringArray()
