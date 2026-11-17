# Camera Director

Cinématiques et zones de caméra pour les jeux Godot 4, en 2D et en 3D
(GDScript typé, sans dépendance, sans autoload). Dépôt :
github.com/MathieuREBOLLEDO/godot-camera-director, utilisé comme sous-module
`addons/camera_director`.

## Idée

Le jeu garde sa caméra. Un director, posé sous elle, prend la main le temps
d'une suite de plans puis la rend :

- **Plan** : un temps de transition (`blend_time`), un temps sur place
  (`hold_time`), une courbe (`transition`, `easing`) — `CameraShotBase`.
  - 2D (`CameraShot`) : un cadre (rectangle dans le repère du parent de la
    caméra) ; le zoom est calculé pour qu'il tienne dans la fenêtre.
  - 3D (`CameraShot3D`) : une pose (`transform`, repère global) et un champ
    de vision (`fov`). `looking(from, target, ...)` pour viser un point,
    `from_camera(camera, ...)` pour reprendre une caméra.
    `following(camera, ...)` : plan vivant, la caméra est relue à chaque
    image (pose, fov, `h_offset` / `v_offset`) : une caméra animée (coup de
    FOV, secousse) ou qui vise une cible qui bouge. La caméra suivie n'est
    pas enregistrée par `to_dict()` (seulement sa pose du moment).
- **Suite** (`CameraSequence`) : des plans dans l'ordre (tous 2D ou tous
  3D).
  - Séquence (`takes_control = false`) : le joueur garde la main. Un dernier
    plan avec `hold_time = 0` reste jusqu'à `stop()`.
  - Cinématique (`takes_control = true`) : le joueur perd la main
    (`control_changed(true)`) jusqu'à la fin du dernier plan, qui finit
    toujours seule.
- **Director** :
  - 2D (`CameraDirector`, sous la `Camera2D`) : déplace et zoome la caméra
    du jeu, puis la rend au cadrage de base donné par `set_base()`.
  - 3D (`CameraDirector3D`, sous la `Camera3D`) : ne touche jamais la
    caméra du jeu (souvent tenue par le joueur). Il a sa propre caméra
    (`rig`), qui part de la caméra en cours, joue les plans, puis rejoint la
    caméra du jeu là où elle est (même si elle a bougé pendant le retour) et
    lui rend la main. Pas de `set_base()` : la base, c'est la caméra du jeu.
- **Zone** : lance une suite quand un corps entre (filtre `body_group`),
  l'arrête à sa sortie (séquence seulement) ; `once` pour une seule fois
  (`rearm()` pour rejouer).
  - 2D : `CameraTrigger` (Area2D). Dans l'éditeur, les cadres de ses plans
    sont dessinés et numérotés.
  - 3D : `CameraTrigger3D` (Area3D). Ses plans peuvent être des
    `CameraShotPoint3D` enfants : des Camera3D qu'on place et prévisualise
    dans l'éditeur (case Aperçu), avec le temps du plan.

## Utilisation en 2D

```gdscript
# Sous la caméra du niveau
var director := CameraDirector.new()
camera.add_child(director)
director.set_base(room_center, room_zoom)   # cadrage rendu à la fin
director.control_changed.connect(func(taken: bool) -> void:
	player.controls_locked = taken)        # au jeu de couper ses commandes

# Une cinématique en code
var cutscene := CameraSequence.new()
cutscene.takes_control = true
cutscene.shots.append(CameraShot.make(Rect2(0, 0, 640, 360), 0.6, 2.0))
director.play(cutscene)

# Une zone
var trigger := CameraTrigger.new()
trigger.sequence = cutscene
trigger.body_group = &"player"
trigger.set_rect(Rect2(0, 0, 160, 320))
level.add_child(trigger)   # director : celui de la caméra en cours
```

## Utilisation en 3D

```gdscript
# Sous la caméra du joueur (FPS, bras de suivi, caméra de table...)
var director := CameraDirector3D.new()
player_camera.add_child(director)
director.control_changed.connect(func(taken: bool) -> void:
	player.input_enabled = not taken)

# Un plan sur un objet, en code
var look := CameraSequence.new()
look.takes_control = true
look.shots.append(CameraShot3D.looking(Vector3(4, 3, 6), boss.global_position, 50.0, 0.8, 2.0))
director.play(look)
```

