# ADR 0001 — Magasin Shophands : un objet unique distribué par le décideur

Date : 2026-02 (validé avec le propriétaire, à l'implémentation)

## Contexte

Pour les parties à 3-4 joueurs, le magasin « Shophands » remplace l'épreuve de
course à 4. Un sorcier — tiré au sort à CHAQUE visite — est enfermé en haut au
centre avec 3 plaques de pression actionnant 3 mains (droite, gauche, bas) ;
les autres sorciers attendent enfermés dans 3 espaces clos, face aux mains.

## Décision

- **Un seul objet par visite.** Le décideur choisit, via les plaques, lequel
  des autres sorciers le reçoit. Le décideur ne reçoit jamais rien.
- **Décision gravée** : au repos les mains sont fermées ; tenir une plaque
  ouvre progressivement la main correspondante, et quand elle est
  entièrement ouverte (frame 0, « tendue ») l'objet part définitivement
  vers l'espace pointé ; les plaques deviennent inertes et la main
  gagnante reste tendue. Avant ce moment, quitter une plaque referme la
  main (hésitation permise).
- **Aucun minuteur** : pas de sablier, la pression sociale du canapé pousse
  à décider (le décideur est de toute façon enfermé, porte fermée).
- **Émergence sans physique** : l'objet disparaît du cadre central, puis
  émerge doucement du bloc 5/0 de la tilemap de l'espace choisi. Sa hitbox
  ne s'active qu'une fois le bloc dépassé ; tant qu'il est au centre, le
  décideur ne peut pas le voler (sinon la porte ne s'ouvrirait jamais).
- **Sortie** : objet attrapé → la porte de sortie (dans l'enclos du
  décideur) s'ouvre ; il la touche → toute la salle est téléportée au
  niveau suivant (les receveurs ne sortent jamais de leurs espaces).
- **Variante 3 joueurs** : main du bas et plaque centrale retirées (2
  receveurs, gauche et droite) ; l'espace du bas est scellé dans la tilemap
  (rangée (7..19, 9) en blocs 4/2, uniquement des blocs 1/1 en dessous).
- **Routage** : 3-4 joueurs → Shophands (le magasin course reste pour
  2 joueurs).

## Conséquences et jalons

- **Pondération des magasins** : le choix du magasin par nombre de
  joueurs (1 à 4) est réglé dans l'autoload **ShopRouter**
  (`scripts/shop_router.gd`) : listes de magasins + poids de tirage
  modifiables dans l'inspecteur (un poids à 0 désactive un magasin). Le
  tirage pondéré est appelé par `global.gd` pour toute destination SHOP.
- Paramètres d'ambiance exposés et réglables dans l'inspecteur :
  `distance_glissement` (128 px), `duree_glissement`, `duree_emergence`.
- À vérifier en playtest : la position de la porte d'entrée (le décideur
  apparaît au centre de son sprite — le décaler vers l'intérieur de
  l'enclos s'il est « dans le mur ») et les marqueurs de spawn des
  receveurs (décalés d'une tuile à côté du trou d'émergence).
