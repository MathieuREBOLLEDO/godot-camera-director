# Carte d'impact des tests

Quand un système change : lancer ses tests pendant le travail, puis tous
les tests de l'addon avant d'annoncer la tâche finie, puis les tests du jeu
hôte qui l'utilisent (Gringo : `-Dir res://game/level`).

Les tests tournent dans un jeu qui a l'addon et le test runner
(ProjetGringo, sous-module addons/camera_director) :
`.\tests\run_tests.ps1 -Dir res://addons/camera_director`, ou un seul test
avec `-Filter <texte>`. Caméra, director et corps créés par chaque test,
libérés après.

| Système (fichiers) | Ses tests | Touche aussi |
|---|---|---|
| Director (camera_director.gd, camera_shot.gd, camera_sequence.gd) | `-Filter camera_director` | jeu : Level (cadrage de base, commandes coupées) |
| Déclencheur (camera_trigger.gd) | `-Filter camera_trigger` | jeu : zones de caméra de l'éditeur de niveaux (ElementBuilder) |
