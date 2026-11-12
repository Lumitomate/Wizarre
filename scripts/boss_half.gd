class_name BossHalf
extends Area2D

## ═══════════════════════════════════════════════════════════════════════
##  UNE MOITIÉ DU BOSS « TENTACULES » — boss_tentacles.tscn
## ═══════════════════════════════════════════════════════════════════════
##  La scène est instanciée 2 fois dans boss_fight.tscn (la 2ᵉ à 180°) ;
##  les 2 moitiés ne se connaissent pas : c'est BossController qui
##  les orchestre et n'appelle QUE les fonctions publiques ci-dessous.
##
##  ŒILS (3 par moitié, index 0..2 = Oeil1..Oeil3) :
##   - OUVERT  : Sprite2D visible + hitbox active → 1 projectile de joueur
##               qui la touche la DÉTRUIT (1 coup = 1 œil, à jamais), avec
##               le même feedback que les ennemis : flash rouge, l'œil est
##               écrasé dans son orbite puis REVIENT à sa place, éclate en
##               débris (EnemyDeathBurst) et la paupière se referme pour
##               de toujours ;
##   - FERMÉ   : paupière figée sur la dernière frame, hitbox désactivée
##               (les projectiles la traversent sans effet) ;
##   - DÉTRUIT : comme fermé, mais ne se rouvrira JAMAIS.
##   - Les strips de paupière (128×448 pleine hauteur) sont l'animation de
##     FERMETURE : jouée à l'endroit pour fermer, à l'envers pour ouvrir.
##
##  CORPS : contact = 1 dégât + rebond du sorcier à 45° vers le HAUT de
##  l'INTÉRIEUR de la salle (jamais hors écran, évite les piques au sol).
##
##  SPAWNS : 4 markers ; le cerveau demande un ennemi ou une tentacule
##  sur un marker précis (choix + rythme gérés par BossController).
## ═══════════════════════════════════════════════════════════════════════

signal oeil_detruit(index: int)

enum EtatOeil { OUVERT, FERME, DETRUIT }

## Frame de paupière fermée (index 0-based : frame 7 de l'anim = index 6)
const FRAME_PAUPIERE_FERMEE := 6
## Durée du clignement du dernier œil vivant (invincibilité brève)
const DUREE_CLIGNOTEMENT := 0.3
## Dégâts du contact avec le corps du boss
const DGT_CONTACT_CORPS := 1
## Force du rebond au contact du corps (comme le knockback des attaques)
const FORCE_REBOND := 1000.0
## Délai entre deux dégâts de contact si le sorcier reste collé au corps
const DELAI_RE_CONTACT := 0.5
## Vitesse de rotation du regard des yeux (comme la tête carnivore t3 : 5.0)
const VITESSE_REGARD := 5.0
## Décalage d'angle du regard de base : la pupille est dessinée vers la
## DROITE dans bossOeil1.png (angle 0). À ajuster si le dessin pointe ailleurs.
const ANGLE_REGARD_BASE := 0.0

## ── Destruction d'un œil : feedback répliqué des ennemis ────────────────
## Éclatement : la MÊME scène que les ennemis (morceaux + giclées avec
## vraie physique), instanciée à la position de l'œil.
const SCENE_ECLATEMENT_OEIL := preload("res://scenes/objets/enemy_death_burst.tscn")
## Flash rouge « Dead Cells » : mêmes couleurs et durées que enemy_flying
const OEIL_FLASH_ROUGE := Color(1.0, 0.1, 0.1, 1.0)
const OEIL_FLASH_ROUGE_DUREE := 0.05
const OEIL_FLASH_RETOUR_DUREE := 0.15
## Knockback : l'œil est écrasé dans son orbite (loin de l'attaquant, comme
## un ennemi repoussé par le sorcier) puis revient EXACTEMENT à sa place
const OEIL_KNOCKBACK_DISTANCE := 20.0  # px locaux (×2 à l'écran, moitié à l'échelle 2)
const OEIL_KNOCKBACK_ALLER := 0.1
const OEIL_KNOCKBACK_RETOUR := 0.15
## Débris plus généreux que les ennemis (l'œil est plus gros qu'eux)
const OEIL_ECLAT_MORCEAUX_MIN := 6
const OEIL_ECLAT_MORCEAUX_MAX := 10
const OEIL_ECLAT_LIQUIDE_MIN := 60
const OEIL_ECLAT_LIQUIDE_MAX := 100

