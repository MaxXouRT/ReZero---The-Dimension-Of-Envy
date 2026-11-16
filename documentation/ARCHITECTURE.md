# Architecture technique

Godot 4.3+, GDScript, Forward+ (PC) / Mobile (Android). Tout l'environnement est **construit par code** (`Builder`) à partir de primitives et de shaders procéduraux : les niveaux restent éditables comme du texte, et le `WorldDistortionSystem` peut les modifier à l'exécution. Les scènes `.tscn` sont des racines minimales (`game`, `player`, `satella`, `lobby`, `credits`, `boot`).

## Autoloads (ordre de chargement)

| Autoload | Fichier | Rôle |
|---|---|---|
| `EventBus` | `scripts/core/event_bus.gd` | Hub de signaux global — **aucun système ne référence un autre quand un signal suffit** |
| `Settings` | `scripts/core/settings.gd` | Préférences locales (`user://settings.cfg`), input map (touches physiques), prénom facultatif |
| `GameState` | `scripts/core/game_state.gd` | État du run : séparation **MONDE** (rembobiné) / **MÉMOIRE** (conservée) |
| `SaveManager` | `scripts/save_system/save_manager.gd` | `user://savegame.json` + `user://meta.json` (lobby, fins) ; bac à sable QA |
| `EnvyAwareness` | `scripts/satella/envy_awareness_system.gd` | Valeur cachée 0–100, stades, plafonds par chapitre, journal des causes |
| `AudioManager` | `scripts/audio/audio_manager.gd` | Bus, ambiances, musique adaptative, sons 3D, one-shots d'ambiance, panique |
| `DialogueManager` | `scripts/narrative/dialogue_manager.gd` | Lignes JSON, file d'attente, sous-titres, textures vocales, notes |
| `ChapterManager` | `scripts/narrative/chapter_manager.gd` | 5 chapitres + objectifs (JSON) |
| `JumpscareState` | `scripts/horror/jumpscare_state.gd` | Fenêtre « scare » lue par le menu pause (piège) |
| `ReturnByDeath` | `scripts/return_by_death/return_by_death_manager.gd` | Séquence de mort, rembobinage, rechargement (survit au changement de scène) |

## Scène de jeu (`scripts/main/game.gd`)

Ordre de construction (sans dépendance circulaire) :

```
Environment (ciel du néant, brouillard volumétrique, SSAO, glow)
 └ WorldDistortionSystem
 └ SatellaAI (scenes/satella/satella.tscn) ─ SatellaBody + SatellaStateMachine (10 états)
 └ ChaseController
 └ HorrorEventDirector
 └ ChapterFlow            (spine narrative : checkpoints, chapitres, objectifs)
 └ MetaEndingController   (salle noire, 4 fins)
 └ MansionWorld           (13 zones, clusters de rendu, détection de zone)
 └ UI : PostProcess · HUD · ReaderUI (notes/inspection) · Journal · HorrorOverlay · PauseMenu · TouchControls
 └ PlayerController (scenes/player/player.tscn) ─ caméra, FlashlightController, InteractionSystem
```

Les références sont **descendantes** (Game → systèmes). Les remontées passent par `EventBus` (`player_died`, `fragment_collected`, `flag_set`, `player_zone_changed`, `dialogue_line`, `chase_started`…) ou par `EventBus.satella_request(command, args)` pour piloter Satella sans référence.

## Systèmes demandés → implémentation

| Système | Classe / fichier |
|---|---|
| PlayerController | `scripts/player/player_controller.gd` (marche, course + endurance, marche lente, accroupi, head bob, tremblement à traumatisme, FOV, pas selon la surface, panique, visibilité, verrous de cinématique) |
| FlashlightController | `scripts/player/flashlight_controller.gd` (ombres dynamiques, portée limitée, retard de main, batterie, clignotements surnaturels, `illuminates()`) |
| InteractionSystem | `scripts/interaction/interaction_system.gd` + `interactable.gd` (couche physique 4, occlusion par la géométrie) ; `door.gd` (portes, verrous, **portails impossibles**) ; `pickups.gd` |
| SatellaAI / SatellaStateMachine | `scripts/satella/satella_ai.gd`, `satella_state_machine.gd`, `satella_state.gd`, `states/*.gd` |
| EnvyAwarenessSystem | `scripts/satella/envy_awareness_system.gd` |
| HorrorEventDirector | `scripts/horror/horror_event_director.gd` + `resources/events/horror_events.json` ; `horror_overlay.gd` (visage, déchirure, faux menus, faux curseur) |
| ChaseController | `scripts/ai/chase_controller.gd` |
| ReturnByDeathManager | `scripts/return_by_death/return_by_death_manager.gd` |
| SaveManager | `scripts/save_system/save_manager.gd` |
| DialogueManager | `scripts/narrative/dialogue_manager.gd` + `resources/dialogues/*.json` |
| AudioManager | `scripts/audio/audio_manager.gd` |
| ChapterManager | `scripts/narrative/chapter_manager.gd` + `chapter_flow.gd` |
| WorldDistortionSystem | `scripts/environment/world_distortion_system.gd` |
| MetaEndingController | `scripts/cutscenes/meta_ending_controller.gd` |

