class_name TentaculeBoss
extends Node2D

## ═══════════════════════════════════════════════════════════════════════
##  TENTACULE DU BOSS « TENTACULES » — tentacule_boss.tscn
## ═══════════════════════════════════════════════════════════════════════
##  Chaîne pilotée par ses JONCTIONS (modèle validé en grillage) :
##   - la source de vérité est _jonctions : les points où le marker DROIT
##     d'un maillon rencontre le marker GAUCHE du suivant. Chaque sprite
##     n'est que du rendu : centre = milieu de ses 2 jonctions, rotation =
##     axe entre elles. La superposition des markers est donc VRAIE PAR
##     CONSTRUCTION, à chaque frame, dans toutes les phases.
##   - maillons RIGIDES : deux jonctions consécutives sont toujours à
##     ESPACEMENT l'une de l'autre (34 px = distance des markers ±17 du
##     prototype). Conséquence acceptée : dans un pli de θ, les pivots se
##     rapprochent (34·cos(θ/2)) — les engrenages s'imbriquent au lieu de
##     se décoller.
##   - règle des 70° GÉOMÉTRIQUE (ANGLE_MAX_DEG) : la trajectoire elle-même
##     ne plie jamais plus que ça entre deux maillons voisins — appliquée
##     au combat comme à la mort (plus aucun redressement cosmétique).
##   - BASE HORIZONTALE : le maillon ancré au trou reste aligné sur l'axe
##     +X local (l'axe du marker = sortie du trou). Il NAÎT DANS le mur
##     (jonction mur à −ESPACEMENT), glisse hors du trou à l'horizontale
##     quand la chaîne tire, et rentre de même au retrait. Le pliage ne
##     commence qu'au maillon suivant.
##   - DÉCOR : les plateformes SOLIDES ne sont jamais traversées — la
##     pointe les contourne en glissant le long du mur (priorité au côté
##     qui la rapproche du sorcier), et le corps longe le contour sans
##     couper les angles ; les plateformes traversables (tuiles à sens
##     unique) restent transparentes pour elles ; seule la rétraction
##     traverse le mur (pour rentrer dans son trou).
##
##  PHASES :
##   - DEPLOY : SORTIE TOTALE D'ABORD — la pointe file TOUT DROIT hors du
##     trou (axe +X) tant que la chaîne n'a pas sorti TOUS ses maillons
##     (nb_articulations_max) ; à pleine longueur seulement, elle fonce
##     vers le sorcier le PLUS LOIN du spawn (recalage chaque frame) et
##     peut se poser sur lui ;
##   - POSE : au PREMIER contact d'un sorcier (ou à l'arrivée près de sa
##     cible), elle s'arrête sur place ~1 s — dégâts au contact, re-hit
##     périodique — puis rentre ;
##   - RETRACT : la base glisse DANS le trou (sur son axe), la courbe est
##     conservée (chaque maillon suit le précédent) et les maillons se
##     redressent progressivement à l'approche du trou (d'autant plus vite
##     qu'ils en sont proches : ils sont donc déjà alignés quand ils
##     deviennent la base) ; la pointe rentre en DERNIÈRE ;
##   - MORT : câble pré-déployé à plat sur l'axe, base ancrée (2 jonctions
##     fixes, horizontales), le reste tombe sous son propre poids (gravité
##     locale, amortissement, vitesse plafond) ; zones de dégâts coupées.
##
##  Repère LOCAL (celui du marker, posé par boss_half.gd) :
##   - origine = point de spawn sur le mur, +X = direction de la salle ;
##   - _jonctions[0] = jonction de pointe (libre), dernier index = jonction
##     mur de la base.
## ═══════════════════════════════════════════════════════════════════════

enum Phase { DEPLOY, POSE, RETRACT, MORT }

# --- Sprites (gauche = fixation, droite = liaison avec le suivant) ---
const TEX_EXTREMITE := preload("res://assets/sprites/Monstres/Boss/Boss1/Tentacule/Boss1_Tentacule1.png")
const TEX_ARTICULATION := preload("res://assets/sprites/Monstres/Boss/Boss1/Tentacule/Boss1_Tentacule2.png")