## Essaim de mouches (répliqué du spawner du niveau : même taille,
## même dispersion — cf. spawner_enemy.gd FLY_GROUP_SIZE/SPREAD)
const ESSAIM_TAILLE := 5
const ESSAIM_DISPERSION := 48.0
const ENNEMI_MOUCHE := preload("res://scenes/entities/ennemies/enemy_fly.tscn")

class OeilRef:
	var half: BossHalf
	var index: int
	func _init(h: BossHalf, i: int) -> void:
		half = h
		index = i

# --- Les 3 yeux : Area2D (hitbox) + strip paupière (peau avec trou) ---
# NB : le sprite statique de l'œil (dans chaque Area2D) reste TOUJOURS
# visible — c'est le trou de la paupière qui l'expose à l'ouverture.
@onready var _oeils: Array[Area2D] = [$Oeil1, $Oeil2, $Oeil3]
@onready var _oeil_sprites: Array[Sprite2D] = [
	$Oeil1/BossOeil1, $Oeil2/BossOeil2, $Oeil3/BossOeil3,
]
@onready var _paupieres: Array[AnimatedSprite2D] = [
	$AnimatedSprite2D_Oeil1, $AnimatedSprite2D_Oeil2, $AnimatedSprite2D_Oeil3,
]
@onready var _markers: Array[Marker2D] = [
	$Marker2DSpawn, $Marker2DSpawn2, $Marker2DSpawn3, $Marker2DSpawn4,
]
## Prototype VISUEL des tentacules (2 sprites calibrés, échelle 2.0 comme
## en jeu) : il ne sert QUE de référence dans l'éditeur — les vraies
## tentacules sont créées en code par tentacule_boss.gd. Caché au démarrage.
@onready var _prototype_tentacule: Node2D = $PrototypeTentacule

# --- État ---
var _etats: Array[EtatOeil] = [EtatOeil.FERME, EtatOeil.FERME, EtatOeil.FERME]
## Flag mort : la moitié s'effondre (plus aucune ouverture autorisée)
var _boss_mort: bool = false
## Direction vers l'INTÉRIEUR de la salle (direction du 1er marker)
var _dir_interieur: Vector2 = Vector2.RIGHT
## Rebond 45° : intérieur + vers le haut (calculé au ready)
var _dir_rebond: Vector2 = Vector2(1, -1).normalized()
## Sorciers en contact avec le corps (re-hit périodique tant qu'ils restent)
var _corps_en_contact: Array[Node2D] = []
## Séquence d'intro : cible forcée du regard (la porte d'entrée), tant
## qu'elle est définie les yeux regardent CETTE cible au lieu des sorciers
var _cible_regard_forcee: Node2D = null
## Positions d'ORIGINE des yeux (repère local de la moitié) : le knockback
## de destruction s'écarte de là puis y revient exactement.
var _oeil_positions_origine: Array[Vector2] = []
## Tentacules de combat en cours par marker (marker → TentaculeBoss) : à la
## mort du boss, les markers occupés ne sortent PAS de câble, c'est la
## tentacule déjà sortie qui retombe. Les références libérées (tentacule
## rentrée et supprimée) sont détectées via is_instance_valid.
var _tentacules_par_marker := {}

const TENTACULE_SCENE := preload("res://scenes/entities/ennemies/Boss/tentacule_boss.tscn")


func _ready() -> void:
	# Prototype visuel des tentacules : réservé à l'éditeur (calibrage des
	# sprites, cf. tentacule_boss.gd) — on le cache pour le jeu.
	_prototype_tentacule.visible = false
	for i in _oeils.size():
		_oeils[i].area_entered.connect(_on_oeil_touche.bind(i))
		# Départ : tous les yeux fermés, hitbox off, paupière figée fermée.
		# RIEN n'est jamais masqué : les strips de paupière (128×448) sont
		# la PEAU du boss, toujours affichée. L'œil statique (en dessous)
		# apparaît à travers le TROU de la paupière quand elle est ouverte.
		_oeils[i].monitoring = false
		_paupieres[i].frame = FRAME_PAUPIERE_FERMEE
		_paupieres[i].stop()
	# Corps : dégâts + rebond au contact des sorciers
	body_entered.connect(_on_corps_entre)
	body_exited.connect(_on_corps_quitte)
	# Re-hit périodique tant qu'un sorcier reste collé au corps
	var timer_contact := Timer.new()
	timer_contact.wait_time = DELAI_RE_CONTACT
	timer_contact.timeout.connect(_re_toucher_corps)
	add_child(timer_contact)
	timer_contact.start()
	# Corps vivant : le squelette anime en boucle
	$AnimatedSprite2D_Squelette.play(&"default")
	# Direction intérieur de la salle : les markers pointent tous vers elle
	_dir_interieur = (_markers[0].global_position - global_position).normalized()
	# Rebond à 45° : moitié vers l'intérieur, moitié vers le haut de la salle
	_dir_rebond = (_dir_interieur + Vector2.UP).normalized()
	# Positions d'origine des yeux (pour le knockback de destruction)
	for i in _oeils.size():
		_oeil_positions_origine.append(_oeils[i].position)


