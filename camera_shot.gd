@tool
class_name CameraShot
extends Resource

## Un plan de caméra : le cadre à montrer, le temps pour y aller et le temps
## qu'on y reste. Joué par un CameraDirector, dans une CameraSequence.
## Le cadre est un rectangle dans le repère du parent de la Camera2D : le
## zoom est calculé pour qu'il tienne en entier dans la fenêtre, centré.

## Cadre montré (repère du parent de la caméra, en pixels).
@export var frame: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
## Temps pour aller du cadre précédent à celui-ci (s ; 0 : coupe nette).
@export_range(0.0, 10.0, 0.05, "or_greater") var blend_time: float = 0.6
## Temps passé sur ce cadre une fois arrivé (s). 0 sur le dernier plan d'une
## séquence (pas une cinématique) : on y reste jusqu'à stop() (sortie de la
## zone). 0 ailleurs : on passe au plan suivant dès l'arrivée.
@export_range(0.0, 60.0, 0.05, "or_greater") var hold_time: float = 1.5
@export var transition: Tween.TransitionType = Tween.TRANS_SINE
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT


static func make(shot_frame: Rect2, blend: float, hold: float) -> CameraShot:
	var shot: CameraShot = CameraShot.new()
	shot.frame = shot_frame
	shot.blend_time = blend
	shot.hold_time = hold
	return shot
