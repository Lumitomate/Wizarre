# Ticket 003 — Correction des bugs d'attaque

## Statut : ready-for-agent

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