func _process(delta: float) -> void:
	if _boss_mort:
		return
	# Chaque œil OUVERT tourne sur lui-même pour suivre le sorcier le plus
	# proche DE LUI (repère : angle global voulu − rotation globale de la
	# chaîne parentale, car la 2ᵉ moitié du boss est instanciée à 180°).
	for i in _oeils.size():
		if _etats[i] != EtatOeil.OUVERT:
			continue
		# Séquence d'intro : les 6 yeux fixent la porte d'entrée
		var point_regard: Vector2
		if _cible_regard_forcee != null and is_instance_valid(_cible_regard_forcee):
			point_regard = _cible_regard_forcee.global_position
		else:
			var plus_proche := _sorcier_le_plus_proche(_oeils[i].global_position)
			if plus_proche == null:
				continue
			point_regard = plus_proche.global_position
		# Viser depuis le CENTRE DU GLOBE (le sprite), pas depuis l'origine
		# de la zone : la zone a son origine 128 px SOUS l'œil (le sprite et
		# sa hitbox sont posés à (25, −128) dedans) — viser depuis l'origine
		# donnait un regard décalé vers le haut ou le bas selon le sorcier.
		var angle_global := (point_regard - _oeil_sprites[i].global_position).angle()
		var angle_local := angle_global - _oeils[i].global_rotation + ANGLE_REGARD_BASE
		_oeil_sprites[i].rotation = lerp_angle(_oeil_sprites[i].rotation, angle_local, delta * VITESSE_REGARD)


## Le sorcier le plus PROCHE d'un point (pour le regard des yeux)
func _sorcier_le_plus_proche(point: Vector2) -> Node2D:
	var plus_proche: Node2D = null
	var distance_min := INF
	for joueur in get_tree().get_nodes_in_group("player_group"):
		var d: float = joueur.global_position.distance_to(point)
		if d < distance_min:
			distance_min = d
			plus_proche = joueur
	return plus_proche


## ── Séquence d'intro (orchestrée par BossController) ────────────────────

## Début du combat en 2 temps, temps 1 : à l'arrivée des sorciers, les
## 6 yeux s'ouvrent (VISUELLEMENT SEULEMENT : hitbox désactivée, on ne
## peut pas les détruire avant le début du combat) et fixent la porte
## d'entrée par laquelle les joueurs viennent d'entrer.
func lancer_intro(cible: Node2D) -> void:
	_cible_regard_forcee = cible
	for i in _etats.size():
		if _etats[i] == EtatOeil.DETRUIT:
			continue
		_etats[i] = EtatOeil.OUVERT
		# monitoring reste FALSE : œil ouvert visuellement mais
		# invulnérable pendant l'intro
		_paupieres[i].play_backwards(&"default")

## Temps 2 (la porte vient de se refermer) : tous les yeux se ferment,
## le regard forcé est relâché — le combat commence (le cerveau ouvre
## immédiatement 1 ou 2 yeux via son cycle).
func fin_intro() -> void:
	_cible_regard_forcee = null
	for i in _etats.size():
		if _etats[i] == EtatOeil.DETRUIT:
			continue
		_etats[i] = EtatOeil.FERME
		_paupieres[i].play(&"default")


## ── Lectures utilisées par BossController ───────────────────────────────

## Index des yeux vivants (0..2) — fermés ou ouverts, PAS détruits
func yeux_vivants() -> Array[int]:
	var vivants: Array[int] = []
	for i in _etats.size():
		if _etats[i] != EtatOeil.DETRUIT:
			vivants.append(i)
	return vivants

func nb_oeils_vivants() -> int:
	return yeux_vivants().size()

func nb_oeils_total() -> int:
	return _etats.size()

