class_name Cabin extends Node2D

## Cabine du magasin (remplace la bulle de verre, cf. CONTEXT.md). Un
## sorcier s'y enferme, choisit un tube d'attaque, et un bras robotisé
## installe le power-up de la boutique dans ce tube. Une fois consommée,
## la cabine est inerte.
##
## Le changement de sort est RÉEL : il est appliqué juste avant la
## réouverture des portes (Sorcerer.set_attack). Tout le rituel (charge
## des lumières, explosion, bras) n'en est que la mise en scène.
##
## L'entrée et les murs sont GÉNÉRÉS depuis CollisionShape2D_Interieur :
## la scène ne contient que des repères, on peut donc déplacer la cabine
## entière sans repositionner une foule de nœuds.
##
## Les appuis de boutons sont poussés par appui_bouton() : en jeu depuis
## _process, dans les tests directement (lit_entree = false).
##
## Une cabine peut être VERROUILLÉE (verrouillee, ex. l'épreuve des
## plaques de pression du magasin reflex) : portes fermées, entrée et
## murs bloqués, jusqu'à l'appel de ouvrir() — alors les portes s'ouvrent
## tout de suite et restent ouvertes jusqu'à ce qu'un sorcier entre.

signal sort_installe(sorcier: Sorcerer, tube_index: int, attack_type: int, attack_tier: int)

enum Etat { ACTIVE, OCCUPIED, CONFIRMING, INSTALLING, RETRACTING, DONE, INERT }

## Montée des 3 tuyaux à l'entrée (la propre animation du tuyau ajoute
## ensuite ses 15 px intégrés quand le tube choisi sort).
const SORTIE_TUYAUX := 25.0
## Durée du glissement des tuyaux qui sortent (et qui se replient) à
## l'entrée / à la sortie du sorcier.
const DUREE_SORTIE_TUYAUX := 0.5
## Très léger décalage entre le départ des tuyaux, de la gauche vers la
## droite (Fossil, puis energy, puis tainted).
const DECALAGE_TUYAUX := 0.08
## Épaisseur des murs physiques générés autour de l'intérieur (local).
const EPAISSEUR_MURS := 6.0
## Le seuil de détection est le rectangle intérieur réduit de ce facteur :
## le sorcier est ainsi bien à l'intérieur quand les murs se ferment.
const FACTEUR_SEUIL := 0.4
## z_index de la porte quand un sorcier est enfermé (la porte passe
## DEVANT lui). Hors occupation, elle retrouve son z_index de base.
const Z_PORTE_DEVANT := 5
## Réduction totale de la largeur de l'espace de jeu (px), répartie sur
## les deux côtés (1 px par mur latéral quand vaut 2).
const RETRAIT_HORIZONTAL := 2.0
## Réduction totale de la hauteur de l'espace de jeu (px), répartie entre
## le plafond et le sol.
const RETRAIT_VERTICAL := 2.0
## Durée du fondu (s) des icônes du panneau : fade in à l'apparition,
## fade out à la disparition.
const FADE_ICONES := 0.2
## Fraction de la charge sur laquelle la lumière monte en opacité (la
## frame 0 de la lumière est vide ; sans cette rampe, l'allumage saute
## d'un coup à la frame 1, déjà à moitié opaque).
const FONDU_LUMIERE := 0.18

