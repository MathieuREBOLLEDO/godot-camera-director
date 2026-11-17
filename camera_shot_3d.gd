@tool
class_name CameraShot3D
extends CameraShotBase

## Un plan de caméra 3D : la pose de la caméra (position et orientation,
## repère global) et son champ de vision. Joué par un CameraDirector3D,
## dans une CameraSequence. Pour le régler à l'œil dans l'éditeur : poser
## un CameraShotPoint3D (une Camera3D qu'on peut prévisualiser) sous un
## CameraTrigger3D, ou appeler from_camera().

## Pose de la caméra (repère global).
@export var transform: Transform3D = Transform3D.IDENTITY
## Champ de vision vertical (degrés).
@export_range(1.0, 179.0, 0.1, "degrees") var fov: float = 75.0
## Plan vivant (following()) : caméra relue à chaque image (pose, fov,
## décalages h_offset / v_offset), même si elle bouge ou s'anime. Pas
## enregistré (un nœud) : transform et fov gardent la pose du moment.
var source: Camera3D = null


static func make(pose: Transform3D, view_fov: float, blend: float, hold: float) -> CameraShot3D:
	var shot: CameraShot3D = CameraShot3D.new()
	shot.transform = pose
	shot.fov = view_fov
	shot.blend_time = blend
	shot.hold_time = hold
	return shot


## Plan placé en [param from], tourné vers [param target] (repère global).
static func looking(from: Vector3, target: Vector3, view_fov: float, blend: float, hold: float) -> CameraShot3D:
	var pose: Transform3D = Transform3D(Basis.IDENTITY, from)
	if not from.is_equal_approx(target):
		var up: Vector3 = Vector3.UP if absf((target - from).normalized().dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
		pose = pose.looking_at(target, up)
	return make(pose, view_fov, blend, hold)


## Plan qui reprend la pose et le champ de vision de [param camera].
static func from_camera(camera: Camera3D, blend: float, hold: float) -> CameraShot3D:
	return make(camera.global_transform, camera.fov, blend, hold)


## Plan vivant sur [param camera] : le director la suit à chaque image (une
## caméra de jeu animée, une caméra qui vise une cible qui bouge).
static func following(camera: Camera3D, blend: float, hold: float) -> CameraShot3D:
	var shot: CameraShot3D = from_camera(camera, blend, hold)
	shot.source = camera
	return shot


## Caméra suivie, si c'est un plan vivant et qu'elle est encore là.
func live_source() -> Camera3D:
	return source if is_instance_valid(source) and source.is_inside_tree() else null


func to_dict() -> Dictionary:
	var data: Dictionary = super()
	var turn: Quaternion = transform.basis.get_rotation_quaternion()
	data["kind"] = "3d"
	data["origin"] = [transform.origin.x, transform.origin.y, transform.origin.z]
	data["rotation"] = [turn.x, turn.y, turn.z, turn.w]
	data["fov"] = fov
	return data


## Pose lue dans [param data] (« origin » [x, y, z], « rotation »
## quaternion [x, y, z, w], « fov ») ; null si « origin » manque.
static func read(data: Dictionary) -> CameraShot3D:
	var origin: Variant = data.get("origin")
	if not origin is Array or (origin as Array).size() != 3:
		return null
	var o: Array = origin
	var turn: Quaternion = Quaternion.IDENTITY
	var rotation: Variant = data.get("rotation")
	if rotation is Array and (rotation as Array).size() == 4:
		var r: Array = rotation
		turn = Quaternion(float(r[0]), float(r[1]), float(r[2]), float(r[3])).normalized()
	var pose: Transform3D = Transform3D(Basis(turn), Vector3(float(o[0]), float(o[1]), float(o[2])))
	return make(pose, float(data.get("fov", 75.0)), 0.6, 1.5)
