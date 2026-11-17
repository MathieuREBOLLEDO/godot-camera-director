# Carte d'impact des tests

Quand un système change : lancer ses tests pendant le travail, puis tous
les tests de l'addon avant d'annoncer la tâche finie, puis les tests du jeu
hôte qui l'utilisent (Gringo : `-Dir res://game/level` et
`-Dir res://game/gameplay`).

Les tests tournent dans un jeu qui a l'addon et le test runner
(ProjetGringo pour la 2D, RoguePinball pour un jeu 3D, sous-module
addons/camera_director) :
`.\tests\run_tests.ps1 -Dir res://addons/camera_director`, ou un seul test
avec `-Filter <texte>`. Caméra, director et corps créés par chaque test,
libérés après.

| Système (fichiers) | Ses tests | Touche aussi |
|---|---|---|
| File des suites (camera_director_base.gd, camera_shot_base.gd) | `-Filter camera_director` (2D et 3D) | tout le reste de l'addon |
| Director 2D (camera_director.gd, camera_shot.gd) | `-Filter test_camera_director.gd` | jeu : Level de Gringo (cadrage de base, commandes coupées) |
| Director 3D (camera_director_3d.gd, camera_shot_3d.gd, camera_shot_point_3d.gd) | `-Filter camera_director_3d` | jeux 3D qui l'utilisent (aucun pour l'instant) |
| Suites en données (camera_sequence.gd) | `-Filter camera_sequence` | éditeurs de niveaux qui gardent des zones (Gringo : CameraZones) |
| Déclencheur 2D (camera_trigger.gd) | `-Filter test_camera_trigger.gd` | jeu : zones de caméra de l'éditeur de niveaux de Gringo (ElementBuilder) |
| Déclencheur 3D (camera_trigger_3d.gd) | `-Filter camera_trigger_3d` | — |
| Debug menu (camera_debug.gd) | `-Filter camera_debug` | debug menu (add_toggle, add_action, add_command) |
