@tool
class_name CameraTrigger
extends Area2D

## Zone qui lance une CameraSequence quand un corps y entre (2D ; en 3D :
## CameraTrigger3D).
## - Séquence : arrêtée quand le corps sort de la zone.
## - Cinématique (sequence.takes_control) : jouée jusqu'au bout, même si le
##   corps sort.
## Le director est celui de la caméra 2D en cours (CameraDirector.current()),
## ou celui réglé dans director. Forme : un CollisionShape2D enfant, ou
## set_rect().
## Dans l'éditeur, les cadres des plans sont dessinés (repère global, comme
## si le parent de la caméra était à l'origine) avec leur numéro.

## Groupe de toutes les zones (2D et 3D) de la partie.
const GROUP: StringName = &"camera_triggers"
## Couleur des cadres dessinés dans l'éditeur.
const FRAME_COLOR: Color = Color(0.95, 0.75, 0.25, 0.9)

## Suite jouée à l'entrée.
@export var sequence: CameraSequence:
	set(value):
		sequence = value
		queue_redraw()
## Une seule fois : ne rejoue plus après la première entrée (rearm() la rend).
@export var once: bool = false
## Groupe des corps qui déclenchent (vide : tout corps du masque).
@export var body_group: StringName = &""
## Director piloté ; vide : celui de la caméra en cours.
var director: CameraDirector = null
## Déjà jouée (once).
var spent: bool = false

var _playing_on: CameraDirector = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Forme rectangulaire [param rect] (repère de la zone).
func set_rect(rect: Rect2) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.get_center()
	add_child(collision)


## Peut rejouer (once).
func rearm() -> void:
	spent = false


func _accepts(body: Node) -> bool:
	return sequence != null and (body_group == &"" or body.is_in_group(body_group))


func _on_body_entered(body: Node2D) -> void:
	if spent or not _accepts(body):
		return
	var target: CameraDirector = director if director != null else CameraDirector.current(get_viewport())
	if target != null and target.play(sequence):
		_playing_on = target
		if once:
			spent = true


func _on_body_exited(body: Node2D) -> void:
	if not _accepts(body) or sequence.takes_control or _playing_on == null:
		return
	if is_instance_valid(_playing_on):
		_playing_on.stop(sequence)
	_playing_on = null


func _exit_tree() -> void:
	# Zone retirée (niveau refait) : sa séquence s'arrête avec elle.
	if _playing_on != null and is_instance_valid(_playing_on) and not sequence.takes_control:
		_playing_on.stop(sequence)
	_playing_on = null


func _draw() -> void:
	if not Engine.is_editor_hint() or sequence == null:
		return
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	var font: Font = ThemeDB.fallback_font
	var number: int = 0
	for shot: CameraShotBase in sequence.shots:
		number += 1
		if not shot is CameraShot:
			continue
		var frame: Rect2 = (shot as CameraShot).frame
		draw_rect(frame, FRAME_COLOR, false, 2.0)
		draw_string(font, frame.position + Vector2(6.0, 20.0), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, FRAME_COLOR)
