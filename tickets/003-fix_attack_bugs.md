# Ticket 003 — Correction des bugs d'attaque

## Statut : fixed (correctif appliqué et validé rouge-vert)

## Résultat de l'analyse (sous-agent, session /retro)

### attack_tier : OK partout
Les 15 scripts `atk_*.gd` assignent bien `attack_tier` au spawn/setup. Aucun manque.

### Double décompte anti-double-coup : BUG RÉEL confirmé dans `scripts/attack_projectile.gd`
Le corps reste dans `_corps_surveilles` après `body_exited` (L131, jamais purgé par `_surveiller_sortie` L66–79), et `_nettoyer_surveillance` (L109–120, déclenché par `tree_exiting`) décrémente aveuglément chaque entrée encore listée.

Scénario : corps dans A + B (même tag d'attaque) → sort de A (`zones` 2→1) → A détruit → `_nettoyer_surveillance` décrémente à 0 et efface → le corps est encore dans B mais la protection est levée → **double-coup possible via B**. Pire : si le corps re-entre dans B après la sortie de A, la destruction de A décrémente l'entrée de B.

Le test `test_double_toc_zones.tscn` passe (cas simple), mais ne couvre pas ce chevauchement multi-projectiles.

### Correctif proposé
Dans `_surveiller_sortie` : retirer le corps de `_corps_surveilles` (ex. `Array.erase`) après le décompte.

### Tests de validation
- `tests/test_double_toc_zones.tscn` : **RESULT: PASS** — scénario de régression ajouté (projectile détruit alors que le corps est encore dans une autre zone du même type : la protection doit rester INTACTE). Validé rouge-vert : sans le correctif, la nouvelle vérification échoue (RESULT: FAIL).
- `tests/test_p3_fire_contact.tscn` : RESULT: PASS
- Suite complète : **RESULT: PASS (54 tests)**

### Correctif appliqué
`scripts/attack_projectile.gd` : `_surveiller_sortie` purge désormais le corps de `_corps_surveilles` après le décompte. Le test a aussi été remis au contrat `RESULT: PASS/FAIL` + code de sortie exigé par `docs/agents/checks.md`.

## Priorité : haute

## Contexte
Plusieurs scripts d'attaque ont été modifiés lors de la session `/retro`. Deux problèmes potentiels ont été identifiés dans `attack_projectile.gd` et les scripts d'attaque spécifiques (F0-F3).

## Problèmes identifiés
1. **Double décrementation** dans `attack_projectile.gd` — la protection anti-double-coup peut se lever trop tôt
2. **`attack_tier`** n'était pas initialisé dans certains `setup_spawn` (corrigé pour F0/F1/F2/F3 mais à vérifier)

## Critères d'acceptation
- La protection anti-double-coup fonctionne correctement (pas de double attaque sur le même cible)
- Chaque attaque utilise bien son `attack_tier` correct
- Les scripts F0-F3 fonctionnent sans erreur

## Actions requises
1. Relancer les tests d'attaque spécifiques (`test_p1_dash.tscn`, `test_p3_fire_contact.tscn`, etc.)
2. Vérifier que `attack_tier` est correctement assigné dans tous les `setup_spawn`
3. S'assurer que le système anti-double-coup ne se déclenche pas prématurément
