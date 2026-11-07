## Dev: a seed for each form a way can take and each event room, so any of them
## can be walked into: `-- sitefind region=ossuary depth=2 quit` prints lines
## `[sites] trial seals seed=4`, used with `route=trial seed=4 warp=objective`.
class_name SiteFinder
extends Node


func _ready() -> void:
	var region := "ossuary"
	var depth := 2
	for a in Dev.args():
		if a.begins_with("region="):
			region = a.substr(7)
		elif a.begins_with("depth="):
			depth = int(a.substr(6))
	for s in range(1, 60):
		if not DungeonGen.route_offer(s, depth).is_empty():
			print("[sites] fork seed=%d: %s" % [s, DungeonGen.route_offer(s, depth)])
			break
	var seen := {}
	for s in range(1, 120):
		var lay := DungeonGen.generate(s, depth, region, false)
		for r in lay.rooms:
			if r.rule != "" and not seen.has(r.rule):
				seen[r.rule] = s
				print("[sites] rule %s seed=%d" % [r.rule, s])
			if r.event != "" and not seen.has(r.event):
				seen[r.event] = s
				print("[sites] event %s seed=%d" % [r.event, s])
	for route in ["trial", "vault", "breach", "lair"]:
		for s in range(1, 300):
			var lay := DungeonGen.generate(s, depth, region, false, route)
			var key := "%s %s" % [route, lay.variant]
			if not seen.has(key):
				seen[key] = s
				print("[sites] %s seed=%d" % [key, s])
	get_tree().quit()
