# Ticket 002 — Validation des nouveaux systèmes

## Statut : in_progress — 1 bug majeur corrigé, 2 points restants

## Résultat de la validation (sous-agent + correctifs)
- Compilation : OK (`godot --headless --quit`, aucune erreur).
- `test_parcours`, `test_protection`, `test_boss_tentacules_mort` : PASS.
- **Bug corrigé** : `bubble2.tscn` ligne 1741 — en-tête du nœud racine corrompu (`[node name="BubbleCabine"] type=...` → `]` fermé trop tôt) → la scène ne s'instanciait pas, `test_cabine` ne se terminait jamais et 7 tests magasin échouaient. Correctif : 1 caractère.
- **Bug corrigé** : `shop_2players_race.gd` et `shop_2players_intro.gd` cherchaient le nœud `"BubbleCabine"` (nom de la racine INTERNE de bubble2.tscn) au lieu de `"Bubble2"` (nom du nœud instance dans les scènes) → la porte de sortie s'ouvrait sans attendre la libération du caisson.

## Reste à faire
1. **Migration cabine du magasin intro 3-4 joueurs (SCÈNE FAITE, visuel à vérifier)** : les 4 bulles de verre inline de `shop_4players_intro.tscn` sont remplacées par des instances de `bubble_cabine.tscn` (mêmes noms Bubble/Bubble2/Bubble3/Bubble4, mêmes positions, échelle 2), comme dans l'intro 2 joueurs. `test_shop_intro_bulle_contact.gd` est réécrit en test de migration (fixtures = Cabin, plus de ZoneContact, objets spawnés) avec contrat RESULT. **Reste à faire : vérification visuelle fenêtrée** (placement des cabines dans les couloirs — elles sont plus larges que les bulles).

   Le **magasin classique** (`shop.tscn`) est aussi converti (règle validée avec le propriétaire : UN SEUL OBJET PAR VISITE — dès qu'un sorcier entre dans une cabine, `sorcier_entre` et les 2 autres sont scellées via `Cabin.sceller()` : objet retiré, entrée bloquée, porte refermée AVEC SON ANIMATION). Types coordonnés par l'hôte (`shop.gd::_coordonner_types_objets`, les spawners internes ne se voient plus). Test : `tests/test_shop_classique.gd`. Les 3 nœuds sont renommés Bulle→Cabine (glossaire). `bubble.tscn`/`bubble.gd` sont désormais INUTILISÉS (la bulle du don 2 joueurs est inline dans sa scène) — à supprimer quand le don sera converti.
2. **Contrats de test manquants** : `tests/test_poussiere.gd` n'imprime pas `RESULT: PASS/FAIL` et masquait des erreurs de script (exit 0 malgré tout) — à mettre au contrat de `docs/agents/checks.md`. (`test_shop_intro_bulle_contact.gd` est au contrat depuis sa réécriture ; `test_shop_intro_4players_4joueurs.gd` aussi, avec en plus la coordination du type de la cabine 4 qui re-spawne — un doublon de type pouvait passer par hasard.)

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
