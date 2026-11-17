class_name CameraDirectorBase
extends Node

## Ce qu'ont en commun CameraDirector (2D) et CameraDirector3D : la file des
## suites (CameraSequence), leurs priorités, le temps sur chaque plan, la
## prise de main d'une cinématique. Chaque director dit seulement comment
## aller à un plan et revenir à la base (_go_to_shot(), _go_to_base(),
## _snap_to_base(), _accepts_shot()).
## Plusieurs suites peuvent jouer ensemble : la plus prioritaire mène, les
## autres attendent (leur plan en cours reprend quand elles repassent devant).
## Une cinématique (takes_control) émet control_changed(true), puis
## control_changed(false) quand plus aucune ne joue : au jeu de couper et
## rendre les commandes.
## Les directors sont dans le groupe GROUP ; le premier prêt ajoute le menu
## Camera au debug menu s'il y en a un (CameraDebug).

## Groupe de tous les directors de la partie.
const GROUP: StringName = &"camera_directors"

## Une suite commence (play()).
signal sequence_started(sequence: CameraSequence)
## Une suite est finie : dernier plan joué, ou stop().
signal sequence_finished(sequence: CameraSequence)
## La suite qui mène passe à un plan (index dans sequence.shots).
signal shot_changed(sequence: CameraSequence, index: int)
## Une cinématique prend la main (vrai) ou plus aucune ne la tient (faux).
signal control_changed(taken: bool)

## Coupé : play() ne lance plus rien (les suites en cours continuent).
@export var enabled: bool = true

var _active: Array[CameraSequence] = [] # dans l'ordre d'arrivée
var _index: Dictionary = {} # CameraSequence -> plan en cours (int)
var _hold: Dictionary = {} # CameraSequence -> temps restant sur ce plan (s)
var _leading: CameraSequence = null
var _release_time: float = 0.0 # retour à la base de la dernière suite menée
var _tween: Tween
var _control_taken: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	CameraDebug.register(self)
	if not CameraDebug.zones_on:
		enabled = false # case du debug menu décochée avant ce director


## Lance [param sequence] ; faux si elle joue déjà, est vide, a un plan que
## ce director ne sait pas jouer (un plan 3D en 2D...) ou si le director est
## coupé.
func play(sequence: CameraSequence) -> bool:
	if not enabled or sequence == null or sequence.shots.is_empty() or _active.has(sequence):
		return false
	for shot: CameraShotBase in sequence.shots:
		if shot == null or not _accepts_shot(shot):
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
	_kill_tween()
	_snap_to_base()
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


## Vrai pendant une transition (vers un plan ou vers la base).
func is_moving() -> bool:
	return _moving()


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


# --- À redéfinir par chaque director ---

## Ce director sait-il jouer [param shot] ?
func _accepts_shot(_shot: CameraShotBase) -> bool:
	return false


## Va au plan [param shot] en shot.blend_time (_new_tween() pour animer).
func _go_to_shot(_shot: CameraShotBase) -> void:
	pass


## Revient au cadrage de base en [param time] secondes (plus aucune suite).
func _go_to_base(_time: float) -> void:
	pass


## Remet le cadrage de base tout de suite (stop_all()).
func _snap_to_base() -> void:
	pass


# --- Commun ---

func _process(delta: float) -> void:
	if _leading == null or _moving():
		return
	var sequence: CameraSequence = _leading
	var index: int = _index[sequence]
	var shot: CameraShotBase = sequence.shots[index]
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
		_go_to_base(_release_time)
		return
	if _index[top] < 0:
		_index[top] = 0
		_start_shot(top)
	else:
		# Reprise : on retourne à son plan, le temps restant est gardé.
		_go_to_shot(top.shots[_index[top]])


func _start_shot(sequence: CameraSequence) -> void:
	var index: int = _index[sequence]
	var shot: CameraShotBase = sequence.shots[index]
	_hold[sequence] = shot.hold_time
	_go_to_shot(shot)
	shot_changed.emit(sequence, index)


## Nouveau tween du director (l'ancien est arrêté) ; null hors de l'arbre.
func _new_tween(trans: Tween.TransitionType, easing: Tween.EaseType) -> Tween:
	_kill_tween()
	if not is_inside_tree():
		return null
	_tween = create_tween().set_parallel().set_trans(trans).set_ease(easing)
	return _tween


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


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
