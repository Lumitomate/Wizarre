class_name GamblingMachine
extends Area2D

## La machine à sous du magasin casino (shop_gambling) : 3 rouleaux —
## sorcier ciblé / tube de livraison / attaque livrée — tournent en
## continu. Chaque plaque de pression, enfoncée à fond (16 px, ~0,3 s),
## verrouille et lance l'animation lumière correspondante ; le rouleau
## continue de tourner PENDANT la lumière, puis se cale à sa fin (Q3/Q11).
## Quand les 3 rouleaux sont calés, l'objet-attaque apparaît au-dessus de
## la machine et vole vers le tube du sorcier ciblé (vol d'absorption de
## AttackObject, en FORÇANT l'index du tube — le rouleau central décide,
## pas la sélection du joueur, cf. Q4). La scène hôte ouvre alors sa porte
## de sortie (signal livraison_terminee).
##
## Rappel des décisions validées :
##  - n'importe quel joueur peut appuyer n'importe quelle plaque, dans
##    n'importe quel ordre ; plaques one-shot ; lumières en parallèle (Q3) ;
##  - n'importe quelle attaque dans n'importe quel tube, remplacement pur,
##    pas de recharge de munitions, tier recalculé à l'arrivée (Q2/Q4) ;
##  - TIRAGE OPTIMISÉ (grillé) : le résultat ne dépend plus du timing —
##    la combinaison (sorcier / tube / objet) est tirée au premier
##    verrouillage de plaque et les 3 rouleaux sont forcés dessus (cf.
##    _tirer_combinaison). 3 % de chance de tirage totalement aléatoire.

signal livraison_terminee

enum Slot { GAUCHE, CENTRE, DROITE }

## Vitesse d'enfoncement des plaques : 16 px en 0,3 s (Q14).
const VITESSE_ENFONCEMENT := 16.0 / 0.3
## Enfoncement total déclenchant la lumière (px, Q14).
const PLAQUE_TRAVEL := 16.0
## Position (locale machine) d'apparition de l'objet livré : au-dessus de
## la machine.
const POSITION_LIVRAISON := Vector2(0, -180)
## Pause (s) entre le calage du 3e rouleau et l'envol de l'objet :
## le joueur a le temps de LIRE la combinaison figée dans les vitrines
## avant que la récompense ne prenne le relais (comportement des vraies
## machines à sous).
const PAUSE_LIVRAISON := 0.6
## Chance (grillée Q : 3 %) que la machine parte en vrille et fasse un
## tirage TOTALEMENT aléatoire — sorcier, tube et objet tirés au hasard,
## sans tenir compte de l'état des sacs. Un vrai parfum de casino :
## la machine peut « se tromper » même quand elle sait quoi donner.
const CHANCE_ALEATOIRE := 0.03

## Frame 1 de l'animation idle du sorcier (Q5) : la même image pour tous
## les joueurs, teintée par la palette de leur couleur (WizardPalette) —
## il n'existe pas 4 PNG distincts, la couleur vient du shader.
const SORCIER_IDLE_1: Texture2D = preload(
	"res://assets/sprites/Sorciers/sorcier_v2/SorcierV2_Idle/Sorciers_v2_Idle_1.png")
const SHADER_SORCIER: Shader = preload("res://assets/shaders/wizard_color.gdshader")

## Rouleau 2 (Q6) : tubes au niveau de munitions 4 (plein), frame 1 du
## soulèvement — l'ordre Charbon / Énergie / Tainted correspond aux tubes
## 0 / 1 / 2 du sac (cf. sorcerer_sac.gd).
const TUYAUX: Array[Texture2D] = [
	preload("res://assets/sprites/Sorciers/Sac/TuyauSac/TuyauSac_Charbon/TuyauSac_Charbon_4/TuyauSac_Charbon4_1.png"),
	preload("res://assets/sprites/Sorciers/Sac/TuyauSac/TuyauSac_Energie/TuyauSac_Energie_4/TuyauSac_Energie4_1.png"),
	preload("res://assets/sprites/Sorciers/Sac/TuyauSac/TuyauSac_Tainted/TuyauSac_Tainted_4/TuyauSac_Tainted4_1.png"),
]

