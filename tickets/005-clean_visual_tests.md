# Ticket 005 — Nettoyage des tests visuels

## Statut : ready-for-agent

## Priorité : moyenne

## Contexte
52+ scènes de test ont été ajoutées lors de la session `/retro` (scènes `_check_*.tscn` et `_preview_*.tscn`). Ces scènes sont des outils d'inspection visuelle, pas des tests automatisés. La CI ne les lance pas, mais elles prennent de l'espace et peuvent cacher des problèmes.

## Problème
- Trop de fichiers de test dans le projet
- Certains tests ne sont pas nécessaires pour la validation
- La CI ne les exécute pas, donc ils ne sont pas couverts par les tests headless

## Critères d'acceptation
- Ne conserver que les tests `test_*.tscn` (tests headless)
- Supprimer ou archiver les scènes `_check_*.tscn` et `_preview_*.tscn`
- Vérifier que la CI ne lance que les vrais tests

## Actions requises
1. Supprimer les fichiers `_check_*.tscn` et `_preview_*.tscn` (ou les archiver)
2. S'assurer que `tests/test_parcours.tscn` et les autres tests headless passent
3. Vérifier que la CI ne lance que les tests headless