func est_ouvert(index: int) -> bool:
	return _etats[index] == EtatOeil.OUVERT

## Position GLOBALE de l'œil (pour les calculs de distance du cerveau)
func position_oeil(index: int) -> Vector2:
	return _oeils[index].global_position

func markers_spawn() -> Array[Marker2D]:
	return _markers

func marker_aleatoire() -> Marker2D:
	return _markers.pick_random()


## ── Ouverture / fermeture / clignement ──────────────────────────────────

## Ouvre l'œil : joue la paupière à l'ENVERS (fermée → ouverte), puis
## bascule sur le sprite d'œil ouvert. La hitbox s'active immédiatement :
## l'œil est touchable dès le début de l'ouverture.
func ouvrir_oeil(index: int) -> void:
	if _etats[index] != EtatOeil.FERME or _boss_mort:
		return
	_etats[index] = EtatOeil.OUVERT
	_oeils[index].monitoring = true
	_paupieres[index].play_backwards(&"default")

## Ferme l'œil : hitbox OFF IMMÉDIATEMENT (plus touchable dès le début de
## la fermeture), puis l'anim de paupière ferme l'œil visuellement.
func fermer_oeil(index: int) -> void:
	if _etats[index] != EtatOeil.OUVERT:
		return
	_etats[index] = EtatOeil.FERME
	_oeils[index].monitoring = false
	_paupieres[index].play(&"default")

## Dernier œil vivant : se referme puis se rouvre aussitôt (quelques
## frames d'invincibilité, jamais fermé longtemps)
func clignoter_oeil(index: int) -> void:
	if _etats[index] != EtatOeil.OUVERT or _boss_mort:
		return
	fermer_oeil(index)
	await get_tree().create_timer(DUREE_CLIGNOTEMENT).timeout
	# Entre-temps le boss peut être mort (le dernier œil détruit ?) : non —
	# pendant le clignement la hitbox est OFF, donc indestructible. Mais
	# la séquence de mort peut avoir démarré : on ne rouvre pas.
	ouvrir_oeil(index)


## ── Destruction d'un œil ────────────────────────────────────────────────

## Un projectile de joueur a touché l'œil OUVERT : détruit à jamais.
## Destruction d'un œil touché par une attaque de JOUEUR : la règle ne
## change pas (1 coup = 1 œil, à jamais) mais avec le MÊME feedback que
## les ennemis — flash rouge « Dead Cells », knockback (écrasé dans son
## orbite, loin de l'attaquant, puis retour EXACT à sa place d'origine :
## l'œil est ancré au boss), puis éclatement en débris+liquide et
## fermeture définitive de la paupière.
func detruire_oeil(index: int, attaque: Node2D = null) -> void:
	if _etats[index] != EtatOeil.OUVERT:
		return
	_etats[index] = EtatOeil.DETRUIT
	# set_deferred OBLIGATOIRE : on vient du signal physique area_entered —
	# changer monitoring pendant le signal est bloqué par le moteur
	_oeils[index].set_deferred("monitoring", false)
	# Le cerveau réagit immédiatement (rythme des spawns, mort du boss…) ;
	# la suite n'est que du jus visuel
	oeil_detruit.emit(index)
	var oeil: Area2D = _oeils[index]
	# Attaquant : la position du projectile ; sans lui, un point fictif dans
	# la salle (l'œil est alors écrasé vers le mur, direction intérieure)
	var source := oeil.global_position - _dir_interieur * 100.0
	if attaque != null and is_instance_valid(attaque):
		source = attaque.global_position
	# Direction de l'attaque (source → œil), convertie dans le repère LOCAL
	# de la moitié (la 2ᵉ moitié est instanciée à 180°)
	var vers_oeil := oeil.global_position - source
	var direction_globale := _dir_interieur if vers_oeil.length() <= 0.01 else vers_oeil.normalized()
	var dir_locale := direction_globale.rotated(-global_rotation)
	# 1. Flash rouge (mêmes couleurs et durées que les ennemis)
	var flash := create_tween()
	flash.tween_property(_oeil_sprites[index], "modulate", OEIL_FLASH_ROUGE, OEIL_FLASH_ROUGE_DUREE)
	flash.tween_property(_oeil_sprites[index], "modulate", Color.WHITE, OEIL_FLASH_RETOUR_DUREE)
	# 2. Knockback dans l'orbite, puis retour à sa place d'origine
	var position_origine := _oeil_positions_origine[index]
	var kb := create_tween()
	kb.tween_property(oeil, "position",
			position_origine + dir_locale * OEIL_KNOCKBACK_DISTANCE, OEIL_KNOCKBACK_ALLER)
	kb.tween_property(oeil, "position", position_origine, OEIL_KNOCKBACK_RETOUR)
	# 3. De retour chez lui : l'œil éclate et la paupière se referme
	kb.chain().tween_callback(_eclater_oeil.bind(index))