## Distance entre les DEUX MARKERS d'un même maillon (px locaux) : les
## sprites font 64 px de large et leurs markers sont à ±17 du pivot
## (valeurs du prototype). CONSTANTE : la modifier casserait la
## superposition des markers (les sprites sont rigides).
const ESPACEMENT := 34.0

# --- Équilibrage (tunable dans l'inspecteur) ---
## LIMITE d'articulations derrière l'extrémité (tentacule de combat) :
## le trou émet des maillons tant que la limite n'est pas atteinte.
## Au-delà, la base reste ancrée au trou (tentacule tendue à fond).
@export var nb_articulations_max: int = 10
## Échelle d'affichage : sprites 2× plus gros (tentacules massives)
@export var echelle: float = 2.0
## Vitesse de déploiement (px locaux/s ; à l'échelle 2.0, ×2 à l'écran —
## la valeur tient compte de l'échelle pour garder la même vitesse écran)
@export var vitesse_deploiement: float = 280.0
## Vitesse de rétraction (px locaux/s, même logique d'échelle)
@export var vitesse_retraction: float = 180.0
## Durée de la pose sur la cible (secondes)
@export var duree_pose: float = 1.0
## Durée de vol max avant de s'arrêter où elle est (anti-poursuite infinie)
@export var duree_vol_max: float = 3.0
## Dégâts au contact
@export var degats: int = 1
## Force d'éjection du sorcier touché (px/s)
@export var force_rebond: float = 800.0

# --- Constantes de comportement ---
## Angle max entre 2 maillons voisins (degrés) — règle validée, désormais
## géométrique : c'est la trajectoire qui est limitée, pas l'affichage.
const ANGLE_MAX_DEG := 70.0
## Rayon de la zone de dégâts de chaque maillon (px écran)
const RAYON_CONTACT := 36.0
## Distance à la cible en dessous de laquelle la tentacule se pose
const SEUIL_POSE := 80.0
## Délai entre deux dégâts pendant la pose (le sorcier reste dedans)
const DELAI_RE_HIT := 0.5
## Gravité des câbles de mort (px/s² GLOBAL — convertie au déploiement)
const GRAVITE_CABLES := 900.0
## Vitesse terminale des câbles (px écran/s)
const VITESSE_CABLE_MAX := 500.0
## Amortissement des câbles pendant la chute
const AMORTISSEMENT_CABLES := 0.985
## Vitesse de redressement des maillons pendant la rétraction (rad/s),
## pour le maillon voisin de la base ; les maillons plus loin se
## redressent d'autant moins vite qu'ils sont loin du trou (facteur
## 1 + 3/(distance à la base + 1)) : la courbe reste visible, seul le
## « cou » du tentacule s'aligne sur son trou.
const VITESSE_REDRESSEMENT := 2.5

# --- État ---
var _phase: int = Phase.DEPLOY
## JONCTIONS de la chaîne (repère local) : index 0 = pointe, dernier
## index = jonction mur de la base. Deux jonctions consécutives sont
## TOUJOURS à ESPACEMENT l'une de l'autre (invariant du modèle).
var _jonctions := PackedVector2Array()
## Sprites rendus (le maillon s relie _jonctions[s] et _jonctions[s+1]) —
## du pur rendu recalculé chaque frame, jamais la source de vérité.
var _sprites: Array[Sprite2D] = []
## Zones de dégâts (une par maillon, parallèle à _sprites)
var _areas: Array[Area2D] = []
## Vitesse de chaque jonction (phase MORT uniquement)
var _vitesses := PackedVector2Array()
## Sorcier visé (tentacule de combat)
var _cible: Node2D = null
## Position de la cible en coordonnées LOCALES (mise à jour chaque frame)
var _pos_cible_locale: Vector2 = Vector2.ZERO
var _tps_vol := 0.0
var _tps_pose := 0.0
var _tps_rehit := 0.0
## Gravité des câbles exprimée dans le repère local (calculée au déploiement)
var _gravite_locale := Vector2.ZERO


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.DEPLOY:
			_avancer_vers_cible(delta)
		Phase.POSE:
			_pouser(delta)
		Phase.RETRACT:
			_retracter(delta)
		Phase.MORT:
			_chute_cables(delta)
	_maj_rendu()


