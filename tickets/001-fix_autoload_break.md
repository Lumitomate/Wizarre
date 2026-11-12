# Ticket 001 — Réparer l'autoload cassé

## Statut : ready-for-agent

## Priorité : haute

## Contexte
Le commit `b6cae70` a renommé un fichier de configuration de base (`global_info.gd` → `run.gd`) et modifié `project.godot` pour qu'il pointe sur le nouveau nom. **Tout le jeu ne démarre plus** car tous les scripts font référence à l'ancien nom.

## Problème
- `project.godot` pointe vers `Run` (nouveau nom)
- Les scripts existants font référence à `GlobalInfo` (ancien nom)
- Le jeu ne démarre pas ou les scripts échouent à charger

## Critères d'acceptation
- Le jeu démarre sans erreur
- Tous les scripts font référence à `Run` (ou `GlobalInfo` selon le choix)
- Les tests headless passent (`test_parcours.tscn`)

## Actions requises
1. Changer `GlobalInfo` en `Run` partout dans le projet
2. Ou revert le commit si c'est plus simple
3. Lancer `godot --headless tests/test_parcours.tscn` pour valider