class_name CameraDebug
extends RefCounted

## Lien facultatif avec le debug menu (addon debug_menu, autoload DebugMenu).
## Le premier director prêt ajoute un menu Camera, une seule fois par
## partie ; sans debug menu, rien ne se passe. Aucun fichier du debug menu
## n'est chargé : il est cherché par son nom (/root/DebugMenu) et appelé
## par add_toggle(), add_action() et add_command().
## Menu Camera : Camera zones active (enabled de tous les directors), Stop
## all and go back (stop_all()), Rearm one-shot triggers (rearm()).
## Console : « camera » (état de chaque director), « camera stop »,
## « camera rearm ».
## Un jeu qui a déjà ses propres fenêtres de caméra met enabled à faux
## avant que le premier director soit prêt.

## Faux : aucun menu ajouté.
static var enabled: bool = true
## Case Camera zones active : gardée ici (et pas lue dans les directors),
## pour qu'elle change même sans director et s'applique à ceux créés après
## (niveau suivant, CameraDirectorBase._ready()).
static var zones_on: bool = true

const DEBUG_MENU: String = "DebugMenu"
const MENU: String = "Camera"
const _META: StringName = &"camera_director_registered"


## Ajoute le menu Camera au debug menu de la partie de [param from], s'il y
## en a un et s'il n'est pas déjà ajouté. Vrai s'il vient d'être ajouté.
static func register(from: Node) -> bool:
	if not enabled or from == null or not from.is_inside_tree():
		return false
	return register_on(from.get_tree().root.get_node_or_null(DEBUG_MENU), from.get_tree())


## Ajoute le menu Camera à [param menu] (un debug menu), pour les directors
## et les zones de [param tree].
static func register_on(menu: Node, tree: SceneTree) -> bool:
	if menu == null or tree == null or menu.has_meta(_META) or not menu.has_method("add_action"):
		return false
	menu.set_meta(_META, true)
	if menu.has_method("add_toggle"):
		menu.call("add_toggle", MENU, "Camera zones active", func() -> bool: return zones_enabled(tree), func(on: bool) -> void: set_zones_enabled(tree, on))
	menu.call("add_action", MENU, "Stop all and go back", func() -> void: stop_all(tree))
	menu.call("add_action", MENU, "Rearm one-shot triggers", func() -> void: rearm_all(tree))
	if menu.has_method("add_command"):
		menu.call("add_command", "camera", func(args: PackedStringArray) -> Variant: return command(tree, args), "Camera directors: state, stop or rearm", "[stop|rearm]")
	return true


## Directors (2D et 3D) de la partie.
static func directors(tree: SceneTree) -> Array[CameraDirectorBase]:
	var found: Array[CameraDirectorBase] = []
	for node: Node in tree.get_nodes_in_group(CameraDirectorBase.GROUP):
		if node is CameraDirectorBase:
			found.append(node)
	return found


## Zones (CameraTrigger et CameraTrigger3D) de la partie.
static func triggers(tree: SceneTree) -> Array[Node]:
	return tree.get_nodes_in_group(CameraTrigger.GROUP)


static func zones_enabled(_tree: SceneTree) -> bool:
	return zones_on


static func set_zones_enabled(tree: SceneTree, on: bool) -> void:
	zones_on = on
	for director: CameraDirectorBase in directors(tree):
		director.enabled = on


static func stop_all(tree: SceneTree) -> void:
	for director: CameraDirectorBase in directors(tree):
		director.stop_all()


static func rearm_all(tree: SceneTree) -> int:
	var count: int = 0
	for trigger: Node in triggers(tree):
		if trigger.has_method("rearm"):
			trigger.call("rearm")
			count += 1
	return count


## État lisible de tous les directors : nom, 2D ou 3D, coupé, prise de main,
## suites (describe()).
static func state(tree: SceneTree) -> String:
	var list: Array[CameraDirectorBase] = directors(tree)
	if list.is_empty():
		return "No camera director."
	var spent: int = triggers(tree).filter(func(trigger: Node) -> bool: return trigger.get("spent") == true).size()
	var lines: PackedStringArray = ["%d director(s), %d trigger(s), %d spent" % [list.size(), triggers(tree).size(), spent]]
	for director: CameraDirectorBase in list:
		var kind: String = "3D" if director is CameraDirector3D else "2D"
		var flags: String = ("" if director.enabled else ", off") + (", control taken" if director.is_control_taken() else "")
		lines.append("%s (%s%s): %s" % [director.get_path(), kind, flags, director.describe().replace("\n", " | ")])
	return "\n".join(lines)


## Commande de console « camera [stop|rearm] ».
static func command(tree: SceneTree, args: PackedStringArray) -> String:
	var verb: String = args[0] if not args.is_empty() else ""
	match verb:
		"stop":
			stop_all(tree)
			return "Stopped, back to base."
		"rearm":
			return "%d trigger(s) rearmed." % rearm_all(tree)
		_:
			return state(tree)
