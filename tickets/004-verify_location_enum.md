# Ticket 004 — Vérification de l'enum Location

## Statut : fixed (validé par sous-agent, session /retro)

## Résultat de validation
- Aucune incohérence détectée : `BOSS_FIGHT` (index 10) et `SHOP_4PLAYERS_REFLEX` (index 11) sont mappés dans `global.gd`, utilisés par `teleport_zone.gd` et `shop_router.gd`, et couverts par `test_parcours.gd` et `test_shop_router.gd`.
- Seule valeur int en dur dans un .tscn : `homepage.tscn` (`destination = 1` → `LEVEL`, valeur préexistante, non impactée).

## Priorité : haute

## Contexte
Deux valeurs ont été ajoutées en fin d'enum `Location` : `BOSS_FIGHT` et `SHOP_4PLAYERS_REFLEX`. La règle du jeu est que les valeurs existantes ne doivent jamais bouger.

## Problème
Il faut vérifier que toutes les scènes qui stockent ces locations en entier (int) sont cohérentes avec les nouvelles valeurs.

## Critères d'acceptation
- `BOSS_FIGHT` et `SHOP_4PLAYERS_REFLEX` sont pris en charge par toutes les scènes
- Aucune référence cassée vers les anciennes valeurs
- Les transitions de niveau (boss fight, shop) fonctionnent correctement

## Actions requises
1. Rechercher toutes les occurrences de `Location` dans le projet
2. Vérifier que les nouvelles valeurs sont présentes dans les scènes
3. S'assurer que les transitions (boss, shop) utilisent les bonnes valeurs
