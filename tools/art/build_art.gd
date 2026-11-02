## Regenerates every procedural art asset.
## Usage: godot --headless --path . -s res://tools/art/build_art.gd [-- only=player,tiles]
extends SceneTree

const FontGen = preload("res://tools/art/font_gen.gd")
const GenTiles = preload("res://tools/art/gen_tiles.gd")
const GenPlayer = preload("res://tools/art/gen_player.gd")
const GenEnemies = preload("res://tools/art/gen_enemies.gd")
const GenBoss = preload("res://tools/art/gen_boss.gd")
const GenProps = preload("res://tools/art/gen_props.gd")
const GenHub = preload("res://tools/art/gen_hub.gd")
const GenIcons = preload("res://tools/art/gen_icons.gd")
const GenUI = preload("res://tools/art/gen_ui.gd")


func _init() -> void:
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5).split(",")
	var t := Time.get_ticks_msec()
	var jobs := {
		"font": func(): FontGen.build("res://assets/fonts"),
		"tiles": func(): GenTiles.build("res://assets/textures"),
		"player": func(): GenPlayer.build("res://assets/sprites"),
		"enemies": func(): GenEnemies.build("res://assets/sprites"),
		"boss": func(): GenBoss.build("res://assets/sprites"),
		"props": func(): GenProps.build("res://assets/sprites"),
		"hub": func(): GenHub.build("res://assets/sprites"),
		"icons": func(): GenIcons.build("res://assets/sprites"),
		"ui": func(): GenUI.build("res://assets/ui"),
	}
	for k in jobs:
		if only.is_empty() or k in only:
			var t0 := Time.get_ticks_msec()
			jobs[k].call()
			print("  built %-10s %5d ms" % [k, Time.get_ticks_msec() - t0])
	print("Art build done in %d ms" % (Time.get_ticks_msec() - t))
	quit()
