# Features

Registre des fonctionnalités de l'addon : une fiche par fonction, avec son
but, ses gestes, ses interactions et les documents qui la décrivent. Lu par
Project Hub (onglet Features), au même format que le mecaniques.md d'un jeu.
Tenu à jour par Claude quand il crée, change ou coupe une fonction.

Format d'une fiche (garder les noms de champs, une ligne chacun) :
- `type` : famille de la fonction (cœur, 2D, 3D, zones, données, liens).
- `parent` : titre de la fiche qui la regroupe (facultatif).
- `statut` : à définir, à faire, en cours, à retravailler, fait ou coupé.
- `but` : à quoi elle sert, en une phrase.
- `commandes` : gestes ou raccourcis, « ; » entre deux, « : » avant ce
  qu'ils font.
- `relations` : une sous-ligne par interaction, « ce qu'on touche → effet ».
- `liens` : autres fiches liées, par leur titre.
- `docs` : fichier.md › section ; « ; » entre deux.
- `tests` : noms des fichiers de test, « ; » entre deux (facultatif).
- `projets` : projets pour lesquels la fonction est propre, « ; » entre
  deux. Sans ce champ, la fonction est commune à tous les jeux.

## Suites de plans
- type : cœur
- statut : fait
- but : jouer des plans dans l'ordre, en séquence (le joueur garde la main) ou en cinématique (il la perd jusqu'à la fin).
- relations :
  - play(suite) → la suite commence, sequence_started
  - Dernier plan d'une séquence avec hold 0 → reste jusqu'à stop()
  - Cinématique → control_changed(true), puis (false) quand plus aucune ne joue
  - Plusieurs suites → la plus haute priorité mène, les autres reprennent ensuite
  - stop_all() → retour immédiat à la base (mort, changement d'écran)
  - enabled faux → play() refuse, ce qui joue continue
- liens : Director 2D ; Director 3D
- docs : README.md › Idée ; README.md › API
- tests : test_camera_director ; test_camera_director_3d

## Director 2D
- type : 2D
- parent : Suites de plans
- statut : fait
- but : déplacer et zoomer la Camera2D du jeu pour montrer un cadre, puis la rendre au cadrage de base.
- relations :
  - set_base(position, zoom) → cadrage rendu à la fin, appliqué tout de suite si la caméra est libre
  - Plan 2D (cadre) → zoom calculé pour que le cadre tienne dans la fenêtre
  - integer_zoom → zoom arrondi à l'entier en dessous (pixels nets)
  - Plan 3D dans la suite → play() refuse
- liens : Zone 2D
- docs : README.md › Utilisation en 2D
- tests : test_camera_director

## Director 3D
- type : 3D
- parent : Suites de plans
- statut : fait
- but : jouer des plans 3D avec une caméra à lui, sans jamais déplacer la caméra du jeu, puis lui rendre la main.
- relations :
  - play(suite) → le rig part de la caméra en cours et devient la caméra en cours
  - Plan 3D (pose, fov) → le rig y va en blend_time (rotation et fov interpolés)
  - Plan vivant (CameraShot3D.following) → le rig suit la caméra à chaque image : pose, fov, secousse (h_offset, v_offset)
  - Fin de la suite → le rig rejoint la caméra du jeu là où elle est, même si elle bouge, puis make_current()
  - Réglages de rendu de la caméra du jeu (environment, cull mask, near, far) → repris par le rig
  - Plan 2D dans la suite → play() refuse
- liens : Zone 3D ; Points de plan 3D
- docs : README.md › Utilisation en 3D
- tests : test_camera_director_3d

## Zone 2D
- type : zones
- statut : fait
- but : lancer une suite quand un corps entre dans une Area2D, l'arrêter à sa sortie.
- relations :
  - Corps du groupe body_group entre → la suite joue sur le director de la caméra en cours
  - Corps sort → séquence arrêtée ; cinématique jouée jusqu'au bout
  - once → une seule fois, rearm() pour rejouer
  - Zone retirée (niveau refait) → sa séquence s'arrête
  - Sélection dans l'éditeur → cadres des plans dessinés et numérotés
- liens : Director 2D ; Éditeur de niveaux
- docs : README.md › Idée
- tests : test_camera_trigger

## Zone 3D
- type : zones
- statut : fait
- but : lancer une suite quand un corps entre dans une Area3D, l'arrêter à sa sortie.
- relations :
  - Corps du groupe body_group entre → la suite joue sur le director 3D de la caméra en cours
  - Corps sort → séquence arrêtée ; cinématique jouée jusqu'au bout
  - CameraShotPoint3D enfants → ce sont les plans de la suite, dans l'ordre
  - set_box(aabb) → forme en boîte sans scène
- liens : Director 3D ; Points de plan 3D
- docs : README.md › Utilisation en 3D
- tests : test_camera_trigger_3d

## Points de plan 3D
- type : 3D
- parent : Zone 3D
- statut : fait
- but : régler un plan 3D à l'œil dans l'éditeur, comme une Camera3D qu'on place et prévisualise.
- commandes : case Aperçu de l'éditeur 3D : voir le plan
- relations :
  - Position, rotation, fov du point → pose du plan
  - blend_time, hold_time, courbe du point → temps du plan
  - En jeu → ne devient jamais la caméra en cours
- liens : Zone 3D
- docs : README.md › Utilisation en 3D
- tests : test_camera_director_3d

## Éditeur de niveaux
- type : données
- statut : fait
- but : garder les suites en données simples (JSON) dans les fichiers d'un éditeur de niveaux, et les relire.
- relations :
  - CameraSequence.to_dict() → suite, plans 2D (cadre) et 3D (pose quaternion, fov)
  - CameraSequence.from_dict() → suite relue, plans illisibles sautés
  - Unités du jeu (cases, mètres) → converties par le jeu avant
- liens : Zone 2D ; Zone 3D
- docs : README.md › Éditeurs de niveaux
- tests : test_camera_sequence

## Menu Camera du debug menu
- type : liens
- statut : fait
- but : couper les zones, tout arrêter, réarmer et lire l'état des caméras depuis le debug menu du jeu, s'il y en a un.
- commandes : Camera › Camera zones active : couper ou rendre toutes les zones ; Camera › Stop all and go back : retour à la base ; Camera › Rearm one-shot triggers : rejouer les zones « once » ; console camera : état de chaque director ; console camera stop ; console camera rearm
- relations :
  - Premier director prêt → menu ajouté une seule fois par partie
  - Pas de debug menu → rien ne se passe, aucun fichier chargé
  - CameraDebug.enabled faux → pas de menu (jeu qui a ses propres fenêtres)
- liens : Suites de plans
- docs : README.md › Debug menu
- tests : test_camera_debug

## Zones de caméra de l'éditeur de Gringo
- type : propre au jeu
- statut : fait
- but : poser des zones de caméra (rectangle de cases, plans en cases) dans l'éditeur de niveaux de Gringo et les jouer en jeu.
- relations :
  - Page Gameplay › Camera zone → zone posée dans LevelData.camera_zones
  - Construction du niveau → un CameraTrigger par zone (CameraZones.build)
  - Fenêtre Niveau › Caméra (debug) → zones actives, zoom entier, arrêter, réarmer
- liens : Zone 2D ; Éditeur de niveaux
- docs : README.md › Éditeurs de niveaux
- projets : ProjetGringo

## Caméra de la télé de Videodrome
- type : propre au jeu
- statut : fait
- but : passer de la caméra du joueur à celle de la télé et revenir au joueur, en fondu.
- relations :
  - Interaction avec la télé → plan vivant sur TvCamera, joué par le director du joueur (CameraDirector3D.current)
  - Changement de cassette → angle au hasard, coup de FOV et secousse de TvCamera suivis
  - Quitter la télé ou fin de l'insertion → retour à la caméra du joueur, là où elle est
  - take_camera (groupe player) → vue rendue au joueur tout de suite
- liens : Director 3D
- docs : README.md › Utilisation en 3D
- projets : godot-videodrome

## Suivi d'une cible 3D
- type : 3D
- parent : Director 3D
- statut : à définir
- but : un plan 3D qui garde un nœud dans le cadre pendant qu'il bouge (boss, balle, porte qui s'ouvre). Déjà possible avec un plan vivant sur une caméra qui vise la cible ; reste un plan qui vise un nœud sans caméra à lui.
- liens : Director 3D

## Zones de caméra dans level_tools
- type : données
- parent : Éditeur de niveaux
- statut : à définir
- but : une brique commune pour poser et régler des zones de caméra dans les éditeurs faits avec level_tools (BatEmUp, RoguePinball, DungeonTactics), au lieu d'une version par jeu.
- liens : Éditeur de niveaux ; Zones de caméra de l'éditeur de Gringo
