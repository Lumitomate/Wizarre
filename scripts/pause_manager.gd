extends CanvasLayer

# Système de pause manette, par-dessus le jeu :
# - Start (n'importe quelle manette de joueur connectée) -> pause
# - Déconnexion de la manette d'un joueur -> pause immédiate
# - Reprendre : maintenir le bouton de saut (A). La jauge se remplit en
#   maintien continu et se vide progressivement au relâchement.
# - En bas de l'écran : les sorciers des joueurs connectés (instances de
#   la vraie scène, figés : idle + soulèvement des tuyaux uniquement)
#
# Le gameplay derrière est réellement en pause (get_tree().paused) ; ce
# CanvasLayer et les sorciers d'affichage tournent en PROCESS_MODE_ALWAYS.
# Ne fonctionne que pendant une partie (game_active) : jamais sur Home.

const FILL_TIME := 1.0      # secondes de maintien pour remplir la jauge
const DRAIN_TIME := 0.5     # secondes pour que la jauge redescende à zéro
const DUMMY_SPACING := 150.0

var paused := false
var gauge := 0.0

var overlay: ColorRect
var resume_bar: ProgressBar
var dummies: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	visible = false
	_build_ui()
	PlayerManager.player_disconnected.connect(_on_player_disconnected)
	PlayerManager.player_reconnected.connect(_on_player_reconnected)


func _build_ui() -> void:
	# Filtre gris/translucide par-dessus le jeu (le jeu reste visible)
	overlay = ColorRect.new()
	overlay.color = Color(0.15, 0.15, 0.15, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Titre PAUSE : vers le milieu de l'écran, légèrement au-dessus du centre
	var title := Label.new()
	title.text = "PAUSE"
	title.add_theme_font_size_override("font_size", 72)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-100, -160)
	title.size = Vector2(200, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(title)

	# Bouton Reprendre au centre : jauge de progression + libellé
	resume_bar = ProgressBar.new()
	resume_bar.min_value = 0
	resume_bar.max_value = 100
	resume_bar.value = 0
	resume_bar.show_percentage = false
	resume_bar.set_anchors_preset(Control.PRESET_CENTER)
	resume_bar.position = Vector2(-110, -20)
	resume_bar.size = Vector2(220, 36)
	overlay.add_child(resume_bar)

	var resume_label := Label.new()
	resume_label.text = "REPRENDRE"
	resume_label.add_theme_font_size_override("font_size", 20)
	resume_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	resume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resume_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resume_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resume_bar.add_child(resume_label)


func _process(delta: float) -> void:
	if not PlayerManager.game_active:
		return

	if not paused:
		# Start d'une manette de joueur connectée -> pause
		for device in PlayerManager.connected_game_devices():
			if PlayerInput.button_pressed(device, PlayerInput.Action.PAUSE):
				pause_game()
				break
		# Clavier (partagé par les joueurs clavier) : Échap -> pause
		if Input.is_physical_key_pressed(KEY_ESCAPE):
			pause_game()
		return

	# Jauge Reprendre : n'importe quel joueur connecté peut maintenir son
	# bouton de saut (manette A, Espace clavier 1, pavé 0/Entrée clavier 2).
	# Plusieurs joueurs simultanés = même comportement (une seule jauge).
	var holding := false
	for device in PlayerManager.connected_game_devices():
		if PlayerInput.button_pressed(device, PlayerInput.Action.JUMP):
			holding = true
			break

	if holding:
		gauge += delta / FILL_TIME
	else:
		# Relâchement (ou déconnexion du joueur qui maintenait) : la jauge
		# redescend progressivement, elle ne saute pas à zéro
		gauge -= delta / DRAIN_TIME
	gauge = clampf(gauge, 0.0, 1.0)
	resume_bar.value = gauge * 100.0

	if gauge >= 1.0:
		resume_game()


func pause_game() -> void:
	if paused:
		return
	paused = true
	gauge = 0.0
	resume_bar.value = 0.0
	get_tree().paused = true
	visible = true
	_spawn_dummies()


func resume_game() -> void:
	if not paused:
		return
	paused = false
	get_tree().paused = false
	visible = false
	_clear_dummies()


# Forcée (ex. retour sur Home) : ne rien laisser derrière soi
func force_resume() -> void:
	resume_game()


func _on_player_disconnected(_controller_id: int) -> void:
	# Déconnexion d'une manette de joueur : pause immédiate. Si la pause
	# était déjà active, on actualise juste les sorciers affichés. Si un
	# autre joueur remplissait la jauge, il continue normalement : seul le
	# device déconnecté cesse de contribuer.
	if paused:
		_refresh_dummies()
	else:
		pause_game()


func _on_player_reconnected(_controller_id: int) -> void:
	# Le sorcier du joueur repris réapparaît en bas de l'écran
	_refresh_dummies()


# Sorciers d'affichage : vraie scène du sorcier (apparence, couleur,
# données actuelles via load_data), figés (idle + tuyaux uniquement)
func _spawn_dummies() -> void:
	_clear_dummies()
	var screen := get_viewport().get_visible_rect().size
	var connected_ids: Array[int] = []
	for id in PlayerManager.game_players:
		if not id in PlayerManager.disconnected_players:
			connected_ids.append(id)

	var count := connected_ids.size()
	for i in range(count):
		var id: int = connected_ids[i]
		var dummy: Sorcerer = PlayerManager.sorcerer_scene.instantiate()
		dummy.controller_id = id
		dummy.sorcerer_color = PlayerManager.get_player_slot(id) as GlobalEnum.SorcererColor
		dummy.input_device = PlayerManager.get_input_device(id)
		dummy.frozen = true
		dummy.can_fire = false
		dummy.tubes_selectable = true
		# Comme spawn_player : charge les données AVANT add_child, sinon le
		# sac (enfant, _ready avant le parent) lirait des sorts vides
		dummy.load_data()
		dummy.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(dummy)
		# Animation idle (le _physics_process gelé ne changerait pas l'état)
		dummy.set_state(GlobalEnum.State.IDLE)
		var x := screen.x * 0.5 + (i - (count - 1) * 0.5) * DUMMY_SPACING
		dummy.position = Vector2(x, screen.y - 120.0)
		dummies.append(dummy)


func _refresh_dummies() -> void:
	if paused:
		_spawn_dummies()


func _clear_dummies() -> void:
	for dummy in dummies:
		if is_instance_valid(dummy):
			dummy.queue_free()
	dummies.clear()
