# RE:ZERO — THE DIMENSION OF ENVY

*First-person psychological / supernatural / meta horror — Godot 4 (GDScript) — PC Windows & mobile (Android).*

> Fan-game non officiel inspiré de *Re:Zero − Starting Life in Another World*. Œuvre de fiction.

Subaru se réveille en pleine nuit dans le manoir de Roswaal… mais ce n'est plus le manoir.
C'est **la Dimension de l'Envie** : un monde sans soleil, cousu à partir de toutes ses boucles ratées.
Il n'a qu'une lampe torche, le **Retour par la Mort**, et aucun moyen de se défendre contre Satella.
Satella croit que Subaru est revenu vers elle. Elle ne sait pas encore que **quelqu'un d'autre** le contrôle.

---

## Lancer le jeu

1. Installer **Godot 4.3+** (version standard, pas .NET).
2. Ouvrir `project.godot` dans Godot (l'import des sons prend quelques secondes au premier lancement).
3. **F5** → lobby 3D → *NEW GAME*.

Options de ligne de commande (QA) :

| Commande | Effet |
|---|---|
| `godot --path . -- --quickstart` | nouvelle partie directe |
| `godot --path . -- --chapter=N` | saute au chapitre N (2–5), `6` = salle noire (finale méta), `7` = trône |
| **F3** en jeu (build debug) | overlay QA : Envy Awareness, état de Satella, zone, fragments |

Rendu : **Forward+** sur PC (brouillard volumétrique, SSAO, ombres dynamiques). Le profil mobile bascule automatiquement sur le renderer **Mobile** (brouillard classique, qualité basse par défaut, contrôles tactiles).

## Commandes

| Action | Clavier/souris (AZERTY & QWERTY) | Manette | Mobile |
|---|---|---|---|
| Se déplacer | Z Q S D / W A S D | stick gauche | joystick gauche |
| Regarder | souris | stick droit | glisser à droite |
| Courir (endurance) | Maj | L3 / LT | bouton COURIR |
| Marcher lentement | Alt / V | — | — |
| S'accroupir | C / Ctrl | B | bouton |
| Interagir / lire | E / clic gauche | A | bouton E |
| Lampe torche | F / clic droit | Y | bouton LAMPE |
| Journal | Tab / J | Select | bouton |
| Pause | Échap / P | Start | bouton II |

Les touches sont liées par **position physique** : ZQSD sur AZERTY = WASD sur QWERTY.

## Contenu

- **5 chapitres** : The Awakening · The Forgotten Memories · The Observer · The Taboo · The One Behind the Screen.
- **13 zones** : chambre de Subaru, couloir est, salle à manger, grand hall (escalier qui boucle, fenêtre sur une pièce impossible), aile ouest condamnée, Chambre Oubliée, Bibliothèque des Souvenirs, forêt du néant (ruines flottantes, chemin qui boucle), Chapelle de l'Envie, Couloir Sans Fin, aile abandonnée (labyrinthe de poursuite), Trône de l'Envie, salle noire.
- **5 fragments du sceau**, chacun avec zone, puzzle, événement surnaturel, élément narratif et interaction avec Satella.
- **SATELLA AI SYSTEM** : 10 états (DORMANT, OBSERVING, WATCHING, FOLLOWING, MANIFESTING, HUNTING, CHASING, DISAPPEARING, INTERACTING, ENRAGED), apparitions dans les miroirs, derrière les vitres, au bout des couloirs ; disparaît quand on détourne le regard.
- **ENVY AWARENESS** (caché, 0–100) : DORMANT → AWARE → OBSESSED → UNSTABLE → AWAKENED → PLAYER DETECTED.
- **Horror Event Director** piloté par données, pacing anti-répétition, **piège du menu pause** pendant les jumpscares.
- **Return by Death** : séquence de mort cinématique, mémoire conservée, réactions de Satella boucle après boucle.
- **Poursuites** : *SHE IS COMING* (couloir sans fin → labyrinthe), la forêt, le trône (mains d'ombre), poursuites spontanées.
- **Finale méta** et **4 fins** (A Escape, B Eternal Loop, C The Real Satella, TRUE The Player) + lobby qui change après la vraie fin.
- **Sound design procédural** (82 sons générés par `tools/generate_audio.py`), musique adaptative en couches, ambiances spatialisées.
- Menus complets : principal 3D, pause, paramètres (audio, graphismes, commandes, accessibilité, profil), journal, lecture de notes, inspection d'objets 3D.
- **Accessibilité** : réduction des flashs, des mouvements de caméra, volume des jumpscares, sous-titres et taille.

## Vie privée — prénom facultatif

Au premier lancement, le jeu propose un **prénom d'affichage facultatif** (un prénom fictif convient). Il est stocké **uniquement** dans `user://settings.cfg` et peut être effacé dans *Paramètres > Profil*. Le jeu **ne lit aucune donnée** de l'ordinateur (pas de fichiers, comptes, identifiants ni applications). Tous les effets de « piratage » de la finale sont des **fictions visuelles et sonores à l'intérieur de la fenêtre du jeu** ; le jeu ne prend jamais le contrôle réel de la machine.

## Structure

```
project.godot  export_presets.cfg  icon.svg
scenes/      main/ (boot, game)  player/  satella/  ui/ (lobby)  cutscenes/ (credits)
scripts/     core/ player/ satella/ (+states/) ai/ horror/ return_by_death/ narrative/
             interaction/ audio/ save_system/ environment/ (+zones/) ui/ cutscenes/ main/
resources/   dialogues/ (dialogues.json, notes.json)  events/ (horror_events.json)  chapters/
shaders/     architecture, void_sky, satella, shadow_tendril, post_process, mirror, painting…
assets/audio sfx/ music/ ambience/ voice/   (générés)
tools/       generate_audio.py
tests/       check_scripts, run_tests (suite QA), screenshot_tour (QA visuelle)
documentation/
```

Documentation détaillée : [`documentation/ARCHITECTURE.md`](documentation/ARCHITECTURE.md), [`documentation/GAME_DESIGN.md`](documentation/GAME_DESIGN.md), [`documentation/ASSETS_AND_AUDIO.md`](documentation/ASSETS_AND_AUDIO.md), [`documentation/QA.md`](documentation/QA.md).

## Tests

```bash
godot --headless --path . res://tests/check_scripts.tscn   # compile tous les scripts
godot --headless --path . res://tests/run_tests.tscn       # suite QA gameplay (≈ 6 min)
xvfb-run godot --path . --rendering-driver vulkan res://tests/screenshot_tour.tscn -- --out=/tmp/tour
```

## Export

`export_presets.cfg` contient **Windows Desktop** (exe avec PCK embarqué) et **Android** (arm64, renderer Mobile, plein écran immersif). Installer les modèles d'export de Godot, puis *Projet > Exporter*. Pour Android, configurer le SDK et un keystore dans *Éditeur > Paramètres de l'éditeur > Export > Android*.
