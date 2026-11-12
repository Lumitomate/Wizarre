# Ticket 012 — CODING_STANDARDS : règle 4 sur les signaux de Godot

## Statut : ready-for-agent

## Priorité : moyenne

## Contexte

Rétro de session, deux bugs réels nés du même terrain (les signaux de
Godot), l'un latent depuis l'ère des bulles de verre :

1. **`child_entered_tree` ne voit que les enfants DIRECTS** (commit
   `12c0dd0`). L'anti-doublon branchait le signal sur le *spawner* alors
   que les objets sont ajoutés au *parent* du spawner (la cabine / la
   bulle) : le signal ne s'est JAMAIS déclenché. Conséquence : deux
   attaques identiques proposées, objet de remplacement jamais spawné
   (~24 % des visites du magasin classique). Aucune erreur, aucun
   avertissement — un signal simplement muet. Corrigé en 3 sites :
   `shop.gd`, `shop_2players_intro.gd`, `shop_4players_intro.gd`.
2. **L'arité de `connect()` n'est vérifiée qu'à l'ÉMISSION** : connecter
   un signal à 4 arguments à une méthode à 0 argument compile, puis
   plante à chaque émission (`Method expected 0 argument(s), but called
   with 4`). Attrapé uniquement par un test qui émettait le signal.

Ce sont des pièges de sémantique Godot qu'aucun grep mécanique ne peut
attraper (il faut suivre le flux : *où le nœud est-il ajouté ?* / *le
callable accepte-t-il tous les arguments ?*) — donc une règle de revue,
pas un check.

## Changement proposé

Ajouter une **règle 4** à `CODING_STANDARDS.md`, dans le style des trois
existantes (bug réel → règle de revue → exemples canoniques) :

> ## 4. Signaux : le signal voit l'endroit où le nœud est ajouté
>
> `child_entered_tree` / `child_exited_tree` ne s'émettent que pour les
> **enfants directs** de l'émetteur. Si un nœud est ajouté ailleurs
> (`get_parent().add_child`, add_child sur un autre nœud), brancher le
> signal sur un intermédiaire (un spawner, un conteneur) donne un signal
> MUET : aucune erreur, jamais déclenché. Vérifier en revue que
> l'émetteur est exactement le parent où l'ajout se fait. Exemples
> canoniques : `shop.gd::_coordonner_types_objets` (écoutait le spawner,
> les objets vivant dans la cabine), cf. commit `12c0dd0` et
> `tests/test_shop_classique.gd` (assert sur les objets réels).
>
> Complément : l'arité d'un `connect()` n'est vérifiée qu'à l'ÉMISSION —
> un callable qui accepte moins d'arguments que le signal n'en émet
> compile puis plante à chaque émission. Donner des paramètres par
> défaut au callable (cf. `_essayer_ouvrir_sortie` des scripts race).

## Critères d'acceptation

- Règle 4 présente dans `CODING_STANDARDS.md`, avec les exemples
  canoniques cités ci-dessus.
- Le chapeau du fichier reste vrai (« chaque règle est née d'un bug
  réel constaté dans ce dépôt »).
