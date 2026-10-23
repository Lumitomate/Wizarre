class_name GamblingReel
extends Node2D

## Un rouleau de la machine à sous du casino (orchestré par
## gambling_machine.gd). Les symboles — des Sprite2D statiques, frame 1,
## taille PNG native — défilent vers le bas devant la vitrine de leur
## slot. Deux effets se combinent (décisions grillées Q10/Q12/Q13/Q17) :
##  - pas uniforme de PITCH px, défilement continu à VITESSE px/s ;
##  - perspective cosinus : image pleine au centre de la vitrine, écrasée
##    en s'en éloignant (hauteur plancher 1 px, largeur /1,6 au collapse).
## Le point de collapse est AU-DELÀ du bord de la vitrine (cylindre
## virtuel plus large que la fenêtre) et le parent Vitrine (Control +
## clip_contents) découpe net ce qui dépasse : le symbole suivant pointe
## son nez au bord, coupé par le cadre, comme sur un vrai bandit manchot.
##
## À l'arrêt (fin de l'animation lumière, lancé par la machine), le
## rouleau décélère, dépasse légèrement le prochain centre de symbole
## puis revient se caler dessus — le « backspin » du vrai bandit manchot
## (Q11). La cible est calculée au LANCEMENT du calage : le backspin n'est
## que cosmétique, le symbole central après calage est déjà le gagnant.

signal calage_termine(rouleau: GamblingReel)

## Écart vertical (px) entre deux symboles du rouleau (Q12).
const PITCH := 48.0
## Vitesse de défilement (px/s), vers le bas (Q10).
const VITESSE := 100.0
## Demi-axe (px) du « cylindre virtuel » : la hauteur d'un symbole
## s'annule à cette distance du centre de la vitrine. VOLONTAIREMENT plus
## grand que la demi-hauteur de vitrine (37 px) : au bord, un symbole a
## encore ~70 % de sa taille et est coupé par le masque (Q17).
const COLLAPSE := 74.0
## Largeur résiduelle d'un symbole au point de collapse (Q13 : « divisée
## par 1.6 horizontalement »).
const LARGEUR_BORD := 1.0 / 1.6
## Dépassement (px) du backspin : le rouleau franchit la cible puis
## revient en arrière se caler (Q11).
const DEPASSEMENT := 8.0
## Durée (s) du freinage jusqu'au dépassement (Q11).
const DUREE_CALE := 0.9
## Durée (s) du retour en arrière final (Q11).
const DUREE_REBOND := 0.15
## Freinage anticipé (Q : freinage en deux temps, comme une vraie
## machine) : la vitesse décroît de VITESSE à VITESSE_FIN pendant la
## lumière — le calage final n'a plus qu'une petite distance à avaler,
## ce qui rend le timing lisible pour le joueur (compétence, Q1b).
const VITESSE_FIN := 25.0

enum Etat { TOURNE, SE_CALLE, ARRETE }

var etat: Etat = Etat.TOURNE

var _offset := 0.0
var _vitesse := VITESSE
var _symboles: Array[Sprite2D] = []
var _tween_calage: Tween = null


func _ready() -> void:
	# Pixel art : filtrage plus proche voisin, comme tous les sprites de
	# la machine (défilement net).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Crée les symboles du rouleau, dans l'ordre. Chaque entrée est un
## dictionnaire {"texture": Texture2D, "material": Material (optionnel)}.
## La liste est répétée (cycle complet) jusqu'à un minimum de 4 symboles :
## avec 1-2 joueurs au rouleau des sorciers (Q9/2.1b), le rouleau garde
## son allure de vraie machine (l'item voisin dépasse du bord) — le
## même joueur apparaît alors 2 fois par cycle.
func configurer(entrees: Array[Dictionary]) -> void:
	var liste := entrees.duplicate()
	while liste.size() < 4:
		var taille := liste.size()
		for i in taille:
			liste.append(liste[i])
	for entree: Dictionary in liste:
		var sprite := Sprite2D.new()
		sprite.texture = entree["texture"]
		if entree.has("material"):
			sprite.material = entree["material"]
		add_child(sprite)
		_symboles.append(sprite)
	# Départ aléatoire : chaque rouleau commence sur un cran différent (Q19)
	_offset = randf() * liste.size() * PITCH
	_repositionner()


func _process(delta: float) -> void:
	if etat != Etat.TOURNE:
		return
	avancer(_vitesse * delta)


## Freinage anticipé : décélère de VITESSE à VITESSE_FIN pendant la
## durée donnée (celle de l'animation lumière, passée par la machine).
## Le rouleau continue de tourner, plus lentement.
func commencer_freinage(duree: float) -> void:
	if etat != Etat.TOURNE:
		return
	var tween := create_tween()
	tween.tween_property(self, "_vitesse", VITESSE_FIN, duree) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Avance le rouleau de `distance` px vers le bas et repositionne les
