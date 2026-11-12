# Ticket 004 — Vérification de l'enum Location

## Statut : ready-for-agent

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