## Un projectile (Area2D) entre dans la hitbox de l'œil : destruction
## s'il s'agit d'une attaque de JOUEUR (remonte l'ancêtre jusqu'à trouver
## le groupe attack_group). Les attaques des ennemis ne comptent pas.
func _on_oeil_touche(area: Area2D, index: int) -> void:
	if _etats[index] != EtatOeil.OUVERT:
		return
	if not _est_attaque_joueur(area):
		return
	detruire_oeil(index, area)


## Fin de la destruction d'un œil : éclatement avec la MÊME scène que les
## ennemis (morceaux + giclées de liquide, vraie physique, retombée au
## sol), le globe disparaît (il a explosé) et la paupière se referme une
## dernière fois sur le trou vide — un œil détruit reste fermé à jamais.
## ÉCART VOLONTAIRE avec les ennemis : leurs débris FUIENT l'attaquant ;
## ici ils retomberaient dans le mur (œil mural) et seraient invisibles —
## l'éclatement gicle donc VERS LA SALLE, sur les sorciers.
func _eclater_oeil(index: int) -> void:
	var oeil: Area2D = _oeils[index]
	var eclatement: EnemyDeathBurst = SCENE_ECLATEMENT_OEIL.instantiate()
	# Position LOCALE dans le parent (le même que celui des ennemis : les
	# débris partagent leur physique, sous l'échelle 0.7 de la salle)
	eclatement.position = get_parent().to_local(oeil.global_position)
	eclatement.direction = _dir_interieur
	eclatement.chunk_count_min = OEIL_ECLAT_MORCEAUX_MIN
	eclatement.chunk_count_max = OEIL_ECLAT_MORCEAUX_MAX
	eclatement.blood_count_min = OEIL_ECLAT_LIQUIDE_MIN
	eclatement.blood_count_max = OEIL_ECLAT_LIQUIDE_MAX
	# add_child différé obligatoire : on vient d'une callback physique
	# (comme chez les ennemis, cf. enemy_flying.gd _spawn_death_burst)
	get_parent().add_child.call_deferred(eclatement)
	# Le globe a explosé : la paupière se referme sur un œil vide
	_oeil_sprites[index].visible = false
	# L'œil se ferme une DERNIÈRE fois (l'anim de fermeture joue, et la
	# paupière reste figée fermée : un œil détruit = fermé à tout jamais)
	_paupieres[index].play(&"default")


func _est_attaque_joueur(node: Node) -> bool:
	var n: Node = node
	while n != null:
		if n.is_in_group("attack_group"):
			return true
		n = n.get_parent()
	return false


## ── Mort de la moitié (orchestrée par BossController) ───────────────────

## Tous les yeux vivants se ferment (les détruits le sont déjà). La moitié
## ne peut plus rien rouvrir ensuite.
func fermer_tous_les_oeils() -> void:
	_boss_mort = true
	for i in _etats.size():
		fermer_oeil(i)


## ── Spawns (demandés par BossController) ────────────────────────────────

## Une tentacule de combat part du marker (le cerveau a choisi le point)
func spawn_tentacule(marker: Marker2D) -> void:
	var tentacule: TentaculeBoss = TENTACULE_SCENE.instantiate()
	get_parent().add_child(tentacule)
	# Même orientation que la moitié (le marker pointe vers la salle)
	tentacule.global_transform = marker.global_transform
	tentacule.lancer_combat()
	# Suivi par marker : à la mort du boss, c'est ELLE qui retombera ici
	_tentacules_par_marker[marker] = tentacule


