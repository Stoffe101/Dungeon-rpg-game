## A sanctuary resident: strolls between favourite spots (sitting at benches and
## the fire), says something when the Kindled walks by, and talks when asked.
## A Prop (so it is interactable and drawn like one) that moves.
class_name Wanderer
extends Prop

const SPEED := 1.25
const BARK_RANGE := 3.0

var def: Dictionary = {}
var spots: Array = []            # shared with the hub: [{p: Vector2, pose: String, tag: String, by: Wanderer}]
var spot := -1
var moving := false
var wait := 0.0
var bark_cd := 0.0
var listen_t := 0.0
var _stuck_t := 0.0
var _last_d := 0.0


static func spawn(st: Stage, d: Dictionary, spot_list: Array, rng: RandomNumberGenerator) -> Wanderer:
	var w := Wanderer.new()
	w.stage = st
	w.kind = "resident"
	w.def = d
	w.spots = spot_list
	w.data = {"prompt": "Talk to %s" % d.name, "id": d.id}
	w.interact_radius = 0.7
	w.ticks = true
	var start := w._pick_spot(rng)
	w.pos = spot_list[start].p if start >= 0 else Vector2(21.0, 15.0)
	w.tile = Vector2i(w.pos)
	st.add_child(w)
	st.props.append(w)
	w._sprite(String(d.sheet), 0.0, 0.0, "idle")
	if d.get("light", false):
		w._light(Color(1.0, 0.62, 0.32), 0.7, 3.5, Vector3(0.3, 0.9, 0.3))
	w._arrive()
	w.wait = rng.randf_range(1.0, 9.0)
	w.refresh_mark()
	w.bark_cd = rng.randf_range(2.0, 12.0)
	return w


func tick(dt: float) -> void:
	_t += dt
	bark_cd -= dt
	if light:
		light.light_energy = _base_energy * (0.85 + 0.15 * sin(_t * 9.0))
	var pl := stage.player
	if listen_t > 0.0:
		# turned toward the Kindled while talking
		listen_t -= dt
		if listen_t <= 0.0:
			if moving:
				sprite.play("walk")
			else:
				_pose_anim()
		return
	if moving:
		_walk(dt)
	else:
		wait -= dt
		if wait <= 0.0:
			_leave()
	if pl and is_instance_valid(pl) and bark_cd <= 0.0 and pos.distance_to(pl.pos) < BARK_RANGE and not (Game.ui and Game.ui.has_modal()):
		var hub := stage as Hub
		if hub == null or hub.may_bark():
			bark_cd = randf_range(28.0, 45.0)
			stage.fx.say(self, head_height(), Residents.bark(String(def.id), stage.rng))


## "!" when they have something to ask, "?" when a request is ready to hand in.
func refresh_mark() -> void:
	match Residents.request_state(String(def.id)):
		"":
			stage.fx.mark(self, head_height() - 0.2, "!", UIKit.C_GOLD)
		"complete":
			stage.fx.mark(self, head_height() - 0.2, "?", UIKit.C_GOLD)
		_:
			stage.fx.unmark(self)


## Where a speech bubble sits: just above the head (children and sitters are lower).
func head_height() -> float:
	var h := 1.5 if def.get("child", false) else 1.9
	if not moving and spot >= 0 and String(spots[spot].pose) == "sit":
		h -= 0.3
	return h


func _walk(dt: float) -> void:
	var goal: Vector2 = spots[spot].p
	var dist := pos.distance_to(goal)
	if dist < 0.12:
		pos = goal
		_arrive()
		return
	var step := stage.path_step(pos, goal)
	var dir := (step - pos).normalized()
	pos = stage.grid.move_box(pos, 0.22, dir * minf(SPEED * dt, dist))
	position = Iso.to_world(pos, 0.0)
	if absf(dir.x) > 0.2:
		sprite.flip_h = dir.x < 0.0
	# give up on a spot that cannot be reached
	_stuck_t = _stuck_t + dt if absf(_last_d - dist) < 0.002 else 0.0
	_last_d = dist
	if _stuck_t > 1.5:
		_stuck_t = 0.0
		_leave()


func _arrive() -> void:
	moving = false
	position = Iso.to_world(pos, 0.0)
	sprite.flip_h = false
	_pose_anim()
	wait = randf_range(7.0, 16.0)


func _pose_anim() -> void:
	var pose := String(spots[spot].pose) if spot >= 0 else "idle"
	sprite.play(pose if sprite.has_anim(pose) else "idle")
	if stage.fx._marks.has(get_instance_id()):
		refresh_mark()


func _leave() -> void:
	if _pick_spot(stage.rng) < 0:
		wait = randf_range(3.0, 6.0)   # everywhere is taken: linger
		return
	moving = true
	_stuck_t = 0.0
	_last_d = 0.0
	sprite.play("walk")


## Picks a free spot, preferring the resident's favourite kinds of place.
func _pick_spot(rng: RandomNumberGenerator) -> int:
	var likes: Array = def.get("likes", [])
	var best := -1
	var best_w := -1.0
	for i in spots.size():
		var s: Dictionary = spots[i]
		if s.get("by") != null and s.by != self:
			continue
		if i == spot:
			continue
		var w := rng.randf() + (1.2 if s.tag in likes else 0.0)
		if w > best_w:
			best_w = w
			best = i
	if best >= 0:
		if spot >= 0:
			spots[spot].by = null
		spots[best].by = self
		spot = best
	return best


## Faces the Kindled and talks (or just listens, once the conversation ends).
func listen(seconds: float, talking := true) -> void:
	listen_t = seconds
	sprite.flip_h = false
	sprite.play("talk" if talking and sprite.has_anim("talk") else "idle")
	# the dialogue pauses the world; the speaker keeps moving their lips
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS if talking else Node.PROCESS_MODE_INHERIT