## ── Lancement ───────────────────────────────────────────────────────────

## Tentacule de COMBAT : la pointe fonce vers le sorcier le plus loin du
## point de spawn, se pose sur lui ~1 s (dégâts), puis rentre dans le mur.
## Appelée par boss_half.gd APRÈS positionnement (global_transform = marker).
func lancer_combat() -> void:
	_appliquer_echelle()
	# Départ : la pointe seule, entièrement rangée DANS le trou (maillon
	# horizontal, jonction mur à −ESPACEMENT). Elle émerge en glissant.
	_jonctions = PackedVector2Array([Vector2.ZERO, Vector2(-ESPACEMENT, 0.0)])
	_creer_maillon(TEX_EXTREMITE)
	_cible = _sorcier_le_plus_loin()
	if _cible == null:
		# Aucun sorcier en jeu : la tentacule se rétracte aussitôt
		_phase = Phase.RETRACT
		return
	_pos_cible_locale = to_local(_cible.global_position)
	_phase = Phase.DEPLOY


## Tentacule de MORT : courte (le cerveau passe ~3 articulations),
## pré-déployée à plat sur l'axe du trou puis elle retombe comme un câble
## restant attaché au corps du monstre.
func lancer_mort(nb_articulations_mort: int) -> void:
	_appliquer_echelle()
	_phase = Phase.MORT
	# Chaîne à plat sur l'axe, base ancrée au trou (jonction mur à 0)
	var nb_maillons := maxi(nb_articulations_mort + 1, 1)
	_jonctions.resize(nb_maillons + 1)
	for s in nb_maillons + 1:
		_jonctions[s] = Vector2(float(nb_maillons - s) * ESPACEMENT, 0.0)
	for s in nb_maillons:
		_creer_maillon(TEX_EXTREMITE if s == 0 else TEX_ARTICULATION)
	# Les câbles de mort sont décoratifs : plus aucune zone de dégâts
	for area in _areas:
		area.monitoring = false
	_vitesses.resize(_jonctions.size())
	_vitesses.fill(Vector2.ZERO)


## ── Phase DEPLOY ────────────────────────────────────────────────────────

