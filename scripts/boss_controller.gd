class_name BossController
extends Node2D

## ═══════════════════════════════════════════════════════════════════════
##  CERVEAU DU BOSS « TENTACULES » — orchestre les 2 moitiés du boss
## ═══════════════════════════════════════════════════════════════════════
##  Règles validées avec le propriétaire :
##
##  YEUX (6 au total, 3 par moitié) :
##   - le corps du boss est invulnérable ; seuls les yeux ouverts sont
##     touchables (1 coup = 1 œil détruit à jamais) ;
##   - toutes les 5 s, le boss ouvre l'œil vivant le PLUS LOIN du sorcier
##     le plus proche de lui (le boss « regarde » là où personne n'est) ;
##   - ~30 % de chance d'ouvrir en plus un 2ᵉ œil, pris de l'AUTRE moitié
##     du boss si possible (les 2 moitiés se coordonnent ici) ;
##   - dernier œil vivant : il clignote (referme puis rouvre aussitôt),
##     quelques frames d'invincibilité à chaque cycle, jamais fermé longtemps.
##
##  SPAWNS (8 au total, 4 par moitié) :
##   - toutes les N secondes (N = 5 s au début, 3 s à un œil vivant —
##     interpolation linéaire), UN point au hasard PAR MOITIÉ se déclenche ;
##   - chaque spawn : ~70 % tentacule / ~30 % ennemi aléatoire ;
##   - limite de 6 ennemis vivants : au-delà, le spawn devient une tentacule.
##
##  MORT (les 6 yeux détruits — les 2 moitiés meurent ENSEMBLE) :
##   1. tous les yeux se ferment (les détruits le sont déjà) ;
##   2. des tentacules courtes sortent des 8 points de spawn puis retombent
##      vers le bas comme des câbles restant attachés au corps ;
##   3. à la fin de la chute : les ennemis restants disparaissent (burst)
##      et la porte de sortie s'ouvre.
## ═══════════════════════════════════════════════════════════════════════

# --- Les deux moitiés du boss (chemins câblés dans boss_fight.tscn) ---
@export var moitie_gauche: NodePath
@export var moitie_droite: NodePath
# La porte de sortie à ouvrir à la mort du boss
@export var porte_sortie: NodePath

# --- Équilibrage des yeux ---
## Intervalle du cycle des yeux (secondes) — ne s'accélère PAS avec la
## destruction des yeux : c'est le rythme des spawns qui accélère.
@export var cycle_oeil_secondes: float = 5.0
## Chance d'ouvrir un 2ᵉ œil (pris de l'autre moitié si possible)
@export_range(0.0, 1.0) var chance_second_oeil: float = 0.3

# --- Équilibrage des spawns ---
## Intervalle de spawn avec 6 yeux vivants (secondes)
@export var spawn_interval_max: float = 5.0
## Intervalle de spawn avec 1 seul œil vivant (secondes)
@export var spawn_interval_min: float = 3.0
## Chance qu'un spawn soit une tentacule (sinon : ennemi aléatoire)
@export_range(0.0, 1.0) var chance_tentacule: float = 0.7
## Limite d'ennemis vivants : au-delà, un spawn « ennemi » devient tentacule
@export var limite_ennemis_vivants: int = 6

# --- Équilibrage de la mort ---
## Longueur des tentacules de mort, en articulations (~3 blocs d'atlas)
@export var articulations_mort: int = 3
## Durée de la chute des câbles avant l'ouverture de la porte (secondes)
@export var duree_chute_mort: float = 2.5

# --- HUD des joueurs (répliqué du niveau : cf. level.gd) ---
signal save_data
const HUD_PANEL_SPACING := 269
const START_Y_POSITION := 25
const SCENE_HUD_JOUEUR := preload("res://scenes/hud/hud_players_info.tscn")

# --- Nœuds ---
var _moitie_gauche: BossHalf
var _moitie_droite: BossHalf
var _porte: Area2D

# Timers : cycle des yeux et cycle des spawns (créés dans _ready)
var _timer_oeil: Timer
var _timer_spawn: Timer
var _mort_en_cours: bool = false
# Début du combat (pour run_duration, comme level.gd level_start_time)
var level_start_time: int = 0

