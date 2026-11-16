class_name CameraDirector
extends Node

## Prend la main sur une Camera2D pour jouer des suites de plans
## (CameraSequence), puis la rend à son cadrage de base (set_base()).
## À poser en enfant de la Camera2D (ou régler camera). Plusieurs suites
## peuvent jouer ensemble : la plus prioritaire mène, les autres attendent
## (leur plan en cours reprend quand elles repassent devant).
## Le jeu donne le cadrage de base (set_base()) ; tant qu'aucune suite ne joue
## et qu'aucun retour n'est en cours, le director ne touche pas à la caméra.
## Une cinématique (takes_control) émet control_changed(true), puis
## control_changed(false) quand plus aucune ne joue : au jeu de couper et
## rendre les commandes.

## Une suite commence (play()).
signal sequence_started(sequence: CameraSequence)
## Une suite est finie : dernier plan joué, ou stop().
signal sequence_finished(sequence: CameraSequence)
## La suite qui mène passe à un plan (index dans sequence.shots).
signal shot_changed(sequence: CameraSequence, index: int)
## Une cinématique prend la main (vrai) ou plus aucune ne la tient (faux).
signal control_changed(taken: bool)

## Caméra pilotée ; vide : le parent, si c'est une Camera2D.
@export var camera: Camera2D
## Zoom des plans arrondi à l'entier en dessous (pixels nets), à partir de 1.
@export var integer_zoom: bool = false
## Coupé : play() ne lance plus rien (les suites en cours continuent).
@export var enabled: bool = true

## Cadrage de base : position de la caméra (repère de son parent) et zoom.
var base_position: Vector2 = Vector2.ZERO
var base_zoom: Vector2 = Vector2.ONE

var _active: Array[CameraSequence] = [] # dans l'ordre d'arrivée
var _index: Dictionary = {} # CameraSequence -> plan en cours (int)
var _hold: Dictionary = {} # CameraSequence -> temps restant sur ce plan (s)
var _leading: CameraSequence = null
var _release_time: float = 0.0 # retour à la base de la dernière suite menée
var _tween: Tween
var _control_taken: bool = false


func _ready() -> void:
	if camera == null:
		camera = get_parent() as Camera2D


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


## Lance [param sequence] ; faux si elle joue déjà, est vide ou si le
## director est coupé.
func play(sequence: CameraSequence) -> bool:
	if not enabled or sequence == null or sequence.shots.is_empty() or _active.has(sequence):
		return false
	_active.append(sequence)
	_index[sequence] = -1
	_hold[sequence] = 0.0
	sequence_started.emit(sequence)
	_refresh()
	return true


## Arrête [param sequence] (rien si elle ne joue pas).
func stop(sequence: CameraSequence) -> void:
	if not _active.has(sequence):
		return
	_active.erase(sequence)
	_index.erase(sequence)
	_hold.erase(sequence)
	if sequence == _leading:
		_release_time = sequence.release_time
	sequence_finished.emit(sequence)
	_refresh()


## Arrête tout et remet la caméra à sa base sans transition (mort, changement
## d'écran).
func stop_all() -> void:
	var stopped: Array[CameraSequence] = _active.duplicate()
	_active.clear()
	_index.clear()
	_hold.clear()
	_leading = null
	if _tween != null:
		_tween.kill()
		_tween = null
	if camera != null:
		camera.position = base_position
		camera.zoom = base_zoom
	for sequence: CameraSequence in stopped:
		sequence_finished.emit(sequence)
	_update_control()


func is_playing(sequence: CameraSequence) -> bool:
	return _active.has(sequence)


## Suite qui mène (null : caméra à sa base, ou en train d'y revenir).
func leading() -> CameraSequence:
	return _leading


## Plan en cours de la suite qui mène (-1 sans suite).
func leading_shot() -> int:
	return _index.get(_leading, -1) if _leading != null else -1


## Une cinématique tient-elle la main ?
func is_control_taken() -> bool:
	return _control_taken


