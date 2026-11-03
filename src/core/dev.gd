## Development switches. Dev command-line arguments (`-- scene=dungeon godmode
## rich unlock=all netsim=...`) and the testing stockpile only work in debug
## builds (the editor, `--path .` runs, debug exports): a release export
## ignores them, so nothing meant for testing reaches players.
class_name Dev
extends RefCounted


static func enabled() -> bool:
	return OS.is_debug_build()


## The dev arguments after `--` (none in a release build).
static func args() -> PackedStringArray:
	return OS.get_cmdline_user_args() if enabled() else PackedStringArray()