## Rouleau 3 (Q7/Q8) : les 12 objets du spawner du magasin (F0 exclu,
## attaque de test), dans l'ordre de AttackType — extraits des scènes
## obj_*.tscn pour utiliser EXACTEMENT les mêmes sprites que le magasin.
const SCENES_OBJETS: Array[PackedScene] = [
	preload("res://scenes/objets/obj_f1_medal.tscn"),
	preload("res://scenes/objets/obj_f2_crown.tscn"),
	preload("res://scenes/objets/obj_f3_belt.tscn"),
	preload("res://scenes/objets/obj_g1_mitten.tscn"),
	preload("res://scenes/objets/obj_g2_scarf.tscn"),
	preload("res://scenes/objets/obj_g3_beanie.tscn"),
	preload("res://scenes/objets/obj_l1_mirror.tscn"),
	preload("res://scenes/objets/obj_l2_comb.tscn"),
	preload("res://scenes/objets/obj_l3_brosse.tscn"),
	preload("res://scenes/objets/obj_p1_seeds.tscn"),
	preload("res://scenes/objets/obj_p2_jar.tscn"),
	preload("res://scenes/objets/obj_p3_bramble.tscn"),
]
## Les types livrés, même ordre que SCENES_OBJETS (F0 absent).
const TYPES_OBJETS: Array[GlobalEnum.AttackType] = [
	GlobalEnum.AttackType.F1, GlobalEnum.AttackType.F2, GlobalEnum.AttackType.F3,
	GlobalEnum.AttackType.G1, GlobalEnum.AttackType.G2, GlobalEnum.AttackType.G3,
	GlobalEnum.AttackType.L1, GlobalEnum.AttackType.L2, GlobalEnum.AttackType.L3,
	GlobalEnum.AttackType.P1, GlobalEnum.AttackType.P2, GlobalEnum.AttackType.P3,
]
## Familles des objets (même ordre) — reprise du mapping de
## spawner_object.gd (F/P → Fossil, G → Tainted, L → Pure) : utilisée
## pour la couleur de la sphère de vol uniquement.
const FAMILLES_OBJETS: Array[GlobalEnum.AttackFamily] = [
	GlobalEnum.AttackFamily.Fossil, GlobalEnum.AttackFamily.Fossil, GlobalEnum.AttackFamily.Fossil,
	GlobalEnum.AttackFamily.Tainted, GlobalEnum.AttackFamily.Tainted, GlobalEnum.AttackFamily.Tainted,
	GlobalEnum.AttackFamily.Pure, GlobalEnum.AttackFamily.Pure, GlobalEnum.AttackFamily.Pure,
	GlobalEnum.AttackFamily.Fossil, GlobalEnum.AttackFamily.Fossil, GlobalEnum.AttackFamily.Fossil,
]

## État de chaque plaque : sprite mobile, profondeur d'enfoncement,
## nombre de corps dessus, verrouillage one-shot (Q3/Q14).
var _plaques: Array[Dictionary] = []
var _rouleaux: Array[GamblingReel] = []
## Couleurs affichées sur le rouleau 1, dans l'ordre des symboles de la
## liste de base (le rouleau répète la liste jusqu'à 4 symboles : le
## modulo de l'index rouleau retombe sur cette liste, cf. GamblingReel).
var _couleurs_rouleau: Array[GlobalEnum.SorcererColor] = []
var _livraison_faite := false
## Combinaison tirée (décision grillée : tirage optimisé, forçage des
## rouleaux) : calculée au PREMIER verrouillage de plaque, puis les 3
## rouleaux sont forcés dessus. L'ordre d'arrêt des rouleaux, choisi par
## les joueurs, ne change donc rien au résultat ; le timing ne décide
## plus rien — la présentation (plaques, lumières, backspin) reste
## identique. Vide = combinaison pas encore tirée.
var _combinaison: Dictionary = {}


func _ready() -> void:
	_lancer_engrenages()
	_preparer_plaques()
	_preparer_lumieres()
	# Les rouleaux dépendent des joueurs : la machine est un ENFANT de la
	# scène du magasin, son _ready tourne donc AVANT celui de la scène
	# hôte — or c'est l'hôte qui spawn les sorciers (spawn_all_players).
	# À ce stade, PlayerManager.players référence encore les sorciers de
	# la scène PRÉCÉDENTE, déjà libérés. On construit les rouleaux en
	# différé : l'appel s'exécute après le _ready de l'hôte, avec les
	# sorciers tout frais de cette scène.
	_construire_rouleaux.call_deferred()


