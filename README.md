# Camera Director

Cinématiques et zones de caméra pour un jeu 2D Godot 4 (GDScript typé, sans
dépendance, sans autoload). Dépôt :
github.com/MathieuREBOLLEDO/godot-camera-director, utilisé comme sous-module
`addons/camera_director`.

## Idée

Le jeu garde sa caméra et son cadrage. Un `CameraDirector`, posé sous la
`Camera2D`, prend la main le temps d'une suite de plans puis la rend :

- **Plan** (`CameraShot`) : un cadre (rectangle dans le repère du parent de
  la caméra), un temps de transition (`blend_time`), un temps sur place
  (`hold_time`). Le zoom est calculé pour que le cadre tienne dans la
  fenêtre.
- **Suite** (`CameraSequence`) : des plans dans l'ordre.
  - Séquence (`takes_control = false`) : le joueur garde la main. Un dernier
    plan avec `hold_time = 0` reste jusqu'à `stop()`.
  - Cinématique (`takes_control = true`) : le joueur perd la main
    (`control_changed(true)`) jusqu'à la fin du dernier plan, qui finit
    toujours seule.
- **Zone** (`CameraTrigger`, Area2D) : lance une suite quand un corps entre
  (filtre `body_group`), l'arrête à sa sortie (séquence seulement) ;
  `once` pour une seule fois (`rearm()` pour rejouer).

## Utilisation

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

## API

`CameraDirector` : `play(sequence) -> bool`, `stop(sequence)`, `stop_all()`
(retour immédiat à la base), `set_base(position, zoom)`, `is_playing()`,
`leading()`, `leading_shot()`, `is_control_taken()`, `active()`,
`view_for(frame)`, `describe()` (debug) ; `integer_zoom` (zoom des plans
arrondi à l'entier en dessous, à partir de 1), `enabled` (coupé : play()
refuse). Signaux : `sequence_started`, `sequence_finished`, `shot_changed`,
`control_changed`. Plusieurs suites en même temps : la plus haute
`priority` mène (à égalité, la plus récente), les autres reprennent ensuite.

`CameraDirector.of(camera)`, `CameraDirector.current(viewport)` : le director
d'une caméra, ou de la caméra en cours.

## Tests

Dans un jeu qui a l'addon et le test runner (addons/test_runner) :
`.\tests\run_tests.ps1 -Dir res://addons/camera_director`. Carte d'impact :
tests/impact.md. Sans test runner, plugin.gd cache tests/ à Godot.
