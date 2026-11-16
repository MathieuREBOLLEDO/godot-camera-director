@tool
class_name CameraSequence
extends Resource

## Une suite de plans (CameraShot) jouée par un CameraDirector.
## - Séquence (takes_control faux) : le joueur garde la main ; le dernier plan
##   avec hold_time 0 reste jusqu'à stop() (par exemple la sortie d'une zone).
## - Cinématique (takes_control vrai) : le joueur perd la main pendant toute
##   la suite (signal control_changed du director) ; elle finit toujours seule
##   après son dernier plan.
## Après la fin, la caméra revient au cadrage de base en release_time.

@export var shots: Array[CameraShot] = []
## Cinématique : le jeu coupe les commandes du joueur tant qu'elle joue.
@export var takes_control: bool = false
## Plusieurs suites en même temps : la plus haute priorité mène (à égalité,
## la plus récente).
@export var priority: int = 0
## Temps pour revenir au cadrage de base à la fin (s ; 0 : coupe nette).
@export_range(0.0, 10.0, 0.05, "or_greater") var release_time: float = 0.6