Passer par une caméra du décor et la suivre (Videodrome : game/tv/tv.gd,
la caméra de la télé avec son coup de FOV ; le director est trouvé par
`CameraDirector3D.current(get_viewport())`, sans connaître le joueur) :

```gdscript
var view := CameraSequence.new()
view.shots.append(CameraShot3D.following(tv_camera, 0.5, 0.0))  # reste jusqu'à stop()
player.director.play(view)
# ...
view.release_time = 1.0
player.director.stop(view)   # retour à la caméra du joueur en 1 s
```

Dans l'éditeur, sans code : un `CameraTrigger3D` avec un `CollisionShape3D`
et des `CameraShotPoint3D` enfants (un par plan, dans l'ordre). Une
`CameraSequence` sur la zone règle seulement `takes_control`, `priority` et
`release_time` ; sans elle, une suite neuve est créée.

## Éditeurs de niveaux

`CameraSequence.to_dict()` / `CameraSequence.from_dict(data)` : une suite en
données simples (types de JSON), pour un éditeur de niveaux qui garde ses
zones dans ses propres fichiers (level_tools, LevelData...). Format :

```
{"takes_control": bool, "priority": int, "release": float,
 "shots": [
   {"kind": "2d", "frame": [x, y, w, h], "blend", "hold", "transition", "easing"},
   {"kind": "3d", "origin": [x, y, z], "rotation": [qx, qy, qz, qw], "fov", ...}]}
```

Les plans illisibles sont sautés. Les unités (pixels, cases, mètres) sont
celles du jeu : à lui de convertir avant (ProjetGringo :
game/level/camera/camera_zones.gd, cadres en cases × PIXELS_PER_METER).

## Debug menu

Si le jeu a le debug menu (addon debug_menu, autoload `DebugMenu`), le
premier director prêt ajoute un menu **Camera** : *Camera zones active*
(coupe tous les directors), *Stop all and go back*, *Rearm one-shot
triggers*, et la commande de console `camera` (état de chaque director),
`camera stop`, `camera rearm`. Aucun fichier du debug menu n'est chargé :
sans lui, rien ne se passe. Un jeu qui a ses propres fenêtres de caméra met
`CameraDebug.enabled = false` avant que le premier director soit prêt.

## API

Commun (`CameraDirectorBase`) : `play(sequence) -> bool` (faux si elle joue
déjà, est vide, a un plan de l'autre dimension, ou si le director est
coupé), `stop(sequence)`, `stop_all()` (retour immédiat à la base),
`is_playing()`, `leading()`, `leading_shot()`, `is_control_taken()`,
`active()`, `is_moving()`, `describe()` (debug) ; `enabled` (coupé : play()
refuse). Signaux : `sequence_started`, `sequence_finished`, `shot_changed`,
`control_changed`. Plusieurs suites en même temps : la plus haute
`priority` mène (à égalité, la plus récente), les autres reprennent ensuite.
Tous les directors sont dans le groupe `CameraDirectorBase.GROUP`, toutes
les zones dans `CameraTrigger.GROUP`.

`CameraDirector` (2D) : `set_base(position, zoom)`, `view_for(frame)`,
`integer_zoom` (zoom des plans arrondi à l'entier en dessous, à partir de
1) ; `CameraDirector.of(camera)`, `CameraDirector.current(viewport)`.

`CameraDirector3D` : `camera` (caméra du jeu, rendue à la fin), `rig`,
`is_driving()` ; `CameraDirector3D.of(camera)` (aussi depuis le rig),
`CameraDirector3D.current(viewport)`.

`CameraDebug` : `register(node)`, `directors(tree)`, `triggers(tree)`,
`state(tree)`, `stop_all(tree)`, `rearm_all(tree)`, `enabled`.

## Tests

Dans un jeu qui a l'addon et le test runner (addons/test_runner) :
`.\tests\run_tests.ps1 -Dir res://addons/camera_director` (ProjetGringo pour
la 2D, RoguePinball pour un jeu 3D). Carte d'impact : tests/impact.md. Sans
test runner, plugin.gd cache tests/ à Godot.