@onready var _pipes: Array[Pipe] = [$"Pipe Fossil", $"Pipe energy", $"Pipe tainted"]
@onready var _box: AnimatedSprite2D = $AnimatedSprite2D_box
@onready var _porte: AnimatedSprite2D = $AnimatedSprite2D_porte
## Repères de placement (inertes) et zone de détection, séparés des
## sprites : la racine est un simple Node2D, aucun repère n'est une zone.
@onready var _interieur: CollisionShape2D = $Reperes/CollisionShape2D_Interieur
@onready var _zone_entree: Area2D = $ZoneEntree
@onready var _murs_racine: Node2D = $Murs
@onready var _bras: AnimatedSprite2D = $AnimatedSprite2D_bras
@onready var _explosion: AnimatedSprite2D = $AnimatedSprite2D_explosion
@onready var _receptacle: Sprite2D = $BulleV2Receptacle1
@onready var _boutons_lumiere: Array[AnimatedSprite2D] = [
	$"BoutonsLumiere/BoutonLumiere_fossil",
	$"BoutonsLumiere/BoutonLumiere_energy",
	$"BoutonsLumiere/BoutonLumiere_tainted",
]
@onready var _icones_panneau: Array[AnimatedSprite2D] = [
	$"BoutonsLumiere/BoutonLumiere_fossil/Icone",
	$"BoutonsLumiere/BoutonLumiere_energy/Icone",
	$"BoutonsLumiere/BoutonLumiere_tainted/Icone",
]
@onready var _icone_receptacle: AnimatedSprite2D = $Icones/IconeReceptacle

## État courant (observable par les tests et l'hôte).
var etat: Etat = Etat.ACTIVE
## Sorcier enfermé (null sinon).
var sorcier: Sorcerer = null
## Power-up posé dans la cabine (null quand la cabine est inerte).
var objet: AttackObject = null
## Lecture manette/clavier active : faux dans les tests, qui poussent les
## appuis via appui_bouton().
var lit_entree: bool = true
## Cabine fermée de base (ex. épreuve des plaques de pression) : porte
## fermée, entrée refusée et murs bloqués jusqu'à ouvrir(). Faux par
## défaut : les cabines du magasin intro restent ouvertes tant qu'un
## sorcier n'est pas entré.
var verrouillee := false

var _appuye: Array[bool] = [false, false, false]
var _charge: Array[float] = [0.0, 0.0, 0.0]
var _duree_charge := 1.0
## Nombre de frames VISIBLES de la lumière (on retire la frame 0, vide).
var _nb_frames_lumiere := 6

var _tube_choisi := -1
var _type_choisi := -1
var _tier_choisi := 0

var _z_porte_base := 0
## La porte a fini de se fermer : les tuyaux sortent, le panneau
## apparaît, et le choix du tube devient possible.
var _porte_fermee := false
## Frame de fermeture de la porte où le sac du sorcier est masqué
## (avant-dernière frame) ; il réapparaît à l'ouverture.
var _frame_sac_cache := 0
## Tweens de fondu en cours, par icône (pour tuer un fondu précédent).
var _tweens_icones: Dictionary = {}
var _positions_tuyaux: Array[Vector2] = []
var _murs: Array[StaticBody2D] = []
var _explosion_finie := false
var _tuyau_sorti := false
var _marque_30 := false
var _marque_63 := false
var _marque_86 := false


func _ready() -> void:
	for p in _pipes:
		_positions_tuyaux.append(p.position)
	_z_porte_base = _porte.z_index
	_frame_sac_cache = maxi(
		_porte.sprite_frames.get_frame_count(_porte.animation) - 2, 0)
	_nb_frames_lumiere = maxi(
		_boutons_lumiere[0].sprite_frames.get_frame_count(_boutons_lumiere[0].animation) - 1, 1)
	_duree_charge = _duree_lumiere()
	# Les 3 lumières commencent sur la frame VIDE (aucune allumée au
	# repos, cf. SpriteFrames : frame 0 = texture nulle).
	for lumiere in _boutons_lumiere:
		lumiere.frame = 0
		lumiere.frame_progress = 0.0
	_initialiser_detection()
	_creer_murs()
	_porte.frame = 0   # porte ouverte
	_box.frame = 11    # ombre de porte ouverte
	if verrouillee:
		_appliquer_fermee()
	_bras.frame = 0    # bras rangé
	_explosion.visible = false
	_icone_receptacle.visible = false
	_masquer_icones_panneau()
	child_entered_tree.connect(_on_enfant)
	_explosion.animation_finished.connect(_on_explosion_finie)
	_bras.animation_finished.connect(_on_bras_finie)
	_porte.animation_finished.connect(_on_porte_finie)
	_zone_entree.body_entered.connect(_on_body_entered)
	_zone_entree.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	match etat:
		Etat.OCCUPIED:
			_lire_entree()
			_avancer_charge(delta)
			_maj_sac()
		Etat.CONFIRMING:
			# L'objet posé disparaît à la frame 3 de l'explosion
			if objet != null and is_instance_valid(objet) and objet.visible \
					and _explosion.frame >= 3:
				objet.visible = false
		Etat.INSTALLING:
			_surveiller_bras()


