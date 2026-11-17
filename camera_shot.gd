@tool
class_name CameraShot
extends CameraShotBase

## Un plan de caméra 2D : le cadre à montrer, le temps pour y aller et le
## temps qu'on y reste. Joué par un CameraDirector, dans une CameraSequence.
## Le cadre est un rectangle dans le repère du parent de la Camera2D : le
## zoom est calculé pour qu'il tienne en entier dans la fenêtre, centré.

## Cadre montré (repère du parent de la caméra, en pixels).
@export var frame: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)


static func make(shot_frame: Rect2, blend: float, hold: float) -> CameraShot:
	var shot: CameraShot = CameraShot.new()
	shot.frame = shot_frame
	shot.blend_time = blend
	shot.hold_time = hold
	return shot


func to_dict() -> Dictionary:
	var data: Dictionary = super()
	data["kind"] = "2d"
	data["frame"] = [frame.position.x, frame.position.y, frame.size.x, frame.size.y]
	return data


## Cadre lu dans [param data] (« frame » : [x, y, largeur, hauteur]) ; null
## s'il manque. Le temps est lu par CameraShotBase.from_dict().
static func read(data: Dictionary) -> CameraShot:
	var values: Variant = data.get("frame")
	if not values is Array or (values as Array).size() != 4:
		return null
	var f: Array = values
	return make(Rect2(float(f[0]), float(f[1]), float(f[2]), float(f[3])), 0.6, 1.5)