## Suites en cours, dans l'ordre d'arrivée.
func active() -> Array[CameraSequence]:
	return _active.duplicate()


## Position et zoom qui montrent [param frame] en entier, centré.
func view_for(frame: Rect2) -> Dictionary:
	var view: Vector2 = camera.get_viewport_rect().size if camera != null and camera.is_inside_tree() else frame.size
	var zoom: float = 1.0
	if frame.size.x > 0.0 and frame.size.y > 0.0:
		zoom = minf(view.x / frame.size.x, view.y / frame.size.y)
	if integer_zoom and zoom >= 1.0:
		zoom = floorf(zoom)
	return {"position": frame.get_center(), "zoom": Vector2(zoom, zoom)}


## État lisible (debug).
func describe() -> String:
	if _active.is_empty():
		return "base" + (" (returning)" if _moving() else "")
	var lines: PackedStringArray = []
	for sequence: CameraSequence in _active:
		var kind: String = "cutscene" if sequence.takes_control else "sequence"
		var mark: String = "> " if sequence == _leading else "  "
		lines.append("%s%s %s, shot %d/%d" % [mark, kind, _name_of(sequence), _index[sequence] + 1, sequence.shots.size()])
	return "\n".join(lines)


func _process(delta: float) -> void:
	if _leading == null or _moving():
		return
	var sequence: CameraSequence = _leading
	var index: int = _index[sequence]
	var shot: CameraShot = sequence.shots[index]
	var last: bool = index == sequence.shots.size() - 1
	# Dernier plan d'une séquence sans durée : on attend stop().
	if last and shot.hold_time <= 0.0 and not sequence.takes_control:
		return
	_hold[sequence] = (_hold[sequence] as float) - delta
	if _hold[sequence] > 0.0:
		return
	if last:
		stop(sequence)
	else:
		_index[sequence] = index + 1
		_start_shot(sequence)


# La suite qui mène a peut-être changé : on va à son plan, ou à la base.
func _refresh() -> void:
	_update_control()
	var top: CameraSequence = null
	for sequence: CameraSequence in _active:
		if top == null or sequence.priority >= top.priority:
			top = sequence
	if top == _leading:
		return
	if _leading != null and _active.has(_leading):
		_release_time = _leading.release_time
	_leading = top
	if top == null:
		_move_to(base_position, base_zoom, _release_time, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		return
	if _index[top] < 0:
		_index[top] = 0
		_start_shot(top)
	else:
		# Reprise : on retourne à son plan, le temps restant est gardé.
		var shot: CameraShot = top.shots[_index[top]]
		var view: Dictionary = view_for(shot.frame)
		_move_to(view["position"], view["zoom"], shot.blend_time, shot.transition, shot.easing)


func _start_shot(sequence: CameraSequence) -> void:
	var index: int = _index[sequence]
	var shot: CameraShot = sequence.shots[index]
	_hold[sequence] = shot.hold_time
	var view: Dictionary = view_for(shot.frame)
	_move_to(view["position"], view["zoom"], shot.blend_time, shot.transition, shot.easing)
	shot_changed.emit(sequence, index)


func _move_to(position: Vector2, zoom: Vector2, time: float, trans: Tween.TransitionType, easing: Tween.EaseType) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if camera == null:
		return
	if time <= 0.0 or not is_inside_tree():
		camera.position = position
		camera.zoom = zoom
		return
	_tween = create_tween().set_parallel().set_trans(trans).set_ease(easing)
	_tween.tween_property(camera, "position", position, time)
	_tween.tween_property(camera, "zoom", zoom, time)


func _moving() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func _update_control() -> void:
	var taken: bool = _active.any(func(sequence: CameraSequence) -> bool: return sequence.takes_control)
	if taken != _control_taken:
		_control_taken = taken
		control_changed.emit(taken)


static func _name_of(sequence: CameraSequence) -> String:
	if sequence.resource_name != "":
		return sequence.resource_name
	return sequence.resource_path.get_file() if sequence.resource_path != "" else "#%d" % sequence.get_instance_id()
