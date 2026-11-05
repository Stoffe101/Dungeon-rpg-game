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
const GenRootmire = preload("res://tools/art/gen_rootmire.gd")
const GenItems = preload("res://tools/art/gen_items.gd")
const GenThrone = preload("res://tools/art/gen_throne.gd")
const GenCreatures = preload("res://tools/art/gen_creatures.gd")
const GenSatchel = preload("res://tools/art/gen_satchel.gd")
const GenCampLife = preload("res://tools/art/gen_camp_life.gd")
const GenDressing = preload("res://tools/art/gen_dressing.gd")
const GenWave2 = preload("res://tools/art/gen_wave2.gd")
const GenGear = preload("res://tools/art/gen_gear.gd")
const GenBuilds = preload("res://tools/art/gen_builds.gd")
const GenWorkshop = preload("res://tools/art/gen_workshop.gd")
const GenDepths = preload("res://tools/art/gen_depths.gd")
const GenLandmarks = preload("res://tools/art/gen_landmarks.gd")
const GenForms = preload("res://tools/art/gen_forms.gd")
const GenUniques = preload("res://tools/art/gen_uniques.gd")
const GenRoutes = preload("res://tools/art/gen_routes.gd")


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
		"hub": func():
			GenHub.build("res://assets/sprites")
			GenCampLife.build("res://assets/sprites"),
		"icons": func(): GenIcons.build("res://assets/sprites"),
		"ui": func():
			GenUI.build("res://assets/ui")
			GenSatchel.build("res://assets/ui"),
		"rootmire": func(): GenRootmire.build("res://assets/sprites"),
		"items": func(): GenItems.build("res://assets/sprites"),
		"throne": func():
			GenThrone.build_tiles("res://assets/textures")
			GenThrone.build("res://assets/sprites"),
		"creatures": func(): GenCreatures.build("res://assets/sprites"),
		"dressing": func(): GenDressing.build("res://assets/sprites"),
		"wave2": func(): GenWave2.build("res://assets/sprites"),
		"gear": func(): GenGear.build("res://assets/sprites"),
		"builds": func(): GenBuilds.build("res://assets/sprites"),
		"workshop": func(): GenWorkshop.build("res://assets/sprites"),
		"depths": func(): GenDepths.build("res://assets/textures"),
		"landmarks": func(): GenLandmarks.build("res://assets/sprites"),
		"forms": func(): GenForms.build("res://assets/sprites"),
		"uniques": func(): GenUniques.build("res://assets/sprites"),
		"routes": func(): GenRoutes.build("res://assets/sprites"),
	}
	for k in jobs:
		if only.is_empty() or k in only:
			var t0 := Time.get_ticks_msec()
			jobs[k].call()
			print("  built %-10s %5d ms" % [k, Time.get_ticks_msec() - t0])
	print("Art build done in %d ms" % (Time.get_ticks_msec() - t))
	quit()