## La jonction de pointe fonce vers la cible (homing : recalée chaque
## frame) ; le trou alimente la chaîne au rythme du vol et les contraintes
## (distances exactes, 70°, base horizontale) sont résolues à chaque passe.
func _avancer_vers_cible(delta: float) -> void:
	_tps_vol += delta
	# Recale la cible : le sorcier bouge pendant le vol
	if _cible != null and is_instance_valid(_cible):
		_pos_cible_locale = to_local(_cible.global_position)
	var n := _jonctions.size()
	# La chaîne a-t-elle sorti TOUS ses maillons ? (pointe + articulations)
	var entiere := (n - 1) >= nb_articulations_max + 1
	var vers := _pos_cible_locale - _jonctions[0]
	# SORTIE TOTALE (règle validée) : tant que la chaîne n'est pas entière,
	# la pointe file TOUT DROIT hors du trou (axe +X), quels que soient les
	# sorciers — la tentacule sort toujours à pleine longueur. À pleine
	# longueur seulement, elle fonce vers le sorcier et peut se poser sur
	# lui (arrivée ou vol trop long), une fois sa pointe sortie du trou.
	var cible := _pos_cible_locale if entiere else _jonctions[0] + Vector2.RIGHT * 1000.0
	var doit_poser := entiere and _jonctions[0].x >= 0.0 \
			and (vers.length() <= SEUIL_POSE or _tps_vol > duree_vol_max)
	# 1. La pointe fonce vers sa cible du moment — sans jamais traverser
	# une plateforme solide. EN POURSUITE (chaîne entière), bloquée par un
	# mur, elle CONTOURNE (règle validée, cf. _avancer_en_evitant). En
	# sortie droite, pas de contournement : bloquée, elle appuie contre le
	# mur. Le déplacement RÉELLEMENT parcouru alimente la chaîne.
	var avant := _jonctions[0]
	var vers_vol := cible - avant
	var pas := minf(vitesse_deploiement * delta, vers_vol.length())
	var arrivee := avant
	if pas > 0.001:
		var direction := vers_vol.normalized()
		if entiere and direction != Vector2.ZERO:
			arrivee = _avancer_en_evitant(avant, direction, pas)
		else:
			arrivee = _bloquer_decor(avant, avant + direction * pas, true)
	_jonctions[0] = arrivee
	var deplacement := _jonctions[0] - avant
	# Chaîne complète : la pointe ne peut pas dépasser la portée max
	# (base ancrée au trou, tentacule tendue) — elle glisse sur ce cercle.
	# On borne le PIVOT de la pointe (milieu de ses 2 jonctions), comme
	# avant : la portée de gameplay est inchangée.
	if n - 1 >= nb_articulations_max + 1:
		var portee := float(nb_articulations_max) * ESPACEMENT
		var pivot_pointe := (_jonctions[0] + _jonctions[1]) * 0.5
		if pivot_pointe.length() > portee:
			_jonctions[0] += pivot_pointe.limit_length(portee) - pivot_pointe
	# 2. La chaîne suit : chaque jonction libre est ramenée à ESPACEMENT
	# derrière sa voisine de pointe (chaîne rigide tirée par la tête).
	# La jonction de base (n-2) est épargnée : elle est posée ci-dessous.
	for s in range(1, n - 2):
		_jonctions[s] = _jonctions[s - 1] + ESPACEMENT \
				* (_jonctions[s] - _jonctions[s - 1]).normalized()
	# 3. Le trou alimente la chaîne au rythme du vol : le maillon de base
	# glisse hors du trou à l'horizontale (de −ESPACEMENT vers 0).
	var x_b := clampf(_jonctions[n - 1].x + deplacement.length(), -ESPACEMENT, 0.0)
	_jonctions[n - 1] = Vector2(x_b, 0.0)
	_jonctions[n - 2] = Vector2(x_b + ESPACEMENT, 0.0)
	# 4. Contraintes géométriques depuis la base (distances exactes + 70°)
	_passe_arriere(delta, false, true)
	# 5. Maillon entièrement sorti (jonction mur affleurante) : le trou en
	# émet un nouveau, DANS le mur, aligné sur l'axe.
	if x_b >= 0.0 and n - 1 < nb_articulations_max + 1:
		_naitre_maillon()
	if doit_poser:
		_debut_pose()


## ── Phase POSE ──────────────────────────────────────────────────────────

func _debut_pose() -> void:
	_phase = Phase.POSE
	_tps_pose = 0.0
	_tps_rehit = DELAI_RE_HIT  # premier re-hit immédiat


## Reste posée ~1 s en infligeant des dégâts au contact (re-hit périodique :
## un sorcier qui reste dedans se fait re-toucher), puis se rétracte.
func _pouser(delta: float) -> void:
	_tps_pose += delta
	_tps_rehit += delta
	if _tps_rehit >= DELAI_RE_HIT:
		_tps_rehit = 0.0
		_re_hit_pose()
	if _tps_pose >= duree_pose:
		_phase = Phase.RETRACT


## Re-hit périodique : tous les sorciers chevauchant encore un maillon
func _re_hit_pose() -> void:
	for area in _areas:
		for body in area.get_overlapping_bodies():
			_toucher(body, area.get_parent())


## ── Phase RETRACT ───────────────────────────────────────────────────────

