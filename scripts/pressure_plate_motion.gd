class_name PressurePlateMotion
extends RefCounted

## LOI DE MOUVEMENT COMMUNE À TOUTES LES PLAQUES DE PRESSION DU JEU.
## Référence : les plaques du shop reflex (scenes/niveaux/magasin/magasin_reflex).
##
## Ce qui est commun :
##  - la VITESSE : 4 px en 0,12 s, soit 33,3 px/s ;
##  - la COURBE : linéaire (ni freinage, ni easing, ni rebond) ;
##  - la durée de REMONTÉE est ÉGALE à la durée de descente ;
##  - le déplacement au PAS DE PHYSIQUE (les plaques sont des
##    AnimatableBody2D, dont la transform de nœud est celle de l'état
##    physique — écrire la position depuis _process la ferait dériver de
##    la position réellement appliquée).
##
## Ce qui est propre à chaque plaque : sa COURSE. Un bouton s'enfonce de
## 4 px, le pilier de la machine à sous de 16 px. Une plaque plus longue
## met simplement plus longtemps à descendre : c'est la VITESSE qui fait
## qu'on reconnaît le même mécanisme partout.
##
## AUCUNE plaque ne doit coder sa vitesse ou sa durée en dur — tout passe
## par ici. Une plaque qui freine en descendant, ou qui remonte plus
## lentement qu'elle ne descend, « flotte » à côté des autres : c'est
## exactement l'écart qui s'était installé entre les trois plaques du jeu
## (relevé au pas de physique : 33 px/s freiné + remontée à 20 px/s d'un
## côté, 33 px/s linéaire de l'autre).

## Course et durée de référence (la vitesse commune en découle).
const COURSE_REFERENCE := 4.0
const DUREE_REFERENCE := 0.12
## Vitesse commune d'enfoncement ET de remontée (px/s).
const VITESSE := COURSE_REFERENCE / DUREE_REFERENCE


## Durée d'un enfoncement (ou d'une remontée) de `course` px à la vitesse
## commune. Une plaque deux fois plus longue met deux fois plus longtemps.
static func duree(course: float) -> float:
	return course / VITESSE


## Tween canonique d'une plaque : LINÉAIRE, au pas de physique, de durée
## déduite de la course. `cible_y` est la position visée sur l'axe Y, dans
## le repère local du parent du corps.
## L'appelant peut enchaîner ses propres `tween_callback` dessus.
static func animer(proprietaire: Node, corps: Node2D, cible_y: float, course: float) -> Tween:
	var tween := proprietaire.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(corps, "position:y", cible_y, duree(course))
	return tween