# Scènes des 2 variantes d'ennemis (tirage aléatoire à chaque spawn « ennemi »).
# NB : la mouche (enemy_fly.tscn) est VOLONTAIREMENT exclue du combat de
# boss — demande validée : le boss ne spawn plus de mouches. Le code de
# l'essaim reste en place dans boss_half.gd (spawn_ennemi) mais n'est plus
# jamais déclenché par ce tirage.
const SCENES_ENNEMIS: Array[PackedScene] = [
	preload("res://scenes/entities/ennemies/enemy_flying.tscn"),
	preload("res://scenes/entities/ennemies/enemy_2lifes.tscn"),
]


func _ready() -> void:
	level_start_time = Time.get_ticks_msec()
	# Fallback robuste : les exports NodePath ne se sérialisent pas de
	# manière fiable dans ce format de scène — si la valeur arrive vide,
	# on retombe sur les chemins canoniques de la salle de boss.
	var chemin_gauche: NodePath = moitie_gauche if not moitie_gauche.is_empty() else NodePath("../BossTentacles")
	var chemin_droite: NodePath = moitie_droite if not moitie_droite.is_empty() else NodePath("../BossTentacles2")
	var chemin_porte: NodePath = porte_sortie if not porte_sortie.is_empty() else NodePath("../Terrain1PortesSortieOuverture1")
	_moitie_gauche = get_node_or_null(chemin_gauche)
	_moitie_droite = get_node_or_null(chemin_droite)
	_porte = get_node_or_null(chemin_porte)

	# La destruction d'un œil (tir de joueur) peut être celle qui tue le
	# boss : chaque moitié prévient, le cerveau vérifie le total vivant
	for moitie: BossHalf in [_moitie_gauche, _moitie_droite]:
		moitie.oeil_detruit.connect(_on_oeil_detruit)

	# Timer du cycle des yeux : fréquence FIXE (5 s)
	_timer_oeil = Timer.new()
	_timer_oeil.wait_time = cycle_oeil_secondes
	_timer_oeil.timeout.connect(_cycle_oeil)
	add_child(_timer_oeil)

	# Timer des spawns : fréquence VARIABLE (5 s → 3 s selon les yeux vivants)
	_timer_spawn = Timer.new()
	_timer_spawn.wait_time = spawn_interval_max
	_timer_spawn.timeout.connect(_cycle_spawn)
	add_child(_timer_spawn)

	# Arrivée des joueurs : spawn, HUD, cinématique d'entrée. Le combat
	# (cycles des yeux et des spawns) ne démarre qu'une fois la porte
	# d'entrée refermée — cf. _on_cinematique_terminee()
	# DIFFÉRÉ : pendant un changement de scène, add_child() pendant le
	# _ready() échoue (l'arbre est occupé) — on attend la frame suivante
	_arrivee_des_joueurs.call_deferred()

	# La sortie de salle (porte de sortie) mène à la boutique, comme le
	# niveau : les données des joueurs sont sauvegardées avant la transition
	if _porte != null:
		_porte.shop_entered.connect(go_to_shop)


## ── Arrivée des joueurs (répliqué du niveau : cf. level.gd) ─────────────
## Spawn des sorciers, HUD par joueur, puis cinématique d'entrée : les
## spawners de munitions sont gelés pendant l'ouverture de la porte et le
## boss n'attaque qu'une fois la porte refermée.
func _arrivee_des_joueurs() -> void:
	PlayerManager.spawn_all_players(get_parent(), {"lives": 3})
	for controller_id in PlayerManager.active_player_ids():
		_ajouter_hud_joueur(controller_id)
	# MODE TEST (WIZARDE_TEST_BOSS=1) : chaque sorcier arrive avec 1
	# attaque ALÉATOIRE dans chacun de ses 3 tubes (pour affronter le boss
	# sans passer par la boutique). Tier II partout pour des attaques déjà
	# montées. Inactif par défaut : on arrive avec son équipement réel.
	if OS.get_environment("WIZARDE_TEST_BOSS") != "":
		for controller_id in PlayerManager.active_player_ids():
			var sorcier: Sorcerer = PlayerManager.players.get(controller_id)
			if sorcier == null:
				continue
			for tube in 3:
				sorcier.set_attack(tube, _attaque_aleatoire(), _tier_aleatoire())
	_geler_spawners_munitions(true)
	var porte := get_parent().get_node_or_null("Terrain1PortesEntree") as EntryDoorCinematic
	if porte != null:
		# SÉQUENCE D'INTRO : les 6 yeux s'ouvrent et fixent la porte
		# d'entrée pendant toute la cinématique d'arrivée
		_moitie_gauche.lancer_intro(porte)
		_moitie_droite.lancer_intro(porte)
		porte.cinematique_terminee.connect(_on_cinematique_terminee)
		porte.lancer_cinematique()
	else:
		_on_cinematique_terminee()


