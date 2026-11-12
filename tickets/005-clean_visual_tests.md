# Ticket 005 — Nettoyage des tests visuels

## Statut : ready-for-agent — inventaire terminé, décision propriétaire requise

## Inventaire (sous-agent, session /retro)
9 scènes candidates à l'archivage/suppression :
- `tests/_check_ammo_sprites.tscn`
- `tests/_check_cast_shape.tscn`
- `tests/_check_dash_invincibility.tscn`
- `tests/_check_impact_render.tscn`
- `tests/_check_kill_render.tscn`
- `tests/_check_loaded_sprites.tscn`
- `tests/_check_shader_render.tscn`
- `tests/_preview_cabine_icones.tscn`
- `tests/_preview_cast_shape.tscn`

Toutes les scènes `test_*.tscn` (tests headless) sont conservées. Aucun fichier supprimé à ce stade.

## Décision attendue du propriétaire
Suppression directe ou déplacement vers `archive/` ?

## Note
`docs/agents/checks.md` désigne les `_check_*_render.tscn` comme patron pour les vérifications visuelles (shader) — vérifier que le patron référencé reste accessible si archivé.

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