# --- API publique (seams) ---

## Déverrouille une cabine verrouillée et ouvre ses portes tout de
## suite : c'est le feedback de réussite de l'épreuve. Les portes
## restent ouvertes jusqu'à ce qu'un sorcier entre (rituel normal).
## Sans effet sur une cabine non verrouillée.
func ouvrir() -> void:
	if not verrouillee:
		return
	verrouillee = false
	_desactiver_murs()
	_zone_entree.monitoring = true
	_ouvrir_portes()


## Le sorcier entre : la cabine se verrouille autour de lui et démarre le
## rituel de choix. Appelée par la détection physique.
func entrer(s: Sorcerer) -> void:
	if verrouillee or etat != Etat.ACTIVE or s == null:
		return
	if objet == null or not is_instance_valid(objet):
		return
	sorcier = s
	sorcier.cabin_lock = true
	# Un tube levé à l'entrée (sélection pour attraper un objet) doit être
	# rabattu : le sac va être masqué pendant le rituel, et à sa
	# réapparition aucun tube ne doit rester levé (cf. test
	# test_tube_leve_sortie_shop). Le sac est caché dès la fermeture de la
	# porte : la refermeture passe inaperçue.
	sorcier.fermer_tube_selectionne()
	etat = Etat.OCCUPIED
	_porte_fermee = false
	# La porte passe devant le sorcier tant qu'il est enfermé.
	_porte.z_index = Z_PORTE_DEVANT
	_activer_murs()
	_fermer_portes()


## Appui/relâchement d'un bouton d'attaque (0/1/2). En jeu, _process lit
## PlayerInput et le pousse ici ; les tests l'appellent directement.
func appui_bouton(tube: int, enfonce: bool) -> void:
	if tube < 0 or tube >= 3:
		return
	# Le choix ne s'ouvre qu'une fois la porte fermée (et les tuyaux sortis).
	if etat != Etat.OCCUPIED or not _porte_fermee:
		return
	_appuye[tube] = enfonce


## Vrai quand la cabine n'a plus de power-up (utilisée, ou couloir scellé).
func est_inerte() -> bool:
	return objet == null or not is_instance_valid(objet)


## Vrai tant qu'un sorcier occupe la cabine, de son entrée jusqu'à ce
## qu'il soit ressorti (les états ACTIVE et INERT sont libres).
func est_occupee() -> bool:
	return etat != Etat.ACTIVE and etat != Etat.INERT


# --- Détection, murs, portes ---

## État « fermée de base » d'une cabine verrouillée : porte fermée (dernière
## frame de l'anim, ombre sur la première), détection d'entrée coupée et
## murs actifs (la porte n'a pas de collision propre : ce sont eux qui
## bloquent physiquement l'entrée tant que ouvrir() n'est pas appelé).
func _appliquer_fermee() -> void:
	_porte.stop()
	_porte.frame = _porte.sprite_frames.get_frame_count(_porte.animation) - 1
	_box.stop()
	_box.frame = 0
	_zone_entree.monitoring = false
	_activer_murs()


func _initialiser_detection() -> void:
	var rect := _interieur.shape as RectangleShape2D
	if rect == null:
		push_error("Cabin: CollisionShape2D_Interieur doit porter un RectangleShape2D")
		return
	var seuil := CollisionShape2D.new()
	var forme := RectangleShape2D.new()
	forme.size = rect.size * FACTEUR_SEUIL
	seuil.shape = forme
	seuil.position = _interieur.position
	_zone_entree.add_child(seuil)
	_zone_entree.collision_mask = 1
	_zone_entree.monitoring = true


