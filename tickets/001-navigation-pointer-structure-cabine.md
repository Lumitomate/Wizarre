# Ticket 001 — Navigation : pointer vers la structure de bubble2/cabin

## Statut : ready-for-agent

## Priorité : haute

## Contexte

L'agent a dû lire `scenes/niveaux/magasin/bubble2.tscn` en entier et faire
des recherches (`grep`) pour découvrir la structure des nœuds de la cabine
v2 (`AnimatedSprite2D_box`, `Reperes/CollisionShape2D_Interieur`,
`ZoneEntree`, etc.) alors que l'ancienne bulle avait des noms de nœuds
similaires mais différents (`AnimatedSprite2D_Bulle`, `CollisionShape2D`).

## Changement proposé

Ajouter un pointeur dans `docs/agents/impacts-et-echelles.md` (ou un
document dédié `docs/agents/cabine.md`) vers `bubble2.tscn` et
`scripts/cabin.gd`, avec les noms des nœuds clés et leur rôle.

## Critères d'acceptation

- Un document référence la structure des nœuds de la cabine.
- L'agent de mise en œuvre n'a plus à deviner les noms de nœuds.
