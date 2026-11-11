# CODING_STANDARDS.md — règles de revue du code Wizarre

Ce fichier est lu par l'agent de **revue** (pas pendant l'implémentation) :
chaque règle ici est née d'un bug réel constaté dans ce dépôt, pas d'une
préférence stylistique. Les vérifications headless sont dans
`docs/agents/checks.md` ; les conventions de rendu et d'échelles dans
`docs/agents/impacts-et-echelles.md`.

## 1. Shader canvas_item : REMPLACER `COLOR`, ne jamais le re-multiplier

En Godot 4, la variable `COLOR` **en entrée** du `fragment()` contient déjà
`texture(TEXTURE, UV) × modulate`. Un shader qui recolorise un sprite doit
**remplacer** `COLOR` en fin de fragment (patron de
`assets/shaders/wizard_color.gdshader`), pas écrire
`vec4(col, a) * COLOR` : re-multiplier applique la texture une deuxième
fois sur elle-même (remappage × source → rendu noir/désaturé, invisible
aux tests headless — cf. le bug `impact_palette.gdshader`).

**Check mécanique** (faille de régression du bug réel) — la CI refuse tout
`.gdshader` contenant `* COLOR` :

```sh
grep -n '\* COLOR' assets/shaders/*.gdshader && exit 1 || exit 0
```

Lecture de `COLOR.a` (comme `wizard_color.gdshader`) reste légitime : seul
le motif `* COLOR` est interdit.

## 2. Callback physique : toucher à la physique passe par le différé

Un callback physique (`body_entered`, `body_exited`, `_on_*_entered` branché
sur un Area2D…) s'exécute **pendant le flush des requêtes** : le moteur y
interdit d'ajouter un corps (`RigidBody2D`, `CharacterBody2D`, `Area2D`) ou
de changer son état de collision (« Can't change this state while flushing
queries »). Les nœuds sans physique (Node2D, Sprite2D, Label) peuvent y être
ajoutés directement.

**Règle de revue** : dans un callback physique, tout ajout de corps physique
ou changement de `monitoring`/`disabled` doit passer par
`add_child.call_deferred` / `set_deferred`. Le projet a deux exemples
canoniques : `EnemyDeathBurst` (add_child différé) et
`spawner_ammo.spawn_now` (spawn entièrement différé, testé par
`tests/test_spawn_ammo_flush.tscn`).

## 3. Instance possiblement libérée : Variant + `is_instance_valid` AVANT l'assignation typée

Assigner une instance **déjà libérée** à une variable *typée*
(`var t: TentaculeBoss = dict.get(marker)`) plante **avant** tout garde-fou
et interrompt la fonction — le `is_instance_valid` prévu après ne s'exécute
jamais (bug réel : `boss_half.tentacules_de_mort`, testé par
`tests/test_boss_tentacules_mort.tscn`).

**Règle de revue** : dès qu'une valeur peut être une référence morte
(résultat de `.get()` sur un dictionnaire de suivi, propriété gardée après
un `queue_free` elsewhere), la lire dans un **Variant**, vérifier
`is_instance_valid`, puis appeler ou caster. Nettoyer les entrées mortes du
dictionnaire quand on les détecte.
