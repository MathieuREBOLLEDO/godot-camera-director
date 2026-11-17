class_name CameraTrigger3D
extends Area3D

## Zone 3D qui lance une CameraSequence quand un corps y entre, comme
## CameraTrigger en 2D :
## - Séquence : arrêtée quand le corps sort de la zone.
## - Cinématique (sequence.takes_control) : jouée jusqu'au bout.
## Plans : ceux de sequence ; si la zone a des CameraShotPoint3D enfants, ce
## sont eux, dans l'ordre (la suite donne alors seulement takes_control,
## priority et release_time ; sans suite, une suite neuve).
## Le director est celui de la caméra 3D en cours
## (CameraDirector3D.current()), ou celui réglé dans director. Forme : un
## CollisionShape3D enfant, ou set_box().

## Suite jouée à l'entrée.
@export var sequence: CameraSequence
## Une seule fois : ne rejoue plus après la première entrée (rearm() la rend).
@export var once: bool = false
## Groupe des corps qui déclenchent (vide : tout corps du masque).
@export var body_group: StringName = &""
## Director piloté ; vide : celui de la caméra en cours.
var director: CameraDirector3D = null
## Déjà jouée (once).
var spent: bool = false

var _playing_on: CameraDirector3D = null


func _ready() -> void:
	add_to_group(CameraTrigger.GROUP)
	monitorable = false
	use_shot_points()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Plans relus depuis les CameraShotPoint3D enfants (s'il y en a). À rappeler
## si on en déplace en jeu.
func use_shot_points() -> void:
	var points: Array[CameraShotPoint3D] = []
	for child: Node in get_children():
		if child is CameraShotPoint3D:
			points.append(child)
	if points.is_empty():
		return
	sequence = sequence.duplicate() as CameraSequence if sequence != null else CameraSequence.new()
	var shots: Array[CameraShotBase] = []
	for point: CameraShotPoint3D in points:
		shots.append(point.to_shot())
	sequence.shots = shots


## Forme en boîte [param box] (repère de la zone).
func set_box(box: AABB) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box.size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = box.get_center()
	add_child(collision)


## Peut rejouer (once).
func rearm() -> void:
	spent = false


func _accepts(body: Node) -> bool:
	return sequence != null and (body_group == &"" or body.is_in_group(body_group))


func _on_body_entered(body: Node3D) -> void:
	if spent or not _accepts(body):
		return
	var target: CameraDirector3D = director if director != null else CameraDirector3D.current(get_viewport())
	if target != null and target.play(sequence):
		_playing_on = target
		if once:
			spent = true


func _on_body_exited(body: Node3D) -> void:
	if not _accepts(body) or sequence.takes_control or _playing_on == null:
		return
	if is_instance_valid(_playing_on):
		_playing_on.stop(sequence)
	_playing_on = null


func _exit_tree() -> void:
	if _playing_on != null and is_instance_valid(_playing_on) and not sequence.takes_control:
		_playing_on.stop(sequence)
	_playing_on = null
