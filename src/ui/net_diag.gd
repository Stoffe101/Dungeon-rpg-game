## Co-op network overlay (F3, or the `netdiag` dev arg): the link to the host,
## traffic, snapshot loss and how far behind the floor is drawn, and how often
## the prediction of this machine's Kindled had to be corrected. The host sees
## each client's link instead.
##
## `netlog=<file>` writes the per-second figures and a summary to that file
## (JSON), for the measured table in docs/NETWORK.md.
class_name NetDiag
extends PanelContainer

var _label: Label
var _t := 0.0
var _log_path := ""
var _rows: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-4, 4)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.78)
	sb.set_content_margin_all(4)
	add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.9))
	add_child(_label)
	var args := Dev.args()
	visible = "netdiag" in args
	for a in args:
		if a.begins_with("netlog="):
			_log_path = a.substr(7)


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F3:
		visible = not visible


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	if not Net.active():
		if visible:
			_label.text = "net: offline"
		return
	var n := Net.i
	var s := n.stats
	var lines: Array = []
	if Net.is_host():
		lines.append("HOST  %d in party" % Net.party_size())
		lines.append("out %.1f KB/s  in %.1f KB/s  snaps %.1f KB/s" % [
			float(s.get("wire_out", 0)) / 1024.0, float(s.get("wire_in", 0)) / 1024.0, float(s.get("snap_out", 0)) / 1024.0])
		for pid in n.roster.keys():
			if int(pid) == 1:
				continue
			var l := n.link_of(int(pid))
			var saves := 0
			if n.run_sync and n.run_sync.stage:
				for pl in n.run_sync.stage.players:
					if pl.peer_id == int(pid):
						saves = pl.lag_saves
			lines.append("%s: rtt %d ms  loss %.1f%%  throttle %d  late saves %d" % [Net.name_of(int(pid)), int(l.get("rtt", 0)),
				float(l.get("loss", 0.0)) * 100.0, int(l.get("throttle", 0)), saves])
		lines.append("inputs in %.0f/s" % float(s.get("in_msgs", 0)))
	else:
		var d: Dictionary = n.run_sync.diag if n.run_sync else {}
		lines.append("CLIENT  rtt %d ms  jitter %d ms" % [int(n.rtt * 1000.0), int(n.jitter * 1000.0)])
		if n.sim_rtt > 0.0 or n.sim_loss > 0.0:
			lines.append("netsim %d ms  %.1f%% loss  %d ms jitter" % [int(n.sim_rtt * 1000.0), n.sim_loss * 100.0, int(n.sim_jitter * 1000.0)])
		lines.append("down %.1f KB/s  up %.1f KB/s" % [float(s.get("wire_in", 0)) / 1024.0, float(s.get("wire_out", 0)) / 1024.0])
		lines.append("snaps %.0f/s  loss %.1f%%  inputs %.0f/s" % [float(s.get("snaps", 0)), float(d.get("loss", 0.0)) * 100.0, float(s.get("in_out", 0))])
		lines.append("drawn %d ms behind" % int(d.get("delay", 0.0)))
		lines.append("prediction: err %.3f avg (%.3f untouched)  %.3f max tiles" % [float(d.get("err_avg", 0.0)), float(d.get("err_free", 0.0)), float(d.get("err_max", 0.0))])
		lines.append("  %.1f slides/s  %.1f jumps/s" % [float(d.get("fixes", 0.0)), float(d.get("jumps", 0.0))])
		if _log_path != "" and n.run_sync:
			_rows.append({"rtt": n.rtt, "jitter": n.jitter, "in_kbs": float(s.get("wire_in", 0)) / 1024.0,
				"out_kbs": float(s.get("wire_out", 0)) / 1024.0, "snaps": float(s.get("snaps", 0)), "loss": d.get("loss", 0.0),
				"delay": d.get("delay", 0.0), "err_avg": d.get("err_avg", 0.0), "err_free": d.get("err_free", 0.0), "err_p50": d.get("err_p50", 0.0), "err_p95": d.get("err_p95", 0.0), "err_max": d.get("err_max", 0.0),
				"fixes": d.get("fixes", 0.0), "jumps": d.get("jumps", 0.0)})
			if _rows.size() % 20 == 0:
				_write_log()
	if visible:
		_label.text = "\n".join(lines)


func _exit_tree() -> void:
	_write_log()


## The rows (four a second) and their averages, for tools/dev/netsim_matrix.
func _write_log() -> void:
	if _log_path == "" or _rows.is_empty():
		return
	var sum := {}
	for r in _rows:
		for k in r:
			sum[k] = float(sum.get(k, 0.0)) + float(r[k])
	var avg := {}
	for k in sum:
		avg[k] = float(sum[k]) / _rows.size()
	var worst := 0.0
	for r in _rows:
		worst = maxf(worst, float(r.err_max))
	avg["err_worst"] = worst
	var f := FileAccess.open(_log_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"samples": _rows.size(), "avg": avg, "netsim": [Net.i.sim_rtt, Net.i.sim_loss, Net.i.sim_jitter] if Net.i else []}, "  "))
