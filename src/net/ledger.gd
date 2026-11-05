## The XP ledger: every change to this machine's experience during an
## expedition, with where it came from, written to
## `user://ledger/<run id>_<name>.jsonl` (one JSON object a line). The host also
## writes what it awarded the party (every recipient and the multiplier).
## Two Kindled who played the same run compare their files with
## `python tools/dev/ledger_compare.py a.jsonl b.jsonl`: where their gains part
## ways shows by source. Cheap (lines are buffered and written per floor).
class_name Ledger
extends RefCounted

static var _lines: PackedStringArray = []
static var _run := ""
static var _who := ""
static var enabled := true


## A run starts (or a guest joins one): where this Kindled stands.
static func begin(run_id: String, who: String) -> void:
	if not enabled or run_id == "":
		return
	flush()
	_run = run_id
	_who = who
	_add({"ev": "start", "who": who, "level": Profile.level(), "xp": int(Profile.data.get("xp", 0)), "total": Profile.total_xp(),
		"xp_gain": _my_gain()})


## This machine's own experience changed (Profile.add_xp).
static func xp(source: String, amount: int) -> void:
	if not enabled or _run == "":
		return
	_add({"ev": "xp", "src": source, "n": amount, "level": Profile.level(), "total": Profile.total_xp()})


## The host credited the party (Party.award_xp): base, multiplier, recipients.
static func award(kind: String, source: String, base: int, mult: float, n: int, to: Array) -> void:
	if not enabled or _run == "":
		return
	_add({"ev": "award", "kind": kind, "src": source, "base": base, "mult": snappedf(mult, 0.001), "n": n, "to": to})


## A note (settlement, a rejoin, a floor).
static func note(what: String, extra := {}) -> void:
	if not enabled or _run == "":
		return
	var d := {"ev": what}
	d.merge(extra)
	_add(d)


static func finish(outcome: String) -> void:
	if not enabled or _run == "":
		return
	_add({"ev": "end", "outcome": outcome, "level": Profile.level(), "xp": int(Profile.data.get("xp", 0)), "total": Profile.total_xp()})
	flush()
	_run = ""


static func _add(d: Dictionary) -> void:
	d["t"] = snappedf(Time.get_ticks_msec() / 1000.0, 0.01)
	if Game.run:
		d["depth"] = Game.run.depth
	_lines.append(JSON.stringify(d))
	if _lines.size() >= 200:
		flush()


static func flush() -> void:
	if _lines.is_empty() or _run == "":
		_lines.clear()
		return
	DirAccess.make_dir_recursive_absolute("user://ledger")
	# one file per Kindled per run (two players on one PC keep theirs apart)
	var path := "user://ledger/%s_%s.jsonl" % [_run.validate_filename(), _who.validate_filename()]
	var f := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_lines.clear()
		return
	f.seek_end()
	for l in _lines:
		f.store_line(l)
	f.close()
	_lines.clear()


static func _my_gain() -> float:
	var st := Game.stage
	if st and st.player and st.player.stats:
		return snappedf(st.player.stats.v("xp_gain"), 0.001)
	return 1.0
