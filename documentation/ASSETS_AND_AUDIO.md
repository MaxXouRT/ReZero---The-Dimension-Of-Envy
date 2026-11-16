# Assets, placeholders et sound design

Le projet est **autonome** : aucun asset externe. Tout ce qui suit est un placeholder fonctionnel, conçu pour être remplacé sans toucher au code.

## Visuels à remplacer

| Placeholder | Où | Remplacement conseillé |
|---|---|---|
| Satella (maillages procéduraux : surfaces de révolution pour la robe, rubans pour la chevelure, d’après l’image de référence du projet) | `scripts/satella/satella_body.gd`, `shaders/satella_hair.gdshader`, `shaders/satella_veil.gdshader` | Modèle riggé (glTF) : garder l'API `set_pose()`, `set_persona()`, `set_dissolve()`, `look_target`, `head_tilt`, `set_mirror_only()` ; les poses deviennent des animations (`AnimationTree`). Matériau : réutiliser `shaders/satella.gdshader` (bord violet + dissolution). |
| Mains d'ombre (chaînes de capsules) | `satella_body.gd`, `zone_throne.gd` | Mesh skinné / VFX particules noires avec `shadow_tendril.gdshader` |
| Mobilier (lits, bureaux, bibliothèques, chaises, horloges…) | `scripts/environment/builder.gd` | Remplacer le contenu de chaque fonction (`bed()`, `desk()`…) par l'instanciation d'une scène `.glb` ; la signature reste identique |
| Matériaux (papier peint, parquet, pierre, marbre…) | `shaders/architecture.gdshader` + `Builder.mat()` | Textures PBR : remplacer l'entrée correspondante de `Builder.mat()` par un `StandardMaterial3D` triplanaire |
| Tableaux | `shaders/painting.gdshader` | Textures peintes (garder l'uniform `stare` pour les yeux qui s'illuminent) |
| Police | `UITheme.serif()` (polices système serif) | Ajouter un `.ttf` gothique dans `assets/fonts/` et le charger dans `UITheme.serif()` |
| Icône | `icon.svg` | — |

## Audio

Tous les sons sont générés par `tools/generate_audio.py` (numpy/scipy, synthèse soustractive, formants, convolution de réverbération) : **82 fichiers** dans `assets/audio/`.

```bash
python3 tools/generate_audio.py
```

Les fichiers sont référencés **par nom** (`AudioManager.play_3d("creak", …)` choisit une variante `creak_1..4`). Pour remplacer un son, déposer un fichier du même nom (`.wav` ou `.ogg`).

| Famille | Fichiers |
|---|---|
| Ambiances (boucles OGG) | `amb_void_wind`, `amb_drone_low`, `amb_mansion_room`, `amb_forest`, `amb_throne` |
| Musique adaptative (couches) | `music_dread` (respire : 45–90 s présente, 60–140 s absente), `music_presence` (proximité de Satella), `music_chase`, `music_throne`, `music_lobby` (berceuse de boîte à musique originale), `music_credits` |
| Bois / manoir | `creak_1-4`, `door_open/close/slam/locked`, `knock`, `clock_tick`, `footsteps_distant` |
| Pas | `step_wood/stone/carpet/dirt_1-4` (surface lue sur le collider) |
| Horreur | `stinger_1-2`, `jumpscare_violent`, `thump`, `whoosh`, `glitch`, `static`, `tear`, `grab`, `glass_crack`, `shadow_hands`, `reality_bend`, `flicker_buzz` |
| Return by Death | `return_by_death` (cœur qui ralentit → cloche inversée → impact → horloge qui s'arrête), `rbd_rewind` |
| Voix (textures) | `whisper_1-6`, `whisper_name` (« Su-ba-ru »), `satella_soft_1-3` (vraie Satella, fredonnement), `witch_low_1-2`, `witch_scream`, `witch_giggle` |
| Panique | `heartbeat`, `breath_in/out` |

### Voix

Il n'y a pas de doublage : chaque ligne est un **sous-titre** accompagné d'une texture vocale selon le style (`whisper`, `soft`, `witch`, `scream`, `name`). Pour doubler : ajouter un champ `"voice": "vo_meta_4c"` à la ligne dans `resources/dialogues/dialogues.json` et déposer `assets/audio/voice/vo_meta_4c.ogg`. Les lignes peuvent venir d'une **direction** (`{"direction": …}`) ou d'une **position** 3D (`{"position": …}`).

### Architecture sonore

- Bus créés à l'exécution : `Music`, `Ambience`, `SFX` (réverbération de couloir), `Voice` (réverbération), `Jumpscare` (volume dédié en accessibilité) ; sur `Master` : passe-bas (mort, panique), distorsion lo-fi (glitchs), limiteur.
- One-shots d'ambiance spatialisés autour de l'auditeur, plus fréquents quand elle s'éveille.
- Battements de cœur et respiration pilotés par la panique.
- Jamais de musique continue : le silence est une couche.