## SATELLA AI SYSTEM

Chaque état (`scripts/satella/states/state_*.gd`) documente en tête : conditions d'activation, comportement, sons, dialogues, transitions.

| État | Activation | Comportement |
|---|---|---|
| DORMANT | défaut / après disparition | invisible ; cooldown dépendant du stade ; au stade OBSESSED+ elle **modifie le manoir** (variante non vue) ; au stade AWAKENED elle murmure sans être vue |
| OBSERVING | apparition spontanée / script | immobile à un point d'observation (bout de couloir, balcon, derrière une vitre, **dans un miroir seulement**) |
| WATCHING | elle est vue | fixe Subaru, penche la tête ; **disparaît dès qu'on détourne le regard** ; trop fixée → s'efface ou MANIFESTE (OBSESSED+) |
| FOLLOWING | AWARE+ | marche derrière Subaru, pas en écho ; s'il se retourne… une fraction de seconde |
| MANIFESTING | OBSESSED+ | se rapproche à chaque regard détourné / clignotement → jumpscare ou poursuite (UNSTABLE+) |
| HUNTING | UNSTABLE+, zones autorisées | patrouille ; détection selon lampe allumée / accroupi |
| CHASING | scripts, détection | piloté par `ChaseController` |
| DISAPPEARING | fin d'apparition | instantané si non vue, dissolution violette si vue |
| INTERACTING | cinématiques | piloté par script |
| ENRAGED | porte claquée au nez (UNSTABLE+), scripts | poursuite plus rapide, lumières qui éclatent, distorsion |

**Directeur d'apparition** (`try_spontaneous_appearance`) : pondère observe/follow/manifest/hunt selon le stade et les **règles de la zone** (`Zone.rules`). Choisit un point **hors du champ de vision**, à distance raisonnable, de préférence là où le joueur va se retourner ; après 5 morts, préfère les **zones déjà visitées** et revient plus vite.

Cooldowns par stade : 150 / 95 / 70 / 50 / 36 / 28 s (× aléa) — rares au début, puis de plus en plus fréquentes.

## ENVY AWARENESS

Gains (constantes `GAIN`) : mort, regarder Satella (par seconde), lampe sur son visage, première visite de zone, fragment, messages (noir > argent), poursuites, porte claquée sur elle, **pause pendant un jumpscare**, chapitre… Plafonds : 30 / 52 / 72 / 92 / 100 selon le chapitre (seul le chapitre 5 peut atteindre PLAYER DETECTED). Pendant la finale, le gain « regard » est suspendu : la scène pilote la valeur.

## Return by Death

`GameState.MEMORY_KEYS` (morts, boucles, conscience, notes lues, événements uniques vus, temps passé à la regarder…) + tous les drapeaux préfixés `mem_` survivent ; le reste revient à l'instantané du dernier point de retour. Les points de retour sont posés par `ChapterFlow` (fragments, chapitres) et certaines zones (chapelle, couloir sans fin, trône) et **sauvegardent automatiquement**.

## Monde et distorsion

- `MansionWorld` : 13 zones, origines globales séparées ; le rez-de-chaussée du manoir est physiquement contigu, le reste est relié par **portes impossibles** (`Door.set_portal`). Détection de zone par sondage de position (la plus petite AABB gagne). Les zones d'un autre *cluster* sont masquées (performances mobile).
- `WorldDistortionSystem` : variantes de nœuds appliquées **uniquement quand personne ne regarde** (porte de la Chambre Oubliée, chaises de la salle à manger, chambre d'amis qui n'existe que certaines boucles, tableaux), respiration des murs (uniform global `distortion`), pulsations de veines violettes (`envy_pulse`).
- Escalier du hall qui boucle (ch. 1–3), couloir sans fin (téléportation silencieuse de 14 m), forêt qui ramène au chemin.

## Rendu

Shaders procéduraux (`shaders/`) : `architecture` (papier peint damassé, parquet, pierre, tapis, marbre, lambris… triplanaire + bump), `void_sky` (néant violet, œil au chapitre 5), `satella` (bord violet, dissolution), `shadow_tendril`, `painting` (6 tableaux, yeux qui suivent), `mirror`, `stained_glass`, `post_process` (grain, vignette, aberration, panique, glitch), `death_overlay`, `torn_half`.
