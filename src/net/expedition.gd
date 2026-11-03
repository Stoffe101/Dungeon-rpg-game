## The party agrees on an expedition before going down together.
##
## Anyone in the party may propose one from the Undervault Gate (region, tier,
## Omens: their choice). Everyone else gets the request on screen wherever they
## are - walking the camp, in the satchel, at the Hearthtree - and answers Ready
## or Not now (Y / N, or the buttons). The proposer counts as ready. When every
## member present is ready, a short countdown runs (anyone can still say Not
## now), then the host leads the whole party down. The proposer (or the host)
## can withdraw it, and proposing again replaces it (a changed plan asks
## everyone again). Someone leaving drops out of it; the proposer leaving ends
## it. One proposal at a time: a second one is turned away.
##
## The host keeps the one true proposal (Net.i.proposal on every machine is a
## copy it sends out); every request is checked there, so a repeated or late
## answer changes nothing.
class_name Expedition
extends RefCounted

const COUNTDOWN := 3.0      # seconds between "everyone is ready" and the descent
const LAPSE := 240.0        # an unanswered proposal goes out on its own after this


# --- this machine ---------------------------------------------------------------------

## The local player proposes (or changes their proposal).
static func request(region: String, tier: int, omens: Array) -> void:
	if not Net.active():
		return
	if Net.is_host():
		propose(1, region, tier, omens)
	else:
		Net.i.to_host("_propose", [region, tier, omens])


## The local player answers the open proposal.
static func reply(yes: bool) -> void:
	var p := Net.i.proposal
	if p.is_empty():
		return
	if Net.is_host():
		answer(1, int(p.id), yes)
	else:
		Net.i.to_host("_answer", [int(p.id), yes])


## The local player takes back their proposal (the host may end anyone's).
static func withdraw() -> void:
	var p := Net.i.proposal
	if p.is_empty():
		return
	if Net.is_host():
		cancel(1, int(p.id))
	else:
		Net.i.to_host("_withdraw", [int(p.id)])


## What this machine's player said ("yes", "no" or "" for not yet).
static func my_answer() -> String:
	var p := Net.i.proposal
	if p.is_empty():
		return ""
	return String((p.answers as Dictionary).get(Net.my_id(), ""))


## A line naming the expedition: "The Ossuary  -  Tier II  -  2 Omens".
static func describe(p: Dictionary) -> String:
	var region := String(p.get("region", "ossuary"))
	var name := Delve.NAME if region == "delve" else String(EnemyDB.REGIONS.get(region, {}).get("name", region))
	var bits := [name, "Tier %s" % Difficulty.roman(int(p.get("tier", 1)))]
	var om: Array = p.get("omens", [])
	if not om.is_empty():
		bits.append(Omens.names(om))
	return "  -  ".join(PackedStringArray(bits))


# --- the host's side ------------------------------------------------------------------

static var _n := 0
static var _made := 0.0       # host seconds when the proposal was made
static var _launch_at := -1.0 # host seconds when the party goes down (-1: not counting)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func propose(by: int, region: String, tier: int, omens: Array) -> void:
	if not Net.is_host():
		return
	var cur := Net.i.proposal
	if not cur.is_empty() and int(cur.by) != by:
		_tell(by, "%s has already proposed an expedition. Answer theirs, or ask them to withdraw it." % Net.name_of(int(cur.by)))
		return
	if Game.run != null or Game.transitioning:
		_tell(by, "The party is already on its way down.")
		return
	if region != "delve" and not EnemyDB.REGIONS.has(region):
		return
	_n += 1
	var answers := {}
	for pid in Net.i.present():
		answers[int(pid)] = ""
	answers[by] = "yes"
	Net.i.proposal = {"id": _n, "by": by, "region": region, "tier": maxi(1, tier), "omens": omens.duplicate(),
		"answers": answers, "launch_in": -1.0}
	_made = _now()
	_launch_at = -1.0
	print("[net] %s proposes: %s" % [Net.name_of(by), describe(Net.i.proposal)])
	_check()
	_send()


static func answer(pid: int, id: int, yes: bool) -> void:
	var p := Net.i.proposal
	if p.is_empty() or int(p.id) != id or not (p.answers as Dictionary).has(pid):
		return
	var was := String(p.answers[pid])
	var now := "yes" if yes else "no"
	if was == now:
		return
	p.answers[pid] = now
	if not yes and _launch_at >= 0.0:
		_launch_at = -1.0
		p["launch_in"] = -1.0
	print("[net] %s answers the proposal: %s" % [Net.name_of(pid), now])
	_check()
	_send()


static func cancel(pid: int, id: int) -> void:
	var p := Net.i.proposal
	if p.is_empty() or int(p.id) != id:
		return
	if pid != int(p.by) and pid != 1:
		return
	_end("%s withdrew the expedition." % Net.name_of(pid))


## Host, every frame: the countdown, and a proposal nobody finished answering.
static func tick() -> void:
	var p := Net.i.proposal
	if p.is_empty() or not Net.is_host():
		return
	if _launch_at >= 0.0 and _now() >= _launch_at:
		_launch(p)
	elif _launch_at < 0.0 and _now() - _made > LAPSE:
		_end("The expedition proposal lapsed.")


## Host: the party changed (someone left or arrived) while a proposal is open.
static func on_roster() -> void:
	var p := Net.i.proposal
	if p.is_empty() or not Net.is_host():
		return
	var here: Array = Net.i.present()
	if not here.has(int(p.by)):
		_end("%s left: their expedition is off." % Net.name_of(int(p.by)))
		return
	var answers: Dictionary = p.answers
	for pid in answers.keys():
		if not here.has(int(pid)):
			answers.erase(pid)
	for pid in here:
		if not answers.has(int(pid)):
			answers[int(pid)] = ""
			if _launch_at >= 0.0:
				_launch_at = -1.0     # a newcomer gets to answer first
				p["launch_in"] = -1.0
	_check()
	_send()


static func _check() -> void:
	var p := Net.i.proposal
	if p.is_empty():
		return
	for pid in p.answers:
		if String(p.answers[pid]) != "yes":
			return
	if _launch_at < 0.0:
		_launch_at = _now() + COUNTDOWN
		p["launch_in"] = COUNTDOWN
		print("[net] everyone is ready: the party goes down in %.0f s" % COUNTDOWN)


static func _launch(p: Dictionary) -> void:
	Net.i.proposal = {}
	_launch_at = -1.0
	_send()
	print("[net] the party goes down: %s" % describe(p))
	Game.begin_descent(String(p.region), int(p.tier), p.omens)


static func _end(why: String) -> void:
	Net.i.proposal = {}
	_launch_at = -1.0
	print("[net] proposal ended: ", why)
	_send()
	Net.i.rpc("_tell", why, Color(1.0, 0.75, 0.55))
	if Game.ui:
		Game.ui.toast(why, Color(1.0, 0.75, 0.55))


static func _send() -> void:
	Net.i.rpc("_proposal", Net.i.proposal)
	Net.i.proposal_changed.emit()


static func _tell(pid: int, text: String) -> void:
	if pid == Net.my_id():
		if Game.ui:
			Game.ui.toast(text, Color(1.0, 0.75, 0.55))
	else:
		Net.i.rpc_id(pid, "_tell", text, Color(1.0, 0.75, 0.55))