## HUD d'un joueur (répliqué de level.gd add_player_hud)
func _ajouter_hud_joueur(controller_id: int) -> void:
	var player_info: PlayerInfo = SCENE_HUD_JOUEUR.instantiate()
	player_info.controller_id = controller_id
	@warning_ignore("integer_division")
	var slot: int = PlayerManager.get_player_slot(controller_id)
	@warning_ignore("integer_division")
	var hud_offset: int = HUD_PANEL_SPACING * (slot + slot / 2)
	player_info.position = Vector2(8, START_Y_POSITION) + Vector2(hud_offset, 0)
	player_info.set_bg_color(slot)
	player_info.load_data(Run.player_snapshot(controller_id))
	var player = PlayerManager.players[controller_id]
	save_data.connect(player._on_save_data)
	player.ammo_changed.connect(player_info._on_ammo_changed)
	# OUBLI DE RÉPLICATION (corrigé) : level.gd et homepage.gd branchent
	# aussi life_changed — sans lui, l'affichage des vies ne bouge JAMAIS
	# dans la salle du boss. Et au moment du branchement, on resynchronise
	# le HUD sur les vies RÉELLES du sorcier : spawn_all_players force
	# lives = 3 ici, alors que le HUD s'était rempli avec les données
	# sauvegardées à la transition précédente (potentiellement différentes).
	player.life_changed.connect(player_info._on_life_changed)
	player_info._on_life_changed(player.lives)
	add_child(player_info)


## Fin de la cinématique d'entrée : les 6 yeux se ferment tous, le regard
## d'intro est relâché, puis le combat démarre — le premier cycle ouvre
## immédiatement 1 ou 2 yeux (pas d'attente de 5 s au tout début).
func _on_cinematique_terminee() -> void:
	_moitie_gauche.fin_intro()
	_moitie_droite.fin_intro()
	_geler_spawners_munitions(false)
	_timer_oeil.start()
	_timer_spawn.start()
	_cycle_oeil()


## Gèle (ou libère) les spawners de munitions de la salle (répliqué de
## level.gd _set_spawners_frozen, partie munitions)
func _geler_spawners_munitions(frozen: bool) -> void:
	for spawner in get_tree().get_nodes_in_group("ammo_spawner_group"):
		spawner.set_physics_process(not frozen)
		spawner.set_process(not frozen)
	for director in get_tree().get_nodes_in_group("ammo_spawn_director_group"):
		director.set_physics_process(not frozen)
		director.set_process(not frozen)
		var timer: Timer = director.get_node_or_null("Cycle")
		if timer != null:
			if frozen:
				timer.stop()
			else:
				timer.start()


## Sortie de la salle du boss : vers la boutique (répliqué de level.gd
## go_to_shop — les données des joueurs sont sauvegardées avant la
## transition ; level_number est déjà incrémenté par la redirection
## boutique→boss, on ne le refait pas ici pour éviter le décalage des vagues)
func go_to_shop() -> void:
	save_data.emit()
	Run.set_run_duration(Time.get_ticks_msec() - level_start_time)
	Global.goto_scene(GlobalEnum.Location.SHOP)


## ── Mode test : attaques aléatoires dans les tubes ─────────────────────
const ATTAQUES_DISPONIBLES: Array[GlobalEnum.AttackType] = [
	GlobalEnum.AttackType.F0, GlobalEnum.AttackType.F1, GlobalEnum.AttackType.F2,
	GlobalEnum.AttackType.G1, GlobalEnum.AttackType.G2, GlobalEnum.AttackType.G3,
	GlobalEnum.AttackType.L1, GlobalEnum.AttackType.L2, GlobalEnum.AttackType.L3,
	GlobalEnum.AttackType.P1, GlobalEnum.AttackType.P2, GlobalEnum.AttackType.P3,
]

func _attaque_aleatoire() -> GlobalEnum.AttackType:
	return ATTAQUES_DISPONIBLES.pick_random()

func _tier_aleatoire() -> GlobalEnum.AttackTier:
	return GlobalEnum.AttackTier.values().pick_random()


