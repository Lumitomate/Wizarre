# Ticket 010 — Navigation : les réglages du ShopRouter se règlent dans SA scène

## Statut : ready-for-agent

## Priorité : haute

## Contexte

Rétro de session (migration cabines, novembre) : l'agent a indiqué au
propriétaire de régler `forcer_magasin` / les poids dans *Paramètres du
projet → Autoload*. **Cette vue ne montre jamais les réglages d'une
autoload.** ShopRouter est chargé comme SCÈNE
(`project.godot` : `ShopRouter="*res://scenes/outils/shop_router.tscn"`)
— ses @exports se règlent en ouvrant cette scène et en sélectionnant le
nœud racine (inspecteur). Coût réel : deux sessions de test perdues par
le propriétaire (« ça n'a pas fonctionné »), jusqu'à correction manuelle
par l'agent.

Le savoir ne vit nulle part : aucun commentaire dans
`scripts/shop_router.gd`, aucune doc.

## Changement proposé

Une note de 3-4 lignes en tête de `scripts/shop_router.gd` (au-dessus
des @export, là où un agent qui touche au routage la lit) :

> **Réglages** : poids et modes de forçage s'éditent dans la scène
> `scenes/outils/shop_router.tscn` (nœud racine sélectionné, inspecteur).
> *Paramètres du projet → Autoload ne montre jamais ces réglages* : ne
> pas chercher là.

## Critères d'acceptation

- La note est en tête de `scripts/shop_router.gd`, au-dessus des @export.
- Elle nomme le piège explicitement (Paramètres du projet → Autoload ne
  montre rien) pour que la mauvaise piste soit coupée net.