## symboles (enroulement modulo la longueur du rouleau).
func avancer(distance: float) -> void:
	_offset = wrapf(_offset + distance, 0.0, float(_symboles.size()) * PITCH)
	_repositionner()


## Lance l'arrêt (fin de l'animation lumière, Q11). Le rouleau continue
## jusqu'au prochain centre de symbole en le dépassant de DEPASSEMENT px,
## puis revient en arrière se caler exactement dessus. Émet
## calage_termine une fois calé.
func lancer_calage() -> void:
	if etat != Etat.TOURNE:
		return
	etat = Etat.SE_CALLE
	# La cible est fixée MAINTENANT : pendant le freinage, _offset avance
	# encore, on capture donc la distance restante une seule fois.
	var depart := _offset
	var distance := _distance_prochain_centre()
	_tween_calage = create_tween()
	# Freinage : décélération jusqu'à dépasser légèrement le symbole cible…
	# (via _fixer_offset : la valeur interpolée du tween EST l'offset, on
	# ne doit jamais l'additionner frame par frame)
	_tween_calage.tween_method(_fixer_offset, depart, depart + distance + DEPASSEMENT, DUREE_CALE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# … puis retour en arrière : le « clac » du bandit manchot (Q11a)
	_tween_calage.tween_method(_fixer_offset, depart + distance + DEPASSEMENT, depart + distance, DUREE_REBOND) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_calage.tween_callback(func() -> void:
		etat = Etat.ARRETE
		calage_termine.emit(self))


## Fixe l'offset du rouleau (utilisé par le tween de calage) et
## repositionne les symboles.
func _fixer_offset(valeur: float) -> void:
	_offset = valeur
	_repositionner()


## Index du symbole le plus proche du centre de la vitrine. À l'arrêt,
## c'est le symbole cible du calage (le gagnant du rouleau).
func symbole_central() -> int:
	var total := float(_symboles.size()) * PITCH
	var meilleur := -1
	var meilleure := INF
	for i in _symboles.size():
		var y := wrapf(float(i) * PITCH + _offset, 0.0, total) - total * 0.5
		if absf(y) < meilleure:
			meilleure = absf(y)
			meilleur = i
	return meilleur


## Distance (toujours >= 0) à faire défiler avant qu'un symbole soit
## exactement au centre de la vitrine : le prochain cran du rouleau.
## Position d'un centre : y = wrapf(i*PITCH + offset, 0, total) - total/2,
## donc y = 0 équivaut à offset ≡ total/2 (mod PITCH) — et total/2 = (N/2)
## crans : phase nulle si N est pair, demi-cran si N est impair.
func _distance_prochain_centre() -> float:
	var phase := 0.0 if _symboles.size() % 2 == 0 else PITCH * 0.5
	return fposmod(phase - fposmod(_offset, PITCH), PITCH)


## Positionne chaque symbole autour du centre de la vitrine (y dans
## [-total/2 ; total/2[), puis applique la perspective à chacun.
func _repositionner() -> void:
	var total := float(_symboles.size()) * PITCH
	for i in _symboles.size():
		var sprite := _symboles[i]
		var y := wrapf(float(i) * PITCH + _offset, 0.0, total) - total * 0.5
		sprite.position = Vector2(0.0, y)
		_appliquer_perspective(sprite, absf(y))


## Perspective linéaire (Q13/Q17, formule validée : "simple d'abord",
## interpolation linéaire sans compression d'espace) : progression p = 1
## au centre, 0 au collapse (74 px, au-delà du bord de la vitrine).
## Hauteur = p, avec un plancher à 1 pixel pour que le symbole ne
## clignote jamais ; largeur interpolée de 1 (centre) à 1/1,6 (collapse).
## Au-delà : invisible. Au bord de la vitrine (37 px) le symbole a encore
## la moitié de sa hauteur et est coupé net par le masque : l'item du
## dessous pointe son nez comme sur une vraie machine (Q17b).
func _appliquer_perspective(sprite: Sprite2D, distance: float) -> void:
	if distance >= COLLAPSE:
		sprite.visible = false
		return
	sprite.visible = true
	var p := clampf(1.0 - distance / COLLAPSE, 0.0, 1.0)
	var plancher := 1.0 / maxf(float(sprite.texture.get_height()), 1.0)
	sprite.scale = Vector2(
		lerpf(LARGEUR_BORD, 1.0, p),
		maxf(p, plancher)
	)