## ── Cycle des yeux ──────────────────────────────────────────────────────
## Choix des yeux ouverts pour les 5 prochaines secondes. Les 2 moitiés
## se coordonnent ici : un œil principal (le plus loin) + éventuellement
## un 2ᵉ de l'autre moitié.
func _cycle_oeil() -> void:
	if _mort_en_cours:
		return
	var vivants := _yeux_vivants()
	# Plus aucun œil : le boss est mort (normalement déjà géré par la
	# destruction du dernier œil, sécurité supplémentaire)
	if vivants.is_empty():
		_declencher_mort()
		return

	# Dernier œil vivant : clignote — il se referme et se rouvre de suite
	# (quelques frames d'invincibilité), jamais fermé longtemps
	if vivants.size() == 1:
		var oe := vivants[0]
		if oe.half.est_ouvert(oe.index):
			oe.half.clignoter_oeil(oe.index)
		else:
			oe.half.ouvrir_oeil(oe.index)
		return

	# 1. On referme tous les yeux vivants actuellement ouverts
	for oe: BossHalf.OeilRef in vivants:
		if oe.half.est_ouvert(oe.index):
			oe.half.fermer_oeil(oe.index)

	# 2. Œil principal : le vivant le plus LOIN du sorcier le plus proche
	var principal := _oeil_le_plus_loin(vivants)
	principal.half.ouvrir_oeil(principal.index)

	# 3. 2ᵉ œil : de l'autre moitié si possible, sinon le suivant
	if randf() < chance_second_oeil and vivants.size() >= 2:
		var autres := vivants.filter(
			func(oe: BossHalf.OeilRef) -> bool: return oe.half != principal.half
		)
		# L'autre moitié n'a plus d'œil vivant : on retire l'œil principal
		# du pool et on pioche parmi les vivants restants
		if autres.is_empty():
			autres = vivants.filter(
				func(oe: BossHalf.OeilRef) -> bool: return oe != principal
			)
		if not autres.is_empty():
			var second := _oeil_le_plus_loin(autres)
			second.half.ouvrir_oeil(second.index)


## L'œil vivant dont le sorcier le plus proche est le plus ÉLOIGNÉ de lui.
## (Le boss ouvre l'œil que personne n'est bien placé pour toucher.)
func _oeil_le_plus_loin(vivants: Array) -> BossHalf.OeilRef:
	var meilleur: BossHalf.OeilRef = vivants[0]
	var meilleure_distance: float = -1.0
	for oe: BossHalf.OeilRef in vivants:
		# NB : Node2D (pas Sorcerer) — une assignation typée trop stricte
		# plante silencieusement et casse tout le cycle des yeux.
		var sorcier: Node2D = EntityFinder.plus_proche(oe.half, oe.half.position_oeil(oe.index), ["player_group"])
		var distance: float = INF if sorcier == null else sorcier.global_position.distance_to(oe.half.position_oeil(oe.index))
		if distance > meilleure_distance:
			meilleure_distance = distance
			meilleur = oe
	return meilleur


## Liste des yeux vivants des 2 moitiés : [{half, index}, ...]
func _yeux_vivants() -> Array[BossHalf.OeilRef]:
	var vivants: Array[BossHalf.OeilRef] = []
	for moitie: BossHalf in [_moitie_gauche, _moitie_droite]:
		for index in moitie.yeux_vivants():
			vivants.append(BossHalf.OeilRef.new(moitie, index))
	return vivants


## ── Cycle des spawns ────────────────────────────────────────────────────
## Un point au hasard PAR MOITIÉ. Rythme variable : de 5 s (6 yeux vivants)
## à 3 s (1 œil vivant), interpolation linéaire sur le nombre d'yeux.
func _cycle_spawn() -> void:
	if _mort_en_cours:
		return
	_maj_interval_spawn()
	for moitie: BossHalf in [_moitie_gauche, _moitie_droite]:
		var marker := moitie.marker_aleatoire()
		if randf() < chance_tentacule or _ennemis_vivants() >= limite_ennemis_vivants:
			moitie.spawn_tentacule(marker)
		else:
			moitie.spawn_ennemi(SCENES_ENNEMIS.pick_random(), marker)


