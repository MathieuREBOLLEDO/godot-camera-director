# Camera Director (addon Godot)

Cinématiques et zones de caméra 2D et 3D, communes aux jeux. GDScript typé
uniquement. Utilisation et API : README.md. Fonctions : features.md (lu par
Project Hub).

## Règles de travail
- Ne pas ajouter de systèmes ou de fonctionnalités non demandés.
- Privilégier le code simple et lisible plutôt qu'une architecture générique.
- Expliquer les choix importants et signaler les compromis.
- Ne pas modifier l'architecture sans proposer un plan avant et attendre
  validation.
- Ne pas commiter sans qu'on le demande.
- Les tests arrivent avec chaque fonction (tests/test_*.gd), et une ligne
  dans tests/impact.md pour un système nouveau ; un bug corrigé a son test.
- features.md : une fiche par fonction, tenue à jour quand une fonction est
  créée, change ou est coupée.

## Contraintes de l'addon
- Aucune dépendance : ni autre addon, ni fichier du projet qui l'utilise.
  Un lien avec un autre addon (debug menu) est facultatif : il le cherche
  par son nom de nœud et l'appelle par has_method() / call(), jamais par
  extends, preload ou class_name d'un autre addon.
- Pas d'autoload : le director vit sous la caméra du jeu.
- 2D et 3D partagent CameraDirectorBase et CameraShotBase ; une suite ne
  mélange pas les deux.
- Tous les chemins en res://addons/camera_director/...
- Godot 4.4 ou plus.
- Dépôt Git à part (github.com/MathieuREBOLLEDO/godot-camera-director),
  utilisé comme sous-module par les jeux : un commit ici part dans ce dépôt.

## Organisation
- camera_shot_base.gd (CameraShotBase) : temps et courbe d'un plan,
  lecture des données (from_dict).
- camera_shot.gd (CameraShot) : plan 2D (cadre).
- camera_shot_3d.gd (CameraShot3D) : plan 3D (pose, fov).
- camera_sequence.gd (CameraSequence) : des plans ; séquence ou cinématique
  (takes_control), priorité, retour ; to_dict() / from_dict().
- camera_director_base.gd (CameraDirectorBase) : file des suites,
  priorités, temps des plans, prise de main, groupe des directors.
- camera_director.gd (CameraDirector) : 2D, déplace la Camera2D, rend la
  base (set_base()).
- camera_director_3d.gd (CameraDirector3D) : 3D, sa propre caméra (rig),
  rend la main à la Camera3D du jeu.
- camera_trigger.gd (CameraTrigger) : zone 2D, cadres dessinés dans
  l'éditeur.
- camera_trigger_3d.gd (CameraTrigger3D) : zone 3D, plans pris des
  CameraShotPoint3D enfants.
- camera_shot_point_3d.gd (CameraShotPoint3D) : plan 3D réglé à l'œil
  (Camera3D de l'éditeur).
- camera_debug.gd (CameraDebug) : menu Camera et commande `camera` du
  debug menu, s'il y en a un.
- plugin.gd : rien à déclarer ; cache tests/ sans test runner.
