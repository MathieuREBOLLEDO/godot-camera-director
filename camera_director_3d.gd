class_name CameraDirector3D
extends CameraDirectorBase

## Joue des suites de plans 3D (CameraSequence de CameraShot3D) puis rend la
## main à la Camera3D du jeu. À poser en enfant de la Camera3D (ou régler
## camera).
## En 3D, la caméra du jeu bouge d'elle-même (tête du joueur, bras de
## suivi...) : le director ne la déplace donc jamais. Il a sa propre caméra
## (rig), qui part de la caméra en cours et devient la caméra en cours le
## temps des plans. Au retour, le rig rejoint la pose de la caméra du jeu là
## où elle est à chaque image (même si elle bouge), puis lui rend la main
## (make_current()). La base, c'est donc la caméra du jeu elle-même : rien à
## régler (pas de set_base()).
## File des suites, priorités et prise de main : CameraDirectorBase.

## Caméra du jeu rendue à la fin ; vide : le parent, si c'est une Camera3D.
@export var camera: Camera3D

## Caméra du director, en cours pendant les plans (créée dans _ready()).
var rig: Camera3D

var _driving: bool = false
var _from: Transform3D
var _from_fov: float = 75.0
var _from_offset: Vector2 = Vector2.ZERO # h_offset, v_offset
var _to: Transform3D
var _to_fov: float = 75.0
var _to_base: bool = false # le but est la caméra du jeu, relue à chaque image
var _to_source: Camera3D = null # plan vivant : caméra relue à chaque image


func _ready() -> void:
	if camera == null:
		camera = get_parent() as Camera3D
	rig = Camera3D.new()
	rig.name = "DirectorRig"
	add_child(rig)
	rig.clear_current(false)
	super()


## Director de [param cam] (son enfant, ou cam est son rig), ou null.
static func of(cam: Camera3D) -> CameraDirector3D:
	if cam == null:
		return null
	if cam.get_parent() is CameraDirector3D and (cam.get_parent() as CameraDirector3D).rig == cam:
		return cam.get_parent()
	for child: Node in cam.get_children():
		if child is CameraDirector3D:
			return child
	return null


## Director de la caméra 3D en cours de [param viewport], ou null.
static func current(viewport: Viewport) -> CameraDirector3D:
	return of(viewport.get_camera_3d()) if viewport != null else null


## Vrai tant que le rig est la caméra en cours (plans ou retour).
func is_driving() -> bool:
	return _driving


func _accepts_shot(shot: CameraShotBase) -> bool:
	return shot is CameraShot3D


func _go_to_shot(shot: CameraShotBase) -> void:
	var shot_3d: CameraShot3D = shot as CameraShot3D
	_take_over()
	var source: Camera3D = shot_3d.live_source()
	if source != null:
		rig.near = minf(rig.near, source.near)
	_blend(shot_3d.transform, shot_3d.fov, source, false, shot.blend_time, shot.transition, shot.easing)


func _go_to_base(time: float) -> void:
	if _driving:
		_blend(Transform3D.IDENTITY, 0.0, null, true, time, Tween.TRANS_SINE, Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	super(delta)
	# Arrivé sur un plan vivant : on reste collé à sa caméra.
	if _driving and not _moving() and not _to_base and is_instance_valid(_to_source):
		_apply(1.0)


func _snap_to_base() -> void:
	_give_back()


# Le rig part de la caméra en cours (celle du jeu, ou une autre qu'il a mise)
# et en prend les réglages de rendu.
func _take_over() -> void:
	if _driving or rig == null or not rig.is_inside_tree():
		return
	var from: Camera3D = get_viewport().get_camera_3d()
	if from == null or from == rig:
		from = camera
	var model: Camera3D = camera if camera != null else from
	if model != null:
		rig.environment = model.environment
		rig.attributes = model.attributes
		rig.cull_mask = model.cull_mask
		rig.near = model.near
		rig.far = model.far
		rig.keep_aspect = model.keep_aspect
		rig.h_offset = model.h_offset
		rig.v_offset = model.v_offset
	if from != null and from.is_inside_tree():
		rig.global_transform = from.global_transform
		rig.fov = from.fov
	rig.make_current()
	_driving = true


func _give_back() -> void:
	_kill_tween()
	if not _driving:
		return
	_driving = false
	if camera != null and camera.is_inside_tree():
		camera.make_current()
	elif rig != null and rig.is_inside_tree():
		rig.clear_current(true)


func _blend(to: Transform3D, to_fov: float, source: Camera3D, to_base: bool, time: float, trans: Tween.TransitionType, easing: Tween.EaseType) -> void:
	_from = rig.global_transform
	_from_fov = rig.fov
	_from_offset = Vector2(rig.h_offset, rig.v_offset)
	_to = to
	_to_fov = to_fov
	_to_source = source
	_to_base = to_base
	if to_base and (camera == null or not camera.is_inside_tree()):
		_give_back()
		return
	var tween: Tween = _new_tween(trans, easing) if time > 0.0 else null
	if tween == null:
		_apply(1.0)
		if to_base:
			_give_back()
		return
	tween.tween_method(_apply, 0.0, 1.0, time)
	if to_base:
		tween.finished.connect(_give_back)


func _apply(weight: float) -> void:
	if rig == null or not rig.is_inside_tree():
		return
	var target: Transform3D = _to
	var target_fov: float = _to_fov
	var target_offset: Vector2 = Vector2.ZERO
	var live: Camera3D = camera if _to_base else _to_source
	if is_instance_valid(live) and live.is_inside_tree():
		target = live.global_transform
		target_fov = live.fov
		target_offset = Vector2(live.h_offset, live.v_offset)
	elif _to_base:
		target_offset = _from_offset
	rig.global_transform = _from.interpolate_with(target, weight)
	rig.fov = lerpf(_from_fov, target_fov, weight)
	var offset: Vector2 = _from_offset.lerp(target_offset, weight)
	rig.h_offset = offset.x
	rig.v_offset = offset.y
