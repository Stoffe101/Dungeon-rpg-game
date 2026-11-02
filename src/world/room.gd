## One room of a generated dungeon floor (pure data + runtime state).
class_name Room
extends RefCounted

enum Type { START, COMBAT, ELITE, TREASURE, SHRINE, MERCHANT, REST, SECRET, STAIRS, BOSS, EVENT }

const TYPE_NAMES := {
	Type.START: "start", Type.COMBAT: "combat", Type.ELITE: "elite", Type.TREASURE: "treasure",
	Type.SHRINE: "shrine", Type.MERCHANT: "merchant", Type.REST: "rest", Type.SECRET: "secret",
	Type.STAIRS: "stairs", Type.BOSS: "boss", Type.EVENT: "event",
}

const EVENTS := ["well", "trial", "echo"]

var id := 0
var type := Type.COMBAT
var cells: Array[Vector2i] = []
var rect := Rect2i()                 # floor bounds in tiles
var doors: Array = []                # [{to:int, dir:Vector2i, tiles:Array[Vector2i], secret:bool}]
var reward := ""                     # relic | embers | vigor | sunshard | memory | ""
var spawns: Array[Vector2i] = []     # candidate enemy spawn tiles
var props: Array = []                # [{kind:String, tile:Vector2i, ...}]
var waves := 1
var encounter: Array = []            # enemy ids per wave: [[...], [...]]
var elite_affix := ""
var grudge := false
var event := ""

# runtime
var visited := false
var cleared := false
var active := false


func center() -> Vector2:
	return Vector2(rect.position) + Vector2(rect.size) * 0.5


func contains_tile(t: Vector2i) -> bool:
	return rect.has_point(t)


func is_combat() -> bool:
	return type == Type.COMBAT or type == Type.ELITE or type == Type.BOSS


func type_name() -> String:
	return TYPE_NAMES.get(type, "combat")


func door_to(other: int) -> Dictionary:
	for d in doors:
		if d.to == other:
			return d
	return {}
