class_name CameraDirector
extends CameraDirectorBase

## Prend la main sur une Camera2D pour jouer des suites de plans 2D
## (CameraSequence de CameraShot), puis la rend à son cadrage de base
## (set_base()). À poser en enfant de la Camera2D (ou régler camera).
## Le jeu donne le cadrage de base (set_base()) ; tant qu'aucune suite ne joue
## et qu'aucun retour n'est en cours, le director ne touche pas à la caméra.
## File des suites, priorités et prise de main : CameraDirectorBase. En 3D :
## CameraDirector3D.

## Caméra pilotée ; vide : le parent, si c'est une Camera2D.
@export var camera: Camera2D
## Zoom des plans arrondi à l'entier en dessous (pixels nets), à partir de 1.
@export var integer_zoom: bool = false

## Cadrage de base : position de la caméra (repère de son parent) et zoom.
var base_position: Vector2 = Vector2.ZERO
var base_zoom: Vector2 = Vector2.ONE


func _ready() -> void:
	if camera == null:
		camera = get_parent() as Camera2D
	super()


## Director de [param cam] (son enfant), ou null.
static func of(cam: Camera2D) -> CameraDirector:
	if cam == null:
		return null
	for child: Node in cam.get_children():
		if child is CameraDirector:
			return child
	return null


## Director de la caméra 2D en cours de [param viewport], ou null.
static func current(viewport: Viewport) -> CameraDirector:
	return of(viewport.get_camera_2d()) if viewport != null else null


## Cadrage rendu quand aucune suite ne joue. Appliqué tout de suite si la
## caméra est libre.
func set_base(position: Vector2, zoom: Vector2) -> void:
	base_position = position
	base_zoom = zoom
	if _leading == null and not _moving() and camera != null:
		camera.position = position
		camera.zoom = zoom


## Position et zoom qui montrent [param frame] en entier, centré.
func view_for(frame: Rect2) -> Dictionary:
	var view: Vector2 = camera.get_viewport_rect().size if camera != null and camera.is_inside_tree() else frame.size
	var zoom: float = 1.0
	if frame.size.x > 0.0 and frame.size.y > 0.0:
		zoom = minf(view.x / frame.size.x, view.y / frame.size.y)
	if integer_zoom and zoom >= 1.0:
		zoom = floorf(zoom)
	return {"position": frame.get_center(), "zoom": Vector2(zoom, zoom)}


func _accepts_shot(shot: CameraShotBase) -> bool:
	return shot is CameraShot


func _go_to_shot(shot: CameraShotBase) -> void:
	var view: Dictionary = view_for((shot as CameraShot).frame)
	_move_to(view["position"], view["zoom"], shot.blend_time, shot.transition, shot.easing)


func _go_to_base(time: float) -> void:
	_move_to(base_position, base_zoom, time, Tween.TRANS_SINE, Tween.EASE_IN_OUT)


func _snap_to_base() -> void:
	if camera != null:
		camera.position = base_position
		camera.zoom = base_zoom


func _move_to(position: Vector2, zoom: Vector2, time: float, trans: Tween.TransitionType, easing: Tween.EaseType) -> void:
	_kill_tween()
	if camera == null:
		return
	var tween: Tween = _new_tween(trans, easing) if time > 0.0 else null
	if tween == null:
		camera.position = position
		camera.zoom = zoom
		return
	tween.tween_property(camera, "position", position, time)
	tween.tween_property(camera, "zoom", zoom, time)