## Engrenages (Q15) : tous jouent « default » en boucle au chargement de
## la scène ; l'engrenage décalé 2 tourne en reverse (play_backwards, sa
## SpriteFrames décalée est conservée). Plus d'autoplay dans la scène :
## tout est piloté ici.
func _lancer_engrenages() -> void:
	$Engernage1.play(&"default")
	$EngrenageDecale2.play_backwards(&"default")
	$Engernage3.play(&"default")
	$Engernage4.play(&"default")


func _construire_rouleaux() -> void:
	_rouleaux = [
		$SlotGauche/Vitrine/Rouleau as GamblingReel,
		$SlotCentre/Vitrine/Rouleau as GamblingReel,
		$SlotDroite/Vitrine/Rouleau as GamblingReel,
	]
	_rouleaux[Slot.GAUCHE].configurer(_entrees_sorciers())
	_rouleaux[Slot.CENTRE].configurer(_entrees_tuyaux())
	_rouleaux[Slot.DROITE].configurer(_entrees_objets())
	for rouleau in _rouleaux:
		rouleau.calage_termine.connect(_on_rouleau_cale)


## Rouleau 1 (Q5/Q9) : un symbole par joueur EN JEU, ordre des emplacements
## 0→3, même image d'idle teintée par la palette du joueur. Sans joueur
## (tests headless) : repli sur les 2 couleurs de base Red/Green pour que
## la machine reste lisible et testable.
func _entrees_sorciers() -> Array[Dictionary]:
	var joueurs: Array[Dictionary] = []
	for controller_id in PlayerManager.active_player_ids():
		# Lecture non typée : l'entrée peut être une instance libérée
		# (changement de scène), l'assignation typée planterait avant
		# même le test de validité.
		var player = PlayerManager.players.get(controller_id)
		if player == null or not is_instance_valid(player):
			continue
		joueurs.append({
			"slot": PlayerManager.get_player_slot(controller_id),
			"couleur": player.sorcerer_color,
		})
	if joueurs.is_empty():
		joueurs = [
			{"slot": 0, "couleur": GlobalEnum.SorcererColor.Red},
			{"slot": 1, "couleur": GlobalEnum.SorcererColor.Green},
		]
	joueurs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["slot"]) < int(b["slot"]))
	var entrees: Array[Dictionary] = []
	_couleurs_rouleau.clear()
	for joueur in joueurs:
		var couleur: GlobalEnum.SorcererColor = joueur["couleur"]
		var materiau := ShaderMaterial.new()
		materiau.shader = SHADER_SORCIER
		WizardPalette.apply_to_material(materiau, couleur)
		entrees.append({"texture": SORCIER_IDLE_1, "material": materiau})
		_couleurs_rouleau.append(couleur)
	return entrees


func _entrees_tuyaux() -> Array[Dictionary]:
	var entrees: Array[Dictionary] = []
	for texture in TUYAUX:
		entrees.append({"texture": texture})
	return entrees


func _entrees_objets() -> Array[Dictionary]:
	var entrees: Array[Dictionary] = []
	for scene in SCENES_OBJETS:
		# Hors arbre : pas de _ready, on ne fait que lire ses SpriteFrames
		var objet: AttackObject = scene.instantiate()
		var animation := objet.get_node("ObjetAttaqueAnimation") as AnimatedSprite2D
		entrees.append({"texture": animation.sprite_frames.get_frame_texture(&"Bronze", 0)})
		objet.free()
	return entrees


func _preparer_plaques() -> void:
	var piliers: Array[StaticBody2D] = [
		$PlaquePressionGauche, $PlaquePressionCentre, $PlaquePressionDroite,
	]
	_plaques.clear()
	for i in piliers.size():
		var pilier := piliers[i]
		var sprite: Sprite2D = null
		for enfant in pilier.get_children():
			if enfant is Sprite2D:
				sprite = enfant
				break
		# La zone de détection est un enfant du pilier solide : elle suit
		# son enfoncement, donc le joueur resté debout dessus reste détecté.
		var zone := pilier.get_node("ZoneDetection") as Area2D
		_plaques.append({
			"corps": pilier,
			"sprite": sprite,
			"base_y": pilier.position.y,
			"appuis": 0,
			"profondeur": 0.0,
			"verrouillee": false,
		})
		zone.body_entered.connect(_on_plaque_corps_entre.bind(i))
		zone.body_exited.connect(_on_plaque_corps_sorti.bind(i))