## Rétraction « corde » : la base glisse DANS le trou sur son axe (elle y
## reste horizontale) et tire toute la chaîne à sa suite — la courbe est
## conservée, la pointe rentre en dernière. Chaque maillon se redresse
## progressivement à l'approche du trou (via _passe_arriere) : quand un
## maillon devient la base, il est déjà aligné. Libérée quand le dernier
## maillon (la pointe) est entièrement rentré.
func _retracter(delta: float) -> void:
	var x_b := _jonctions[_jonctions.size() - 1].x - vitesse_retraction * delta
	# Maillon entièrement rentré (jonction mur à −ESPACEMENT) : retiré.
	while x_b <= -ESPACEMENT and _jonctions.size() > 2:
		_retirer_maillon()
		x_b += ESPACEMENT
	if x_b <= -ESPACEMENT:
		queue_free()  # plus que la pointe, et elle est rentrée
		return
	var n := _jonctions.size()
	_jonctions[n - 1] = Vector2(x_b, 0.0)
	_jonctions[n - 2] = Vector2(x_b + ESPACEMENT, 0.0)
	_passe_arriere(delta, true)


## ── Phase MORT (câbles qui retombent) ───────────────────────────────────

## Mort du boss : cette tentacule de combat DÉJÀ DÉPLOYÉE retombe comme un
## câble (comme les tentacules-câbles de lancer_mort) : phases de combat
## stoppées, dégâts coupés, elle garde sa forme actuelle et chute sous son
## propre poids, la base restant ancrée là où elle est. Une tentacule déjà
## en cours de rétraction est ignorée : elle rentrait déjà de toute façon.
func faire_tomber() -> void:
	if _phase == Phase.RETRACT or _phase == Phase.MORT:
		return
	_phase = Phase.MORT
	# Décorative désormais : plus aucune zone de dégâts
	for area in _areas:
		area.monitoring = false
	_vitesses.resize(_jonctions.size())
	_vitesses.fill(Vector2.ZERO)


## La base reste ancrée (2 jonctions fixes, horizontales, LÀ OÙ ELLES
## SONT — jamais réécrites dans cette phase : au trou pour les câbles de
## mort, à leur place pour une tentacule de combat qui tombe) ; les
## jonctions libres tombent sous leur propre poids, tenues par la distance
## exacte avec leur support (le câble reste tendu) et la contrainte d'angle
## (70° max entre maillons voisins). La simulation continue : les câbles se
## balancent puis se stabilisent — ils restent affichés attachés au corps.
func _chute_cables(delta: float) -> void:
	var n := _jonctions.size()
	# Intégration des jonctions libres (toutes sauf les 2 de la base, qui
	# ne sont jamais touchées : elles restent ancrées où elles sont).
	# Chaque jonction est bloquée au bord des plateformes solides.
	for s in n - 2:
		_vitesses[s] += _gravite_locale * delta
		_vitesses[s] = _vitesses[s].limit_length(VITESSE_CABLE_MAX)
		var avant := _jonctions[s]
		var arrivee := avant + _vitesses[s] * delta
		_jonctions[s] = _bloquer_decor(avant, arrivee)
		if _jonctions[s] != arrivee:
			_vitesses[s] = Vector2.ZERO  # posée sur une plateforme
		_vitesses[s] *= AMORTISSEMENT_CABLES
	_passe_arriere(delta, false, true)


## ── Contraintes de la chaîne ────────────────────────────────────────────

## Passe mur → pointe : retablit la distance EXACTE (ESPACEMENT) de chaque
## maillon à son voisin côté mur et applique la contrainte d'angle (70°
## max entre maillons voisins, la base servant d'axe à 0°). C'est la
## géométrie elle-même qui est contrainte — les markers restent superposés
## par construction, quelle que soit la courbure.
## Avec redresser = true (rétraction), l'écart d'angle de chaque maillon
## est en plus réduit vers 0, d'autant plus vite que le maillon est proche
## de la base : la tentacule s'aligne sur son trou en y rentrant.
func _passe_arriere(delta: float, redresser: bool, bloquer := false) -> void:
	var n := _jonctions.size()
	if n < 3:
		return  # un seul maillon (la pointe) : déjà aligné par la base
	var angle_precedent := 0.0  # axe du maillon côté mur (base = +X)
	var depuis_base := 0
	for s in range(n - 3, -1, -1):
		var ecart := wrapf((_jonctions[s] - _jonctions[s + 1]).angle() - angle_precedent, -PI, PI)
		ecart = clampf(ecart, -deg_to_rad(ANGLE_MAX_DEG), deg_to_rad(ANGLE_MAX_DEG))
		if redresser:
			var taux := VITESSE_REDRESSEMENT * (1.0 + 3.0 / (1.0 + float(depuis_base)))
			ecart = move_toward(ecart, 0.0, taux * delta)
		angle_precedent += ecart
		var place := _jonctions[s + 1] + Vector2.from_angle(angle_precedent) * ESPACEMENT
		# Le corps ne coupe pas non plus les angles : chaque maillon replacé
		# est bloqué au bord des plateformes solides et, bloqué, CONTOURNE
		# autour de son voisin (règle validée) au lieu de couper le virage.
		if bloquer and _bloquer_decor(_jonctions[s], place, true) != place:
			# Côté de drapé : vers le maillon côté pointe (la cible pour la
			# pointe elle-même) — repère stable, contrairement à la distance
			# au maillon actuel qui alterne au bord d'une plateforme.
			var vers := _pos_cible_locale if s == 0 else _jonctions[s - 1]
			place = _place_contournee(_jonctions[s + 1],
					Vector2.from_angle(angle_precedent), _jonctions[s], vers)
		_jonctions[s] = place
		depuis_base += 1


