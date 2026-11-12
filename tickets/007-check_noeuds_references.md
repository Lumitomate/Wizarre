# Ticket 007 — Check automatique : références de nœuds scène ↔ script

## Statut : ready-for-agent

## Priorité : haute

## Contexte

Deux fois dans la même session, un script de shop a référencé un nœud
que la scène n'a plus :

1. `shop_2players_race.gd` cherchait `$Bubble/BubbleCabine` alors que le
   nœud de la cabine s'appelle `Bubble2` dans la scène (bug déjà
   documenté dans le script : « chercher "BubbleCabine" ici retournait
   null et la porte s'ouvrait sans attendre la libération du caisson ») ;
2. après suppression de `PorteMagasinEpreuve2` dans
   `shop_4players_race.tscn`, `shop_4players_race.gd` le référencait
   encore dans `_portes_epreuve()` → la scène plantait au démarrage.

`godot --headless --quit` ne détecte RIEN (il compile les scripts sans
instancier les scènes) : le bug ne sort que si un test instancie la
scène — et encore, seulement si ce test existe.

C'est une erreur **mécanique** (un chemin de nœud qui n'existe pas),
donc vérifiable par une machine, pas un jugement.

## Changement proposé

Créer `tests/test_noeuds_references.tscn` (+ `.gd`) : un test headless
qui parcourt les couples scène/script connus et vérifie que chaque
référence racine `$Nom` du script existe bien comme nœud dans la scène
associée.

Périmètre minimal viable :

- les scènes de `scenes/niveaux/magasin/` dont le script racine est
  `res://scripts/shop_*.gd` ;
- les références `$Nom` (un seul niveau, la forme la plus courante) ;
- ignorer ce qui ne peut pas être vérifié statiquement (chemins
  imbriqués type `$Bubble/AnimatedSprite2D_Bulle`, `get_node` dynamique) —
  un faux positif rendrait le test ignoré, donc inutile.

Le test s'insère dans la boucle CI existante (`.github/workflows/tests.yml`
lance `tests/test_*.tscn`) : aucune modification du workflow.

## Critères d'acceptation

- `godot --headless res://tests/test_noeuds_references.tscn` échoue si
  un script de shop référence un nœud racine absent de sa scène.
- Le test passe sur l'état actuel du dépôt.
- Ajouter dans le test un cas positif volontairement faux corrigé
  immédiatement (vérification du vérificateur), ou documenter pourquoi
  on s'en dispense.