func _creer_murs() -> void:
	var rect := _interieur.shape as RectangleShape2D
	if rect == null:
		return
	# Demi-dimensions de l'espace de jeu. La largeur est réduite de
	# RETRAIT_HORIZONTAL, réparti sur les deux côtés.
	var hx := rect.size.x * 0.5 - RETRAIT_HORIZONTAL * 0.5
	var hy := rect.size.y * 0.5 - RETRAIT_VERTICAL * 0.5
	var centre := _interieur.position
	var t := EPAISSEUR_MURS
	var specs := [
		[Vector2(2.0 * hx + 2.0 * t, t), centre + Vector2(0.0, -hy - t * 0.5)],
		[Vector2(2.0 * hx + 2.0 * t, t), centre + Vector2(0.0, hy + t * 0.5)],
		[Vector2(t, 2.0 * hy + 2.0 * t), centre + Vector2(-hx - t * 0.5, 0.0)],
		[Vector2(t, 2.0 * hy + 2.0 * t), centre + Vector2(hx + t * 0.5, 0.0)],
	]
	for spec in specs:
		var corps := StaticBody2D.new()
		corps.collision_layer = 1
		corps.collision_mask = 0
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = spec[0]
		cs.shape = rs
		cs.position = spec[1]
		cs.disabled = true
		corps.add_child(cs)
		_murs_racine.add_child(corps)
		_murs.append(corps)


func _activer_murs() -> void:
	for corps in _murs:
		(corps.get_child(0) as CollisionShape2D).set_deferred("disabled", false)


func _desactiver_murs() -> void:
	for corps in _murs:
		(corps.get_child(0) as CollisionShape2D).set_deferred("disabled", true)


## La porte a fini de se fermer : les tuyaux sortent et le panneau
## apparaît ; le choix du tube s'ouvre alors.
func _on_porte_finie() -> void:
	if etat != Etat.OCCUPIED:
		return
	_porte_fermee = true
	_sortir_tuyaux()
	_afficher_icones_panneau()


func _fermer_portes() -> void:
	_porte.play(&"default")           # 0 → 11
	_box.play_backwards(&"default")   # 11 → 0


func _ouvrir_portes() -> void:
	_porte.play_backwards(&"default") # 11 → 0
	_box.play(&"default")             # 0 → 11


# --- Tuyaux, icônes ---

func _sortir_tuyaux() -> void:
	for i in range(3):
		var p := _pipes[i]
		if sorcier != null:
			p.set_ammo(sorcier.energy_counts[i])
			p.set_spell(sorcier.spells.get(i, {}))
		_glisser_tuyau(p, _positions_tuyaux[i] + Vector2(0.0, -SORTIE_TUYAUX),
			float(i) * DECALAGE_TUYAUX)


## Replie les 3 tuyaux, en parallèle, et renvoie le Tween (pour attendre
## leur rentrée complète avant d'ouvrir la porte).
func _replier_tuyaux() -> Tween:
	var t := create_tween()
	t.set_parallel(true)
	for i in range(3):
		_pipes[i].reset_display()
		t.tween_property(_pipes[i], "position", _positions_tuyaux[i], DUREE_SORTIE_TUYAUX)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return t


## Glisse un tuyau vers `cible` (sortie de 25 px, ou repli), après
## `delai` secondes (léger décalage gauche → droite à la sortie).
func _glisser_tuyau(p: Pipe, cible: Vector2, delai: float = 0.0) -> void:
	var t := create_tween()
	t.tween_property(p, "position", cible, DUREE_SORTIE_TUYAUX)\
		.set_delay(delai)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _afficher_icones_panneau() -> void:
	for i in range(3):
		if sorcier == null:
			_estomper(_icones_panneau[i], 0.0, true)
			continue
		var spell: Dictionary = sorcier.spells.get(i, {})
		_poser_icone(_icones_panneau[i], spell.get("attack_type", -1), true)


func _masquer_icones_panneau() -> void:
	for icone in _icones_panneau:
		_estomper(icone, 0.0, true)