## ── Création et retrait des maillons ────────────────────────────────────

## Crée le sprite d'un nouveau maillon (index = _sprites.size()) + sa zone
## de dégâts. z-index décroissant = chaque nouveau maillon passe SOUS le
## précédent : la superposition gauche/droite est garantie.
func _creer_maillon(texture: Texture2D) -> void:
	var s := _sprites.size()
	var sprite := Sprite2D.new()
	sprite.texture = texture
	# Pivot = centre de rotation du prototype : l'articulation porte son
	# sprite décalé de (-1, 0) (offset de la scène), l'extrémité est à (0, 0).
	sprite.offset = Vector2.ZERO if s == 0 else Vector2(-1, 0)
	# Filtre NEAREST comme tous les sprites du boss (pixel art net) —
	# un Sprite2D créé en code est en filtre linéaire par défaut (flou).
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = -s
	add_child(sprite)
	_sprites.append(sprite)
	var area := Area2D.new()
	var forme := CollisionShape2D.new()
	var cercle := CircleShape2D.new()
	cercle.radius = RAYON_CONTACT
	forme.shape = cercle
	area.add_child(forme)
	# bind(sprite) : la fonction de contact connaît son maillon (éjection)
	area.body_entered.connect(_on_segment_touche.bind(sprite))
	sprite.add_child(area)
	_areas.append(area)


## Le maillon de base a entièrement quitté le trou (jonction mur
## affleurante) : le trou en émet un nouveau, DANS le mur, aligné sur
## l'axe (+X local).
func _naitre_maillon() -> void:
	_jonctions.append(_jonctions[_jonctions.size() - 1] + Vector2(-ESPACEMENT, 0.0))
	_creer_maillon(TEX_ARTICULATION)


## Retire le maillon de base (entièrement rentré dans le trou) : sa
## jonction mur disparaît, sa voisine devient la nouvelle base.
func _retirer_maillon() -> void:
	_jonctions.remove_at(_jonctions.size() - 1)
	var sprite: Sprite2D = _sprites.pop_back()
	_areas.pop_back()
	sprite.queue_free()


## ── Rendu ───────────────────────────────────────────────────────────────

## Chaque maillon est posé ENTRE ses deux jonctions : centre = milieu,
## rotation = axe pointe. Ses markers (±17 du pivot) tombent alors pile
## sur les jonctions partagées avec les maillons voisins.
func _maj_rendu() -> void:
	for s in _sprites.size():
		var sprite := _sprites[s]
		sprite.position = (_jonctions[s] + _jonctions[s + 1]) * 0.5
		sprite.rotation = (_jonctions[s] - _jonctions[s + 1]).angle()


## ── Ciblage ─────────────────────────────────────────────────────────────

## Le sorcier le plus LOIN du point de spawn (règle validée)
func _sorcier_le_plus_loin() -> Node2D:
	var plus_loin: Node2D = null
	var distance_max := -1.0
	for joueur in get_tree().get_nodes_in_group("player_group"):
		var distance: float = joueur.global_position.distance_to(global_position)
		if distance > distance_max:
			distance_max = distance
			plus_loin = joueur
	return plus_loin


