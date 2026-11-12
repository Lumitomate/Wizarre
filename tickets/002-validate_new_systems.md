# Ticket 002 — Validation des nouveaux systèmes

## Statut : in_progress — 1 bug majeur corrigé, 2 points restants

## Résultat de la validation (sous-agent + correctifs)
- Compilation : OK (`godot --headless --quit`, aucune erreur).
- `test_parcours`, `test_protection`, `test_boss_tentacules_mort` : PASS.
- **Bug corrigé** : `bubble2.tscn` ligne 1741 — en-tête du nœud racine corrompu (`[node name="BubbleCabine"] type=...` → `]` fermé trop tôt) → la scène ne s'instanciait pas, `test_cabine` ne se terminait jamais et 7 tests magasin échouaient. Correctif : 1 caractère.
- **Bug corrigé** : `shop_2players_race.gd` et `shop_2players_intro.gd` cherchaient le nœud `"BubbleCabine"` (nom de la racine INTERNE de bubble2.tscn) au lieu de `"Bubble2"` (nom du nœud instance dans les scènes) → la porte de sortie s'ouvrait sans attendre la libération du caisson.

## Reste à faire
1. **Migration cabine du magasin intro 3-4 joueurs (INCOMPLÈTE, jeu fonctionnel)** : le crash en jeu (`Node not found: BubbleCabine` à l'entrée du magasin 3-4 joueurs) a été corrigé en re-pointant `_bulle(COULOIR_BAS_GAUCHE)` vers `$Bubble2` — la scène garde ses 4 bulles de verre et la base gère les deux cas (`is Cabin` → rituel cabine, sinon → contact ZoneContact). Reste à faire : remplacer les 4 bulles de verre de `shop_4players_intro.tscn` par des instances de `bubble2.tscn` (comme déjà fait pour le magasin intro 2 joueurs), + vérification visuelle fenêtrée.
2. **Contrats de test manquants** : `tests/test_poussiere.gd` et `tests/test_shop_intro_bulle_contact.gd` n'impriment pas `RESULT: PASS/FAIL` et masquaient des erreurs de script (exit 0 malgré tout) — à mettre au contrat de `docs/agents/checks.md`.

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
