# Ticket 013 — checks.md : deux règles de design de test nées de la session

## Statut : ready-for-agent

## Priorité : basse

## Contexte

Rétro de session, deux leçons de test qui coûtent cher quand elles
manquent :

1. **Un test de coordination vérifie l'OBJET réel, pas le réglage
   interne.** Les tests d'anti-doublon assertaient
   `spawner.chosen_object_type` (toujours correct, c'est l'agent qui
   l'écrit) et jamais les objets réellement présents sous les cabines —
   le bug des signaux muets (cf. ticket 012, commit `12c0dd0`) a survécu
   à TOUS les tests pendant des mois. Corrigé : les tests intro et
   classique vérifient maintenant `item_attack_type` des objets réels.
2. **Les assertions à instant fixe sur anims/timers sont fragiles en
   parallèle.** « fermeture EN COURS à l'instant T » a flaké sous 4
   workers : l'animation avance en temps réel, les ticks de physique
   prennent du retard sous charge, l'anim peut être déjà finie au tick
   visé (ou pas encore). Corrigé dans `test_shop_classique.gd` par un
   invariant insensible à la charge (« pas encore fermée 2 ticks après »
   — l'anim dure 1 s, impossible).

## Changement proposé

Deux lignes dans `docs/agents/checks.md`, dans la section « Lancer les
tests headless » (ou une courte sous-section « Design de test ») :

> - Un test de coordination (anti-doublon, routage, répartition) vérifie
>   l'OBJET réel observable, pas le réglage interne qui l'a produit
>   (`chosen_object_type` toujours juste ≠ objet sous la cabine toujours
>   juste — cf. ticket 012).
> - Pas d'assertion « en cours à l'instant T » sur une anim ou un timer à
>   un step fixe : fragile en parallèle (l'anim avance en temps réel, les
>   ticks prennent du retard). Vérifier un invariant insensible à la
>   charge : « pas encore fermé N ticks après » (l'anim dure plus
>   longtemps), « fermé à un moment ≤ X ».

## Critères d'acceptation

- Les deux règles figurent dans `docs/agents/checks.md`, formulations
  courtes, avec renvoi aux exemples (`test_shop_classique.gd`,
  `tests/test_shop_intro_2players.gd`).
- Pas de doublon avec ce que CODING_STANDARDS.md couvre déjà (les
  vérifications de rendu y sont déjà pointées).
