# Ticket 002 — Validation des nouveaux systèmes

## Statut : ready-for-agent

## Priorité : haute

## Contexte
La session `/retro` a ajouté de nombreux nouveaux fichiers et systèmes (boss, protection, dust, cabin, etc.). Il faut valider que ces systèmes sont correctement intégrés et fonctionnent.

## Changements apportés
- **Boss** : `boss_controller.gd`, `boss_half.gd`, `tentacule_boss.gd`
- **Protection** : `protection.gd` (gestion des dégâts, invincibilité, cooldown)
- **Dust** : `dust.gd` (fumée de contact, surface tinting)
- **Cabin** : `cabin.gd` (remplacement de la bulle, installation de power-up)
- **Nouveaux tests** : 52+ scènes `_check_*.tscn` et `_preview_*.tscn`

## Critères d'acceptation
- Tous les nouveaux systèmes sont correctement connectés aux modules existants
- Le flux de jeu (run → shop → boss) fonctionne sans erreur
- Les tests headless passent (test_parcours.tscn)
- Aucune erreur de compilation

## Actions requises
1. Lancer `godot --headless tests/test_parcours.tscn` pour valider le flux principal
2. Vérifier que les systèmes boss, protection, dust et cabin sont opérationnels
3. S'assurer que les 52 tests visuels sont bien structurés (seuls les `test_*.tscn` doivent être exécutés par CI)