## Mort du boss : pour chaque marker, soit une tentacule de combat est déjà
## sortie — c'est ELLE qui retombe (elle garde sa forme et chute comme un
## câble, cf. TentaculeBoss.faire_tomber) — soit le trou est libre et une
## courte tentacule-câble en sort, comme avant.
func tentacules_de_mort(articulations_mort: int) -> void:
	for marker in _markers:
		# .get() peut rendre une instance LIBÉRÉE (tentacule de combat
		# rentrée dans son trou → queue_free, cf. tentacule_boss.gd) :
		# l'assignation directe à une variable TYPÉE plante avant même le
		# garde-fou is_instance_valid (« Trying to assign invalid
		# previously freed instance ») et coupait toute la séquence de
		# mort. Passer par un Variant, puis nettoyer l'entrée morte.
		var existante: Variant = _tentacules_par_marker.get(marker)
		if existante != null and is_instance_valid(existante):
			existante.faire_tomber()
		else:
			_tentacules_par_marker.erase(marker)
			spawn_tentacule_mort(marker, articulations_mort)

## Tentacule de MORT : courte (~3 blocs), qui retombe comme un câble
## attaché au corps (séquence de mort du boss)
func spawn_tentacule_mort(marker: Marker2D, articulations: int) -> void:
	var tentacule: TentaculeBoss = TENTACULE_SCENE.instantiate()
	get_parent().add_child(tentacule)
	tentacule.global_transform = marker.global_transform
	tentacule.lancer_mort(articulations)

## Un ennemi aléatoire (la scène est choisie par le cerveau)
## Un spawn « ennemi » tirant enemy_fly fait apparaître un ESSAIM entier
## (répliqué du spawner du niveau : cf. spawner_enemy.gd _spawn_fly_group)
func spawn_ennemi(scene: PackedScene, marker: Marker2D) -> void:
	if scene.resource_path.ends_with("enemy_fly.tscn"):
		_spawn_essaim_mouches(marker)
		return
	var ennemi: Node2D = scene.instantiate()
	get_parent().add_child(ennemi)
	# Position APRÈS add_child : le parent (racine de la salle) est à
	# l'échelle 0.7, contrairement à la moitié du boss — l'ennemi ne doit
	# PAS hériter de cette échelle
	ennemi.global_position = marker.global_position


## Essaim de mouches éparpillées autour du point de spawn : chaque mouche
## rejoint le groupe (elles partagent la cible et volent en formation)
func _spawn_essaim_mouches(marker: Marker2D) -> void:
	var essaim: Array[EnemyFly] = []
	for i in ESSAIM_TAILLE:
		var mouche: EnemyFly = ENNEMI_MOUCHE.instantiate()
		get_parent().add_child(mouche)
		mouche.global_position = marker.global_position + Vector2(
			randf_range(-ESSAIM_DISPERSION, ESSAIM_DISPERSION),
			randf_range(-ESSAIM_DISPERSION, ESSAIM_DISPERSION))
		mouche.swarm_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 40.0
		essaim.append(mouche)
	for mouche in essaim:
		mouche.swarm = essaim


## ── Contact avec le corps du boss ───────────────────────────────────────

func _on_corps_entre(body: Node2D) -> void:
	if not body.is_in_group("player_group"):
		return
	_corps_en_contact.append(body)
	_toucher_corps(body)

func _on_corps_quitte(body: Node2D) -> void:
	_corps_en_contact.erase(body)

## Tant qu'un sorcier reste collé au corps : re-hit périodique (le
## knockback le repousse aussitôt, mais un sorcier peut revenir se coller)
func _re_toucher_corps() -> void:
	# Nettoyage des sorciers libérés (mort pendant le contact)
	_corps_en_contact = _corps_en_contact.filter(is_instance_valid)
	for corps in _corps_en_contact:
		_toucher_corps(corps)

## 1 dégât + rebond à 45° vers le haut de l'intérieur de la salle.
## Le sorcier.hit() applique son propre knockback (repoussé par l'ennemi
## le plus proche) : on le REMPLACE par notre direction calibrée —
## c'est le renvoi à 45° qui garantit que le sorcier ne sort jamais de
## l'écran et ne retombe pas sur les piques au sol.
func _toucher_corps(body: Node2D) -> void:
	# Le knockback s'applique même si le hit est absorbé par le cooldown :
	# le corps éjecte, dégâts ou pas.
	body.set("hit_knockback_timer", 0.3)
	body.set("hit_knockback_velocity", _dir_rebond * FORCE_REBOND)
	if body.get("can_take_damage") == true:
		body.hit(DGT_CONTACT_CORPS)
		# hit() réécrit le knockback après nous : on re-override APRÈS
		body.set("hit_knockback_timer", 0.3)
		body.set("hit_knockback_velocity", _dir_rebond * FORCE_REBOND)
