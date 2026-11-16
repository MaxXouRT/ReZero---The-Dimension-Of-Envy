# QA — tests et état connu

## Outils

| Outil | Commande | Ce qu'il vérifie |
|---|---|---|
| Vérificateur de scripts | `godot --headless --path . res://tests/check_scripts.tscn` | tous les scripts GDScript compilent (avec les autoloads) |
| Suite gameplay | `godot --headless --path . res://tests/run_tests.tscn [-- --only=systems|chapters|walk|meta]` | voir ci-dessous |
| Test tactile (téléphone simulé) | `godot --headless --path . res://tests/touch_test.tscn -- --mobile` | menus au doigt, joystick, regard, boutons à l’écran, bouton Retour Android |
| Visite visuelle | `xvfb-run godot --path . --rendering-driver vulkan res://tests/screenshot_tour.tscn -- --out=DIR` | capture chaque zone + Satella (rendu Forward+ réel, compilation des shaders) |
| Capture de scène | `res://tests/capture_scene.tscn -- --scene=… --time=… --out=…` (`--visits=N`, `--true`) | lobby et ses variantes |
| Capture de mort | `res://tests/capture_death.tscn -- DIR` | écran Return by Death |

Les tests utilisent un **bac à sable de sauvegarde** (`user://qa_*`) : ils ne touchent jamais la vraie sauvegarde, les fins débloquées ni l'historique du lobby.

## Couverture de la suite gameplay

- Intégrité des données : chaque `say("id")` et chaque note référencée dans le code existe ; lignes de boucle 2–8, lignes AWAKENED, 5 chapitres, objectifs, événements d'horreur, sons clés.
- Return by Death : le monde après le point de retour est rembobiné ; morts, conscience, notes, drapeaux `mem_` survivent.
- Sauvegarde/chargement : chapitre, fragments, mémoire postérieure au point de retour, info de sauvegarde, suppression.
- Envy Awareness : plafonds par chapitre, 6 stades, PLAYER DETECTED seulement au chapitre 5.
- Jeton `{PLAYER_NAME}` et repli neutre sans prénom.
- 13 zones construites, points d'observation, **les 10 états de Satella**, directeur d'apparition au stade UNSTABLE, **15 types d'événements d'horreur**, faux menu + déchirure, **piège du menu pause** (déclenché pendant la fenêtre de jumpscare, résolu, puis pause normale hors fenêtre), porte impossible vers la bibliothèque, poursuite → capture → mort, solutions des puzzles.
- Progression réelle par le sceau : 2 fragments → chapitre 3 + portes, 3 → chapitre 4 + aile condamnée, 4 → chapitre 5 + néant, descente au trône, 3 piliers → dernier fragment.
- **Bot de déplacement physique** : chambre → couloir → hall → aile ouest → Chambre Oubliée, et forêt → chapelle (collisions et ouvertures alignées).
- Finale méta : branche **TRUE** complète (prénom, crédits débloqués) et branche **choix** (indécision → fin B).

## Résultats (build actuel)

- `check_scripts` : 73 scripts, 0 échec.
- `run_tests` : toutes les sections passent (systèmes 99/99 ; progression des chapitres, bot de déplacement, fin TRUE et fin B : OK).
- Visite visuelle : 15 captures, aucune erreur de shader, aucune mort inattendue.

## Limitations connues / à faire

- **Testé sous Linux** (Godot 4.3, Vulkan logiciel *lavapipe* et headless). Pas encore testé sur une machine Windows ni sur un téléphone Android réel : les presets d'export sont fournis mais les builds n'ont pas été produits ici (modèles d'export non installés dans l'environnement).
- Les performances n'ont pas été mesurées sur GPU réel (le rendu logiciel n'est pas représentatif). Le profil « Bas » désactive brouillard volumétrique et SSAO.
- Satella, le mobilier et les voix sont des **placeholders** (voir `ASSETS_AND_AUDIO.md`) ; il n'y a pas de doublage, seulement des sous-titres + textures vocales.
- Le texte du jeu est en français ; les titres de chapitres/fragments/fins sont en anglais comme demandé.
- Le mode headless de Godot affiche des erreurs `mesh_get_surface_count` dues au renderer factice (MultiMesh) : sans effet en jeu.
