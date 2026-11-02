## Projection conventions shared by simulation and presentation.
##
## Gameplay runs on a flat 2D plane measured in tiles (Vector2: x = east, y = south).
## The 3D presentation uses an orthographic camera pitched 45 degrees. World depth (z)
## and height (y) are both stretched by sqrt(2), so after projection one tile of floor,
## one tile of wall height and one tile of width all cover exactly PPU screen pixels.
## That keeps pixel art 1:1 while still giving us real 3D lights, shadows and depth.
class_name Iso
extends RefCounted

const PPU := 16.0
const SQ2 := 1.4142135623730951
const TEXEL := 1.0 / PPU
const CAMERA_PITCH_DEG := -45.0
const CAMERA_DISTANCE := 40.0


static func to_world(p: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(p.x, height * SQ2, p.y * SQ2)


static func to_plane(w: Vector3) -> Vector2:
	return Vector2(w.x, w.z / SQ2)


## Height in tiles of a world-space point.
static func height_of(w: Vector3) -> float:
	return w.y / SQ2


## Basis for a SpriteLib quad (which is pre-stretched by sqrt(2) vertically)
## that lies parallel to the camera plane and is rotated by `screen_angle`
## (radians, counter-clockwise on screen). Use for spinning sprites: weapons,
## arrows, bolts.
static func screen_basis(screen_angle: float, flip_y := false) -> Basis:
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(CAMERA_PITCH_DEG))
	var rot := Basis(Vector3.BACK, screen_angle)
	var unscale := Basis.from_scale(Vector3(1.0, (-1.0 if flip_y else 1.0) / SQ2, 1.0))
	return tilt * rot * unscale


## Screen-space angle (counter-clockwise, y up) of a plane direction.
static func screen_angle(dir: Vector2) -> float:
	return -atan2(dir.y, dir.x)
