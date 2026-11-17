@tool
class_name CameraShotPoint3D
extends Camera3D

## Un plan 3D réglé à l'œil dans l'éditeur : une Camera3D qu'on place, qu'on
## oriente et qu'on prévisualise (case « Aperçu » de l'éditeur 3D), avec le
## temps du plan. Posé en enfant d'un CameraTrigger3D, il devient un plan de
## sa suite, dans l'ordre des enfants. Ailleurs : to_shot().
## En jeu, il ne devient jamais la caméra en cours.

## Temps pour aller au plan (s ; 0 : coupe nette).
@export_range(0.0, 10.0, 0.05, "or_greater") var blend_time: float = 0.6
## Temps passé sur le plan (s) ; 0 : voir CameraShotBase.hold_time.
@export_range(0.0, 60.0, 0.05, "or_greater") var hold_time: float = 1.5
@export var transition: Tween.TransitionType = Tween.TRANS_SINE
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT


func _ready() -> void:
	if not Engine.is_editor_hint() and is_current():
		# La première Camera3D d'une scène devient la caméra en cours : on la
		# rend à une autre caméra s'il y en a une.
		clear_current(true)


## Plan à la pose (globale) et au champ de vision de ce point.
func to_shot() -> CameraShot3D:
	var shot: CameraShot3D = CameraShot3D.from_camera(self, blend_time, hold_time)
	shot.transition = transition
	shot.easing = easing
	return shot
