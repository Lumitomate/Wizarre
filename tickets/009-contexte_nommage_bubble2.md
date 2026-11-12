# Ticket 009 — Navigation : le nœud de la cabine s'appelle « Bubble2 »

## Statut : ready-for-agent

## Priorité : basse

## Contexte

Le savoir « le nœud de la cabine s'appelle `Bubble2` dans les scènes de
shop, sa racine interne s'appelle `BubbleCabine`, script `cabin.gd` » ne
vit que dans un commentaire de code de `shop_2players_race.gd`. Le
prochain agent qui touche un autre shop le ratera (déjà un bug : porte
de sortie qui s'ouvrait sans attendre la libération du caisson).

**Recouvrement** : `tickets/001-navigation-pointer-structure-cabine.md`
propose déjà un doc sur la structure des nœuds de la cabine. Ce ticket
couvre le complément de nommage scene↔script ; à fusionner avec le 001
si l'agent de mise en œuvre en fait un seul document.

## Changement proposé

Une note de quelques lignes dans `CONTEXT.md` (le glossaire du projet),
à la suite des définitions liées au magasin :

> **Cabine (Bubble2 / BubbleCabine)** — le nœud instancié dans les
> scènes de shop s'appelle `Bubble2` ; sa racine interne (scène
> `bubble2.tscn`, script `cabin.gd`) s'appelle `BubbleCabine`. Un script
> de shop qui cherche `BubbleCabine` depuis la racine retourne `null` :
> chercher `Bubble2`.

## Critères d'acceptation

- `CONTEXT.md` contient la note de nommage.
- Renvoi croisé avec le livrable du ticket 001 pour éviter la
  duplication (un seul endroit fait autorité sur la structure, un seul
  sur le nommage).