## Lumières éteintes au chargement (frame 0, anim non lancée) : elles ne
## jouent qu'au verrouillage de leur plaque (Q14).
func _preparer_lumieres() -> void:
	for lumiere in _lumieres():
		lumiere.stop()
		lumiere.frame = 0


func _lumieres() -> Array[AnimatedSprite2D]:
	return [$LumiereGauche, $LumiereCentre, $LumiereDroite]


func _process(delta: float) -> void:
	for i in _plaques.size():
		var plaque := _plaques[i]
		if bool(plaque["verrouillee"]):
			continue
		var direction := 0.0
		if int(plaque["appuis"]) > 0:
			direction = 1.0
		elif float(plaque["profondeur"]) > 0.0:
			direction = -1.0
		else:
			continue
		# Descente/remontée à vitesse fixe (Q14) ; c'est le PILIER ENTIER
		# (corps solide + sprite + zone) qui bouge : le joueur debout dessus
		# descend avec lui, et la zone de détection le suit.
		plaque["profondeur"] = clampf(
			float(plaque["profondeur"]) + direction * VITESSE_ENFONCEMENT * delta,
			0.0, PLAQUE_TRAVEL)
		var corps := plaque["corps"] as StaticBody2D
		corps.position.y = float(plaque["base_y"]) + float(plaque["profondeur"])
		if float(plaque["profondeur"]) >= PLAQUE_TRAVEL:
			_verrouiller_plaque(i)


func _on_plaque_corps_entre(corps: Node2D, slot: int) -> void:
	if not corps.is_in_group("player_group"):
		return
	appuyer_plaque(slot)


func _on_plaque_corps_sorti(corps: Node2D, slot: int) -> void:
	if not corps.is_in_group("player_group"):
		return
	relacher_plaque(slot)


## Appui d'un corps sur la plaque `slot` (public : aussi utilisé par le
## test headless pour simuler un sorcier sans corps physique).
func appuyer_plaque(slot: int) -> void:
	if slot < 0 or slot >= _plaques.size():
		return
	var plaque := _plaques[slot]
	if bool(plaque["verrouillee"]):
		return
	plaque["appuis"] = int(plaque["appuis"]) + 1


## Relâchement de la plaque `slot` : si elle n'était pas encore à fond,
## elle remonte et ne déclenche rien (Q14).
func relacher_plaque(slot: int) -> void:
	if slot < 0 or slot >= _plaques.size():
		return
	var plaque := _plaques[slot]
	plaque["appuis"] = maxi(0, int(plaque["appuis"]) - 1)


## La plaque est totalement enfoncée (16 px) : verrouillage définitif
## (one-shot, Q3), l'animation lumière joue une fois ; le rouleau continue
## de tourner PENDANT la lumière et se cale à sa fin (Q11).
func _verrouiller_plaque(slot: int) -> void:
	var plaque := _plaques[slot]
	plaque["verrouillee"] = true
	plaque["profondeur"] = PLAQUE_TRAVEL
	# Premier verrouillage : la machine tire la combinaison livrée et
	# force les 3 rouleaux dessus (n'importe laquelle des plaques peut
	# être la première, l'ordre ne compte pas)
	if _combinaison.is_empty():
		_combinaison = _tirer_combinaison()
		_forcer_rouleaux()
	var lumiere := _lumieres()[slot]
	lumiere.frame = 0
	lumiere.play(&"default")
	# Freinage anticipé (Q b) : le rouleau décélère PENDANT la lumière
	# (SpriteFrames : pas de get_animation() en Godot 4 — durée =
	# nb frames / fps), le calage final n'avale qu'une petite distance
	var frames := lumiere.sprite_frames
	_rouleaux[slot].commencer_freinage(
		float(frames.get_frame_count(&"default")) / frames.get_animation_speed(&"default"))
	await lumiere.animation_finished
	_rouleaux[slot].lancer_calage()


func _on_rouleau_cale(_rouleau: GamblingReel) -> void:
	for rouleau in _rouleaux:
		if rouleau.etat != GamblingReel.Etat.ARRETE:
			return
	# Pause de lecture : le triple reste figé dans les vitrines avant
	# l'envol de la récompense (Q b)
	await get_tree().create_timer(PAUSE_LIVRAISON).timeout
	_livrer()


