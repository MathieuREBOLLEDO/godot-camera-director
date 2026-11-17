@tool
class_name CameraSequence
extends Resource

## Une suite de plans joués par un director : CameraShot (2D, CameraDirector)
## ou CameraShot3D (3D, CameraDirector3D), pas les deux dans une suite.
## - Séquence (takes_control faux) : le joueur garde la main ; le dernier plan
##   avec hold_time 0 reste jusqu'à stop() (par exemple la sortie d'une zone).
## - Cinématique (takes_control vrai) : le joueur perd la main pendant toute
##   la suite (signal control_changed du director) ; elle finit toujours seule
##   après son dernier plan.
## Après la fin, la caméra revient au cadrage de base en release_time.
## to_dict() / from_dict() : la suite en données simples, pour un éditeur de
## niveaux qui garde ses zones dans ses propres fichiers.

@export var shots: Array[CameraShotBase] = []
## Cinématique : le jeu coupe les commandes du joueur tant qu'elle joue.
@export var takes_control: bool = false
## Plusieurs suites en même temps : la plus haute priorité mène (à égalité,
## la plus récente).
@export var priority: int = 0
## Temps pour revenir au cadrage de base à la fin (s ; 0 : coupe nette).
@export_range(0.0, 10.0, 0.05, "or_greater") var release_time: float = 0.6


## Suite en données simples (types de JSON seulement) :
## {"takes_control", "priority", "release", "shots": [plan.to_dict()...]}.
func to_dict() -> Dictionary:
	var list: Array = []
	for shot: CameraShotBase in shots:
		if shot != null:
			list.append(shot.to_dict())
	return {"takes_control": takes_control, "priority": priority, "release": release_time, "shots": list}


## Suite relue depuis [param data] (to_dict()) ; les plans illisibles sont
## sautés.
static func from_dict(data: Dictionary) -> CameraSequence:
	var sequence: CameraSequence = CameraSequence.new()
	sequence.takes_control = bool(data.get("takes_control", false))
	sequence.priority = int(data.get("priority", 0))
	sequence.release_time = float(data.get("release", 0.6))
	var list: Variant = data.get("shots", [])
	if list is Array:
		for item: Variant in list:
			if item is Dictionary:
				var shot: CameraShotBase = CameraShotBase.from_dict(item)
				if shot != null:
					sequence.shots.append(shot)
	return sequence