## Échelle d'affichage + gravité des câbles convertie dans le repère local
## (appelée après que boss_half a posé global_transform).
func _appliquer_echelle() -> void:
	scale = Vector2(echelle, echelle)
	# (0, gravité) global → local : rotation inverse, puis / échelle
	_gravite_locale = Vector2(0, GRAVITE_CABLES).rotated(-global_rotation) / echelle


## ── Décors : ne jamais traverser une plateforme solide ────────────────
## Sondage le long d'un déplacement : tuile à collision à sens unique
## (plateforme traversable) = passage ; toute autre tuile à collision =
## blocage au bord. La RÉTRACTION n'est PAS bloquée : la tentacule doit
## rentrer DANS son trou, à travers le mur.
const PAS_SONDAGE := 8.0   # pas d'échantillonnage le long d'un trajet (px écran)
const MARGE_MUR := 4.0     # arrêt juste AVANT la surface (px écran)
## Écarts d'angle du contournement (degrés) : essayés dans l'ordre, de la
## direction directe vers de plus en plus rasantes le long du mur.
const ECARTS_CONTOURNEMENT: Array[float] = [15.0, 35.0, 60.0, 85.0]
## La TileMapLayer de la salle (trouvée une fois, parmi les voisins)
var _tilemap: TileMapLayer = null
## Côté de contournement actuellement engagé pour la pointe (+1/-1, 0 =
## aucun) : hystérésis anti-tremblement au bord des plateformes, où les
## deux côtés sont à distance quasi égale du sorcier et alterneraient
## sans cesse. Remis à zéro dès que le chemin direct redevient libre.
var _cote_contournement := 0.0

## Renvoie la position d'arrivée (repère LOCAL), limitée au premier tuileau
## SOLIDE rencontré entre depart et arrivee. Avec echapper = true, un
## départ DÉJÀ dans un mur laisse filer (évasion : un maillon coincé dans
## une tuile doit pouvoir en sortir, sinon il y resterait prisonnier).
func _bloquer_decor(depart_local: Vector2, arrivee_locale: Vector2, echapper := false) -> Vector2:
	if _tilemap == null:
		for enfant in get_parent().get_children():
			if enfant is TileMapLayer:
				_tilemap = enfant
				break
		if _tilemap == null:
			return arrivee_locale
	# Évasion : départ dans une tuile solide → déplacement autorisé
	if echapper and _point_solide(to_global(depart_local)):
		return arrivee_locale
	# Sondage en coordonnées MONDE (la tentacule est tournée/zoomée)
	var depart := to_global(depart_local)
	var arrivee := to_global(arrivee_locale)
	var trajet := arrivee - depart
	var longueur := trajet.length()
	if longueur < 0.01:
		return arrivee_locale
	var pas := trajet / longueur
	var distance := PAS_SONDAGE
	while distance < longueur:
		if _point_solide(depart + pas * distance):
			return to_local(depart + pas * maxf(distance - MARGE_MUR, 0.0))
		distance += PAS_SONDAGE
	if _point_solide(arrivee):
		return to_local(depart + pas * maxf(longueur - MARGE_MUR, 0.0))
	return arrivee_locale