## Tirage de la combinaison livrée (grillées : option forçage, 3 %
## aléatoire, replis simplifiés). Sans la part de chance : 3 tirages
## indépendants au hasard —
##  - sorcier : parmi ceux qui ont un tube vide (sinon tous les sorciers) ;
##  - tube : parmi les tubes vides du sorcier tiré (sinon ses 3 tubes,
##    remplacement pur — règle déjà en place, Q2/Q4) ;
##  - objet : parmi les objets que PERSONNE ne possède (sinon ceux que
##    le sorcier tiré ne possède pas — il y en a toujours : 3 tubes max,
##    12 objets). « Possédé » = état courant des sacs, rien de persistant.
## Sans joueur (tests headless) : équivalent aléatoire total.
func _tirer_combinaison() -> Dictionary:
	var sorciers := _sorciers_actifs()
	if sorciers.is_empty() or randf() < CHANCE_ALEATOIRE:
		return _tirer_aleatoire()
	var sorcier := _tirer_sorcier(sorciers)
	return {
		"couleur": sorcier.sorcerer_color,
		"tube": _tirer_tube(sorcier),
		"type_index": _tirer_type_index(sorcier, sorciers),
	}


## Tirage totalement aléatoire (3 % de CHANCE_ALEATOIRE, ou sans joueur) :
## exactement le comportement d'avant — aucun des tirages optimisés.
func _tirer_aleatoire() -> Dictionary:
	return {
		"couleur": _couleurs_rouleau[randi() % _couleurs_rouleau.size()],
		"tube": randi() % TUYAUX.size(),
		"type_index": randi() % TYPES_OBJETS.size(),
	}


## Sorciers en jeu, valides (lecture non typée : cf. _entrees_sorciers).
func _sorciers_actifs() -> Array[Sorcerer]:
	var sorciers: Array[Sorcerer] = []
	for controller_id in PlayerManager.active_player_ids():
		var player = PlayerManager.players.get(controller_id)
		if player != null and is_instance_valid(player):
			sorciers.append(player)
	return sorciers


## Tube vide = pas d'attaque dans le tube (état courant des sacs).
func _tube_est_vide(sorcier: Sorcerer, tube: int) -> bool:
	var spell = sorcier.spells.get(tube, {})
	return (spell as Dictionary).is_empty()


func _tubes_vides(sorcier: Sorcerer) -> Array[int]:
	var vides: Array[int] = []
	for i in TUYAUX.size():
		if _tube_est_vide(sorcier, i):
			vides.append(i)
	return vides


## Types d'attaque possédés par un sorcier (set de GlobalEnum.AttackType).
func _types_possedes(sorcier: Sorcerer) -> Dictionary:
	var possedes := {}
	for i in TUYAUX.size():
		if not _tube_est_vide(sorcier, i):
			possedes[sorcier.spells[i]["attack_type"]] = true
	return possedes


## Sorcier tiré : parmi ceux qui ont un tube vide (pour que l'objet
## puisse être reçu sans remplacement) ; si tous les sacs sont pleins,
## parmi tous les sorciers.
func _tirer_sorcier(sorciers: Array[Sorcerer]) -> Sorcerer:
	var eligibles: Array[Sorcerer] = []
	for s in sorciers:
		if not _tubes_vides(s).is_empty():
			eligibles.append(s)
	if eligibles.is_empty():
		eligibles = sorciers
	return eligibles[randi() % eligibles.size()]


## Tube du sorcier tiré : parmi ses tubes vides ; s'il n'en a plus,
## parmi ses 3 tubes (l'objet remplacera le contenu du tube).
func _tirer_tube(sorcier: Sorcerer) -> int:
	var vides := _tubes_vides(sorcier)
	if vides.is_empty():
		for i in TUYAUX.size():
			vides.append(i)
	return vides[randi() % vides.size()]


## Objet livré : parmi les objets que personne ne possède (priorité
## globale) ; si tout est possédé (cas limite 4×3=12), parmi les objets
## que le sorcier tiré ne possède pas — il y en a toujours (3 tubes max).
func _tirer_type_index(sorcier: Sorcerer, sorciers: Array[Sorcerer]) -> int:
	var possedes_tous := {}
	for s in sorciers:
		for type in _types_possedes(s):
			possedes_tous[type] = true
	var disponibles: Array[int] = []
	for i in TYPES_OBJETS.size():
		if not possedes_tous.has(TYPES_OBJETS[i]):
			disponibles.append(i)
	if disponibles.is_empty():
		var possedes_sien := _types_possedes(sorcier)
		for i in TYPES_OBJETS.size():
			if not possedes_sien.has(TYPES_OBJETS[i]):
				disponibles.append(i)
	return disponibles[randi() % disponibles.size()]


