## The deepening pass: the map, weapons, the Hearthtree, great things, guardian hunts,
## the Undervault's consequences and what keeps a long game going.
extends TestCase

var tree_root: Node


func setup_tree(n: Node) -> void:
	tree_root = n


# --- the map ---------------------------------------------------------------------------

func test_the_map_marker_never_reaches_past_its_diamond() -> void:
	var c := Vector2(50, 50)
	for mine in [true, false]:
		for r in [2.5, 3.0, 4.0]:
			var shapes := Minimap.player_mark(c, r, mine)
			eq(shapes.size(), 3 if mine else 2, "outline, fill%s" % (" and a heart" if mine else ""))
			for poly: PackedVector2Array in shapes:
				for pt in poly:
					check(pt.distance_to(c) <= r + 1.01, "nothing sticks out of the marker (%.1f at r %.1f)" % [pt.distance_to(c), r])


func test_the_map_does_not_draw_where_a_kindled_looks() -> void:
	var src := FileAccess.get_file_as_string("res://src/ui/minimap.gd")
	check(not src.contains(".look"), "the map never reads a Kindled's facing")
	check(not src.contains("draw_line(at"), "and draws no line out of a marker")