## CONTOURNEMENT DE LA POINTE (règle validée) : d'abord tout droit vers la
## cible ; bloquée par une plateforme solide, elle essaie des directions
## de plus en plus rasantes le long du mur. Priorité : une fois engagée
## d'un côté (HYSTÉRÉSIS anti-tremblement, cf. _cote_contournement), elle
## garde ce côté tant qu'il reste libre ; sans engagement, le côté qui la
## RAPPROCHE le plus du sorcier est essayé en premier. Tout est bloqué :
## elle appuie contre le mur (jusqu'à la fin de son temps de vol).
## Renvoie la position d'arrivée choisie (repère local).
func _avancer_en_evitant(depart: Vector2, direction: Vector2, pas: float) -> Vector2:
	var tout_droit := depart + direction * pas
	if _bloquer_decor(depart, tout_droit, true) == tout_droit:
		_cote_contournement = 0.0  # chemin direct redevenu libre
		return tout_droit
	for ecart_deg in ECARTS_CONTOURNEMENT:
		var ecart := deg_to_rad(ecart_deg)
		var cotes := [1.0, -1.0]
		if _cote_contournement != 0.0:
			# Engagement en cours : même côté en premier, l'autre en secours
			cotes = [_cote_contournement, -_cote_contournement]
		else:
			# Sans engagement : priorité au côté qui rapproche du sorcier
			var c_gauche := depart + direction.rotated(ecart) * pas
			var c_droite := depart + direction.rotated(-ecart) * pas
			if _pos_cible_locale.distance_squared_to(c_droite) \
					< _pos_cible_locale.distance_squared_to(c_gauche):
				cotes = [-1.0, 1.0]
		for cote in cotes:
			var candidat := depart + direction.rotated(ecart * cote) * pas
			if _bloquer_decor(depart, candidat, true) == candidat:
				_cote_contournement = cote
				return candidat
	return depart


## CONTOURNEMENT D'UN MAILLON ENTRAÎNÉ (règle validée) : il doit rester à
## ESPACEMENT EXACT de son voisin côté mur (superposition des markers) —
## bloqué, il tourne donc AUTOUR de ce voisin (arc de rayon ESPACEMENT),
## par écarts d'angle croissants, du côté qui le rapproche de `vers` (le
## maillon côté pointe : le drapé sur un bord garde ainsi TOUJOURS le même
## côté, au lieu d'alterner et de faire trembler la chaîne). Tout est
## bloqué : il reste sur place.
func _place_contournee(voisin: Vector2, direction: Vector2, actuel: Vector2, vers: Vector2) -> Vector2:
	for ecart_deg in ECARTS_CONTOURNEMENT:
		var ecart := deg_to_rad(ecart_deg)
		var candidats := [
			voisin + direction.rotated(ecart) * ESPACEMENT,
			voisin + direction.rotated(-ecart) * ESPACEMENT,
		]
		if vers.distance_squared_to(candidats[0]) > vers.distance_squared_to(candidats[1]):
			candidats.reverse()
		for candidat in candidats:
			if _bloquer_decor(actuel, candidat, true) == candidat:
				return candidat
	return actuel


## Un point du MONDE est-il dans une tuile SOLIDE (collision qui n'est pas
## à sens unique) ?
func _point_solide(point_monde: Vector2) -> bool:
	var donnees: TileData = _tilemap.get_cell_tile_data(
			_tilemap.local_to_map(_tilemap.to_local(point_monde)))
	if donnees == null:
		return false
	for poly in donnees.get_collision_polygons_count(0):
		if not donnees.is_collision_polygon_one_way(0, poly):
			return true
	return false


## ── Dégâts au contact ───────────────────────────────────────────────────

func _on_segment_touche(body: Node2D, segment: Node2D) -> void:
	_toucher(body, segment)


## 1 dégât + éjection du sorcier, éloigné du maillon qui l'a touché.
## Même API que le contact avec le corps du boss (boss_half.gd) :
## le knockback du sorcier est remplacé par le nôtre, calibré.
func _toucher(body: Node2D, segment: Node2D) -> void:
	if not body.is_in_group("player_group"):
		return
	# CONTACT = ARRÊT (règle validée) : dès qu'elle touche un sorcier, la
	# tentacule cesse son vol (sortie droite ou poursuite) et se pose sur
	# place — re-hit périodique puis rétraction. Sans effet si déjà posée.
	if _phase == Phase.DEPLOY:
		_debut_pose()
	var dir := (body.global_position - segment.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = global_transform.x.normalized()
	body.set("hit_knockback_timer", 0.3)
	body.set("hit_knockback_velocity", dir * force_rebond)
	if body.get("can_take_damage") == true:
		body.hit(degats)
		# hit() réécrit le knockback après nous : on re-override APRÈS
		body.set("hit_knockback_timer", 0.3)
		body.set("hit_knockback_velocity", dir * force_rebond)