## Force les 3 rouleaux sur la combinaison tirée : chaque rouleau se
## calera sur le symbole cible au lieu du « prochain cran » du timing.
## Index de base : l'index du rouleau forcé est l'index dans la liste de
## base (configurer duplique la liste en ordre, donc _symboles[i] ==
## base[i] pour i < taille de base) — le même joueur apparaît plusieurs
## fois sur le rouleau, n'importe quelle occurrence est valable.
func _forcer_rouleaux() -> void:
	var idx_sorcier := 0
	for i in _couleurs_rouleau.size():
		if _couleurs_rouleau[i] == _combinaison["couleur"]:
			idx_sorcier = i
			break
	_rouleaux[Slot.GAUCHE].forcer_cible(idx_sorcier)
	_rouleaux[Slot.CENTRE].forcer_cible(int(_combinaison["tube"]))
	_rouleaux[Slot.DROITE].forcer_cible(int(_combinaison["type_index"]))


## Livraison (Q4) : l'objet-attaque du rouleau 3 apparaît au-dessus de la
## machine puis vole vers le tube du rouleau 2 du sorcier du rouleau 1.
## Pas de recharge de munitions (set_attack n'y touche pas) ; le tier est
## recalculé à l'arrivée par AttackObject (règle : nombre d'attaques du
## même élément). La machine devient ensuite inerte (Q19).
func _livrer() -> void:
	if _livraison_faite:
		return
	_livraison_faite = true
	# La machine devient inerte (Q19) : plaques toutes verrouillées, plus
	# rien à animer ici — on coupe le processing (AttackObject gère le
	# vol d'absorption de son côté)
	set_process(false)
	var cible := resultat()
	var sorcier := _sorcier_par_couleur(cible["couleur"])
	if sorcier == null:
		# Pas de sorcier correspondant (tests headless sans joueurs) :
		# rien à livrer, mais la fin de visite reste signalée à la scène
		livraison_terminee.emit()
		return
	var index: int = cible["type_index"]
	var objet: AttackObject = SCENES_OBJETS[index].instantiate()
	# Ajouté au parent (la scène du niveau, échelle 1) pour hériter de la
	# taille standard des objets de magasin (×2, cf. spawner_object.gd)
	get_parent().add_child(objet)
	objet.global_position = to_global(POSITION_LIVRAISON)
	objet.scale = Vector2(2.0, 2.0)
	objet.item_attack_family = FAMILLES_OBJETS[index]
	objet.item_attack_type = cible["type"]
	objet.item_attack_tier = GlobalEnum.AttackTier.I
	objet.delivre.connect(func(_s: Sorcerer, _t: int) -> void:
		livraison_terminee.emit())
	objet.donner_a(sorcier, int(cible["tube"]))


## Triple désigné par les 3 vitrines : {"couleur": SorcererColor,
## "tube": 0-2 (Charbon/Énergie/Tainted), "type": AttackType,
## "type_index": index dans TYPES_OBJETS/SCENES_OBJETS}.
func resultat() -> Dictionary:
	var couleur: GlobalEnum.SorcererColor = _couleurs_rouleau[
		posmod(_rouleaux[Slot.GAUCHE].symbole_central(), _couleurs_rouleau.size())]
	var tube: int = _rouleaux[Slot.CENTRE].symbole_central() % TUYAUX.size()
	var type_index: int = _rouleaux[Slot.DROITE].symbole_central() % TYPES_OBJETS.size()
	return {
		"couleur": couleur,
		"tube": tube,
		"type": TYPES_OBJETS[type_index],
		"type_index": type_index,
	}


func _sorcier_par_couleur(couleur: GlobalEnum.SorcererColor) -> Sorcerer:
	for controller_id in PlayerManager.active_player_ids():
		var player = PlayerManager.players.get(controller_id)
		if player != null and is_instance_valid(player) and player.sorcerer_color == couleur:
			return player
	return null