## Pose l'icône d'un sort sur un sprite. `fade` : apparition en fondu si
## l'icône n'était pas déjà affichée. Un sort invalide (vide) la fait
## disparaître en fondu.
func _poser_icone(icone: AnimatedSprite2D, attack_type: int, fade: bool = false) -> void:
	var anim := SpellIcons.anim_name(attack_type)
	if anim == "" or not icone.sprite_frames.has_animation(anim):
		_estomper(icone, 0.0, true)
		return
	var deja := icone.visible and icone.animation == anim
	icone.animation = anim
	icone.frame = 0
	icone.visible = true
	if fade and not deja:
		_estomper(icone, 1.0, false)
	else:
		icone.modulate.a = 1.0


## Fondu d'une icône vers `cible`, puis masquage si `cacher`.
func _estomper(icone: AnimatedSprite2D, cible: float, cacher: bool) -> void:
	if not icone.visible and cible <= 0.0:
		return
	var precedent: Tween = _tweens_icones.get(icone)
	if precedent != null and precedent.is_valid():
		precedent.kill()
	icone.visible = true
	var t := create_tween()
	_tweens_icones[icone] = t
	t.tween_property(icone, "modulate:a", cible, FADE_ICONES)
	if cacher:
		t.tween_callback(func() -> void: icone.visible = false)


# --- Charge des lumières ---

func _lire_entree() -> void:
	if not lit_entree or sorcier == null or not is_instance_valid(sorcier):
		return
	for t in range(3):
		appui_bouton(t, PlayerInput.button_pressed(sorcier.input_device, _action(t)))


func _avancer_charge(delta: float) -> void:
	var pas := delta / maxf(_duree_charge, 0.001)
	for t in range(3):
		var avant := _charge[t]
		_charge[t] = clampf(_charge[t] + (pas if _appuye[t] else -pas), 0.0, 1.0)
		_actualiser_bouton_lumiere(t)
		if avant < 1.0 and _charge[t] >= 1.0:
			_confirmer(t)
			return


## La frame 0 est VIDE : on ne s'en sert que pour l'état éteint. Dès que
## la charge commence, on passe à la frame 1 (première vraie frame) et on
## progresse sur les frames 1..N ; l'opacité monte sur le début de la
## charge pour un allumage progressif, sans saut.
func _actualiser_bouton_lumiere(tube: int) -> void:
	var lumiere := _boutons_lumiere[tube]
	var charge := clampf(_charge[tube], 0.0, 1.0)
	if charge <= 0.0:
		lumiere.frame = 0
		lumiere.modulate.a = 1.0
		return
	lumiere.frame = 1 + clampi(floori(charge * float(_nb_frames_lumiere)),
		0, _nb_frames_lumiere - 1)
	lumiere.modulate.a = clampf(charge / FONDU_LUMIERE, 0.0, 1.0)


func _confirmer(tube: int) -> void:
	etat = Etat.CONFIRMING
	_tube_choisi = tube
	_type_choisi = objet.item_attack_type
	_tier_choisi = _tier_projete(tube, _type_choisi)
	_boutons_lumiere[tube].frame = _boutons_lumiere[tube].sprite_frames.get_frame_count(
		_boutons_lumiere[tube].animation) - 1
	_explosion_finie = false
	_tuyau_sorti = false
	_explosion.frame = 0
	_explosion.visible = true
	_explosion.play(&"default")
	_pipes[tube].tube_sorti.connect(_on_tuyau_sorti, CONNECT_ONE_SHOT)
	_pipes[tube].play_grow()


func _on_explosion_finie() -> void:
	_explosion_finie = true
	_explosion.visible = false
	_verifier_fin_confirmation()


func _on_tuyau_sorti() -> void:
	_tuyau_sorti = true
	_verifier_fin_confirmation()


func _verifier_fin_confirmation() -> void:
	if etat == Etat.CONFIRMING and _explosion_finie and _tuyau_sorti:
		_demarrer_installation()


# --- Installation par le bras ---

func _demarrer_installation() -> void:
	etat = Etat.INSTALLING
	_marque_30 = false
	_marque_63 = false
	_marque_86 = false
	_icone_receptacle.modulate.a = 1.0
	_poser_icone(_icone_receptacle, _type_choisi)
	_bras.frame = 0
	_bras.play(_anim_bras(_tube_choisi))


