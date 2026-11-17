@tool
class_name CameraShotBase
extends Resource

## Ce qu'ont tous les plans, en 2D (CameraShot) comme en 3D (CameraShot3D) :
## le temps pour y aller, le temps qu'on y reste et la courbe du mouvement.
## Une CameraSequence en contient une suite.

## Temps pour aller du cadre précédent à celui-ci (s ; 0 : coupe nette).
@export_range(0.0, 10.0, 0.05, "or_greater") var blend_time: float = 0.6
## Temps passé sur ce cadre une fois arrivé (s). 0 sur le dernier plan d'une
## séquence (pas une cinématique) : on y reste jusqu'à stop() (sortie de la
## zone). 0 ailleurs : on passe au plan suivant dès l'arrivée.
@export_range(0.0, 60.0, 0.05, "or_greater") var hold_time: float = 1.5
@export var transition: Tween.TransitionType = Tween.TRANS_SINE
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT


## Plan en données simples (JSON) : voir CameraSequence.to_dict().
func to_dict() -> Dictionary:
	return {"blend": blend_time, "hold": hold_time, "transition": int(transition), "easing": int(easing)}


## Plan relu depuis [param data] (CameraShot si « kind » vaut « 2d » ou
## manque, CameraShot3D si « 3d ») ; null si les données sont fausses.
static func from_dict(data: Dictionary) -> CameraShotBase:
	var shot: CameraShotBase = null
	match String(data.get("kind", "2d")):
		"2d":
			shot = CameraShot.read(data)
		"3d":
			shot = CameraShot3D.read(data)
	if shot == null:
		return null
	shot.blend_time = float(data.get("blend", shot.blend_time))
	shot.hold_time = float(data.get("hold", shot.hold_time))
	shot.transition = int(data.get("transition", shot.transition)) as Tween.TransitionType
	shot.easing = int(data.get("easing", shot.easing)) as Tween.EaseType
	return shot
