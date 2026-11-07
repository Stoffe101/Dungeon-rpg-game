## Dev (`stallog`): takes every slow frame apart. Times each stage of the frame
## from the engine's own signals (process, draw, then whatever is left: presenting
## and waiting on the GPU), asks the renderer what it measured for the window and
## the world viewport, and names what changed that frame, so a stall can be blamed
## on something rather than guessed at.
##
## Args: `stallog` or `stallog=<ms>` (default 30), `stalls=<file>` to also write CSV.
class_name StallProbe
extends Node

var limit_ms := 30.0
var _t_frame := 0
var _t_pre := 0
var _t_post := 0
var _process_us := 0
var _draw_us := 0
var _world_rid: RID
var _was := {}
var _n := 0
var _slow := 0
var _worst := 0.0
var _file: FileAccess

const WATCH := {
	"nodes": Performance.OBJECT_NODE_COUNT,
	"objs": Performance.OBJECT_COUNT,
	"res": Performance.OBJECT_RESOURCE_COUNT,
	"tex_mem": Performance.RENDER_TEXTURE_MEM_USED,
	"buf_mem": Performance.RENDER_BUFFER_MEM_USED,
	"vid_mem": Performance.RENDER_VIDEO_MEM_USED,
	"static": Performance.MEMORY_STATIC,
	"pipe_canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
	"pipe_mesh": Performance.PIPELINE_COMPILATIONS_MESH,
	"pipe_surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"pipe_draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"pipe_spec": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000
	for a in Dev.args():
		if a.begins_with("stallog="):
			limit_ms = float(a.substr(8))
		elif a.begins_with("stalls="):
			_file = FileAccess.open("user://" + a.substr(7), FileAccess.WRITE)
			if _file:
				_file.store_line("frame,ms,process,draw,present,cpu_win,gpu_win,cpu_world,gpu_world,notes")
	Dev.marking = true
	Events.room_cleared.connect(func(id: int) -> void: Dev.mark("room_cleared %d" % id))
	Events.banner.connect(func(t: String, _s: String) -> void: Dev.mark("banner " + t))
	Events.toast.connect(func(t: String, _c: Color) -> void: Dev.mark("toast " + t.substr(0, 24)))
	get_tree().process_frame.connect(_on_process_frame)
	RenderingServer.frame_pre_draw.connect(_on_pre)
	RenderingServer.frame_post_draw.connect(_on_post)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for k in WATCH:
		_was[k] = Performance.get_monitor(WATCH[k])


func _on_pre() -> void:
	_t_pre = Time.get_ticks_usec()
	_process_us = _t_pre - _t_frame


func _on_post() -> void:
	_t_post = Time.get_ticks_usec()
	_draw_us = _t_post - _t_pre


func _on_process_frame() -> void:
	var now := Time.get_ticks_usec()
	if _t_frame > 0:
		_measure(now)
	_t_frame = now
	if not _world_rid.is_valid():
		var v: PixelView = Game.view if "view" in Game else null
		if v and v.viewport:
			_world_rid = v.viewport.get_viewport_rid()
			RenderingServer.viewport_set_measure_render_time(_world_rid, true)


func _measure(now: int) -> void:
	_n += 1
	var ms := (now - _t_frame) / 1000.0
	var notes: Array = []
	for k in WATCH:
		var v: float = Performance.get_monitor(WATCH[k])
		var d: float = v - float(_was[k])
		_was[k] = v
		if d == 0.0 or ms < limit_ms:
			continue
		if k.ends_with("_mem") or k == "static":
			if absf(d) > 262144.0:
				notes.append("%s%+.1fMB" % [k, d / 1048576.0])
		else:
			notes.append("%s%+d" % [k, d])
	if ms < limit_ms:
		Dev.take_marks()
		return
	_slow += 1
	_worst = maxf(_worst, ms)
	var root := get_viewport().get_viewport_rid()
	var cw := RenderingServer.viewport_get_measured_render_time_cpu(root)
	var gw := RenderingServer.viewport_get_measured_render_time_gpu(root)
	var cv := RenderingServer.viewport_get_measured_render_time_cpu(_world_rid) if _world_rid.is_valid() else 0.0
	var gv := RenderingServer.viewport_get_measured_render_time_gpu(_world_rid) if _world_rid.is_valid() else 0.0
	var marks := Dev.take_marks()
	var present := maxf(0.0, (now - _t_post) / 1000.0)
	print("[stall] %.0f ms at %.2f s  process %.1f  draw %.1f  present %.1f  win cpu %.1f gpu %.1f  world cpu %.1f gpu %.1f  %s  %s" % [ms, Time.get_ticks_msec() / 1000.0,
		_process_us / 1000.0, _draw_us / 1000.0, present, cw, gw, cv, gv, " ".join(PackedStringArray(notes)), ", ".join(PackedStringArray(marks))])
	if _file:
		_file.store_line("%d,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%s" % [_n, ms, _process_us / 1000.0, _draw_us / 1000.0, present, cw, gw, cv, gv, " ".join(PackedStringArray(notes + marks))])
		_file.flush()


func _exit_tree() -> void:
	print("[stall] %d frames, %d over %.0f ms, worst %.0f ms" % [_n, _slow, limit_ms, _worst])