func _surveiller_bras() -> void:
	var f := _bras.frame
	if f >= 30 and not _marque_30:
		_marque_30 = true
		_receptacle.visible = false
		_icone_receptacle.visible = false
	if f >= 63 and not _marque_63:
		_marque_63 = true
		_pipes[_tube_choisi].set_spell({
			"attack_type": _type_choisi,
			"attack_tier": _tier_choisi,
		})
		# L'icône est dans le tube : les lumières ont fini leur rôle (on
		# masque les trois, une lumière secondaire à moitié allumée ne doit
		# pas rester affichée).
		for lumiere in _boutons_lumiere:
			lumiere.visible = false
	if f >= 86 and not _marque_86:
		_marque_86 = true
		_poser_icone(_icones_panneau[_tube_choisi], _type_choisi, true)


func _on_bras_finie() -> void:
	if etat != Etat.INSTALLING:
		return
	etat = Etat.RETRACTING
	_masquer_icones_panneau()
	# On attend que les tuyaux soient complètement rentrés avant d'ouvrir
	# la porte (et donc de libérer le sorcier).
	await _replier_tuyaux().finished
	etat = Etat.DONE
	if sorcier != null and is_instance_valid(sorcier):
		# Le changement RÉEL, juste avant la réouverture des portes.
		sorcier.set_attack(_tube_choisi, _type_choisi, _tier_choisi)
		sorcier.cabin_lock = false
		sort_installe.emit(sorcier, _tube_choisi, _type_choisi, _tier_choisi)
	_ouvrir_portes()
	# La porte s'ouvre : le sac du sorcier réapparaît.
	_afficher_sac()
	_desactiver_murs()


## Sac du sorcier enfermé (PipeManager), ou null.
func _sac_du_sorcier() -> Node2D:
	if sorcier == null or not is_instance_valid(sorcier):
		return null
	return sorcier.get_node_or_null("PipeManager") as Node2D


## Masque le sac dès que la fermeture de la porte atteint l'avant-
## dernière frame (le sac n'a plus à être visible depuis l'extérieur).
func _maj_sac() -> void:
	var sac := _sac_du_sorcier()
	if sac != null and sac.visible and _porte.frame >= _frame_sac_cache:
		sac.visible = false


func _afficher_sac() -> void:
	var sac := _sac_du_sorcier()
	if sac != null:
		sac.visible = true


# --- Détection physique ---

func _on_body_entered(body: Node2D) -> void:
	if etat != Etat.ACTIVE:
		return
	if body is Sorcerer and body.is_in_group("player_group"):
		entrer(body as Sorcerer)


func _on_body_exited(body: Node2D) -> void:
	if etat == Etat.DONE and body == sorcier:
		etat = Etat.INERT
		# Le sorcier est sorti : la porte retrouve son z_index de base.
		_porte.z_index = _z_porte_base


func _on_enfant(child: Node) -> void:
	if child is AttackObject and objet == null:
		objet = child
		objet.capturable = false


# --- Utilitaires ---

func _duree_lumiere() -> float:
	var p: AnimatedSprite2D = _boutons_lumiere[0]
	var vitesse := p.sprite_frames.get_animation_speed(p.animation)
	if _nb_frames_lumiere <= 0 or vitesse <= 0.0:
		return 1.0
	return float(_nb_frames_lumiere) / vitesse


func _tier_projete(tube: int, attack_type: int) -> int:
	if sorcier == null:
		return 0
	var projected: Dictionary = sorcier.spells.duplicate(true)
	projected[tube] = {"attack_type": attack_type, "attack_tier": 0}
	return SpellRules.compute_tier(projected, attack_type)


func _anim_bras(tube: int) -> StringName:
	match tube:
		0: return &"bras_fossil"
		1: return &"bras_energie"
		_: return &"bras_tainted"


func _action(tube: int) -> PlayerInput.Action:
	match tube:
		0: return PlayerInput.Action.ATK1
		1: return PlayerInput.Action.ATK2
		_: return PlayerInput.Action.ATK3