## Intervalle des spawns = interpolation linéaire entre spawn_interval_max
## (6 yeux vivants) et spawn_interval_min (1 œil vivant)
func _maj_interval_spawn() -> void:
	var vivants: int = _moitie_gauche.nb_oeils_vivants() + _moitie_droite.nb_oeils_vivants()
	var total: int = _moitie_gauche.nb_oeils_total() + _moitie_droite.nb_oeils_total()
	var t := clampf(float(total - vivants) / float(total - 1), 0.0, 1.0)
	_timer_spawn.wait_time = lerpf(spawn_interval_max, spawn_interval_min, t)


## Ennemis vivants dans la salle (chaque mouche compte pour une entité)
func _ennemis_vivants() -> int:
	return get_tree().get_nodes_in_group("enemy_group").size()


## Un œil vient d'être détruit par un tir de joueur : s'il n'en reste plus
## aucun vivant des DEUX moitiés, le boss meurt (les moitiés meurent
## ENSEMBLE — même si l'une avait encore des yeux vivants il y a un instant)
func _on_oeil_detruit(_index: int) -> void:
	if _yeux_vivants().is_empty():
		# call_deferred OBLIGATOIRE : le signal oeil_detruit est émis depuis
		# une callback physique (area_entered du projectile) — la séquence de
		# mort crée des tentacules (Area2D), ce qui est interdit pendant le
		# flush des requêtes physiques. Le garde-fou _mort_en_cours absorbe
		# les appels en double (plusieurs yeux détruits dans la même frame).
		_declencher_mort.call_deferred()


## ── Mort du boss ────────────────────────────────────────────────────────
## Déclenchée quand un œil est détruit alors qu'il était le dernier vivant.
func _declencher_mort() -> void:
	if _mort_en_cours:
		return
	_mort_en_cours = true

	# 1. Fin immédiate des attaques : timers stoppés, plus aucun spawn ni
	#    changement d'œil. Les tentacules déjà déployées finissent leur
	#    cycle naturellement (le cerveau ne les contrôle plus).
	_timer_oeil.stop()
	_timer_spawn.stop()

	# 2. Tous les yeux se ferment (les détruits le sont déjà)
	for moitie: BossHalf in [_moitie_gauche, _moitie_droite]:
		moitie.fermer_tous_les_oeils()

	# 3. Léger screenshake : la mort du boss secoue l'écran (amorti rapide)
	_screenshake_mort()

	# 4. Tentacules : sur chaque marker, soit une tentacule de combat est
	#    déjà sortie — c'est ELLE qui retombe (elle garde sa forme) — soit
	#    une courte tentacule-câble sort du trou (cf. BossHalf)
	for moitie: BossHalf in [_moitie_gauche, _moitie_droite]:
		moitie.tentacules_de_mort(articulations_mort)

	# 5. À la fin de la chute : ennemis restants disparaissent (burst),
	#    puis la porte de sortie s'ouvre
	get_tree().create_timer(duree_chute_mort).timeout.connect(_fin_de_la_mort)


## Léger screenshake à la mort du boss : secousse amortie du canvas du
## viewport (la salle n'a pas de Camera2D — on décale la transformation du
## canvas, puis on la remet EXACTEMENT en place à la fin).
func _screenshake_mort() -> void:
	var viewport := get_viewport()
	var origine := viewport.canvas_transform
	var tween := create_tween()
	for i in 6:
		var angle := randf() * TAU
		var amplitude := 14.0 * pow(0.6, i)
		tween.tween_property(viewport, "canvas_transform",
				origine.translated(Vector2.from_angle(angle) * amplitude), 0.05)
	tween.tween_property(viewport, "canvas_transform", origine, 0.05)


func _fin_de_la_mort() -> void:
	# Ennemis restants : éclatement (burst) sans mort « comptée » pour la
	# salle — le boss est vaincu, pas les mouches
	for ennemi in get_tree().get_nodes_in_group("enemy_group"):
		ennemi.queue_free()
		# Le burst visuel d'un ennemi, spawné à sa position dans la salle
		var burst := preload("res://scenes/objets/enemy_death_burst.tscn").instantiate()
		burst.global_position = ennemi.global_position
		get_tree().current_scene.add_child(burst)

	# Porte de sortie : on lance l'animation d'ouverture. Sa hitbox
	# (désactivée au ready) s'activera à la fin de l'animation — c'est le
	# comportement existant du niveau (cf. level.gd / exit_doors.gd).
	if _porte != null:
		_porte.play()
