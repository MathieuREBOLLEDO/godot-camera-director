# Camera Director (addon Godot)

Cinématiques et zones de caméra 2D, communes aux jeux. GDScript typé
uniquement. Utilisation et API : README.md.

## Règles de travail
- Ne pas ajouter de systèmes ou de fonctionnalités non demandés.
- Privilégier le code simple et lisible plutôt qu'une architecture générique.
- Expliquer les choix importants et signaler les compromis.
- Ne pas modifier l'architecture sans proposer un plan avant et attendre
  validation.
- Ne pas commiter sans qu'on le demande.
- Les tests arrivent avec chaque fonction (tests/test_*.gd), et une ligne
  dans tests/impact.md pour un système nouveau ; un bug corrigé a son test.

## Contraintes de l'addon
- Aucune dépendance : ni autre addon, ni fichier du projet qui l'utilise.
- Pas d'autoload : le director vit sous la Camera2D du jeu.
- Tous les chemins en res://addons/camera_director/...
- Godot 4.4 ou plus.
- Dépôt Git à part (github.com/MathieuREBOLLEDO/godot-camera-director),
  utilisé comme sous-module par les jeux : un commit ici part dans ce dépôt.

## Organisation
- camera_shot.gd (CameraShot) : un plan (cadre, transition, durée).
- camera_sequence.gd (CameraSequence) : des plans ; séquence ou cinématique
  (takes_control), priorité, retour.
- camera_director.gd (CameraDirector) : joue les suites sur une Camera2D,
  rend la base, signale la prise de main.
- camera_trigger.gd (CameraTrigger) : zone qui lance une suite.
- plugin.gd : rien à déclarer ; cache tests/ sans test runner.
