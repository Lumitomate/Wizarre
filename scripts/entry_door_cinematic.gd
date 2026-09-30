extends AnimatedSprite2D
class_name EntryDoorCinematic

## Porte d'entrée animée (level + magasins) : orchestre la cinématique
## d'arrivée des sorciers.
##
## Séquence (coordonnée avec les Sorcerer via start_door_exit()) :
##  1. Chargement de la scène : les sorciers sont déjà spawnés FIGÉS
##     (frozen), posés au centre de la porte, invisibles (arrival_fade 0).
##  2. La porte joue son anim d'ouverture ; à la MOITIÉ des frames, la
##     première sortie démarre.
##  3. Les sorciers sortent un à un, en CHAÎNE : le suivant ne sort que
##     lorsque le précédent a fini sa sortie complète (door_exit_done).
##     Apparition au centre de la porte (pieds sur la ligne de sol), anim
##     walk sur place + fade d'opacité du bas vers le haut, puis décalage
##     latéral (marche) vers sa position finale. Sens alterné : rang 0 →
##     droite, rang 1 → gauche, rang 2 → droite éloignée... sauf porte à
##     UN seul sorcier (il reste au centre, ex. magasin course) et rang 2
##     à 3 joueurs (il s'arrête au milieu).
##  4. Quand le DERNIER sorcier est apparu (fade fini), la porte se referme
##     (anim jouée à l'envers).
##  5. Une fois la porte refermée : signal cinematique_terminee → la scène
##     libère les spawners, les sorciers sont dégelés (contrôles actifs).

signal cinematique_terminee

## Rangs de sortie des sorciers de CETTE porte, dans l'ordre.
## Rempli par la scène avant le lancement de la cinématique.
var _en_attente: Array[Sorcerer] = []   # sorciers de cette porte, ordre de sortie
var _deja_sortis: int = 0               # compteur pour le rythme
var _porte_ouverte := false


func _ready() -> void:
	# L'anim d'ouverture : frames des sprites porteEntreOuverture
	# (la texture d'origine reste le fallback si les frames manquent)
	play("default")


## Enregistre un sorcier comme sortant de cette porte (rang = ordre de sortie
## local à la porte, 0 = premier). Le sorcier doit déjà être spawné, gelé
## et en position d'attente (centre de la porte, invisible).
func inscrire_sorcier(sorcier: Sorcerer, rang: int) -> void:
	while _en_attente.size() <= rang:
		_en_attente.append(null)
	_en_attente[rang] = sorcier


## Vide la file des sorciers inscrits et rompt leurs liens avec la porte.
## Utilisé par le magasin Shophands : tous les sorciers se sont
## auto-inscrits à la porte à leur spawn (comportement par défaut du
## sorcier), mais seul le décideur doit en sortir — les receveurs restent
## dans leurs espaces clos. La scène réinscrit ensuite le décideur seul.
func reinitialiser_inscriptions() -> void:
	for sorcier in _en_attente:
		if sorcier != null and is_instance_valid(sorcier):
			sorcier._door_cine = null
	_en_attente.clear()


## Lance la cinématique : ouverture de la porte, puis sorties décalées.
func lancer_cinematique() -> void:
	# Connexion fin d'anim : mi-anim → première sortie ; fin → porte ouverte
	# (la refermeture est déclenchée par le dernier fade)
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)
	play("default")
	# Réveil des sorciers : chacun écoute son tour via son propre timer
	_appeler_premiere_sortie()


func _appeler_premiere_sortie() -> void:
	# Sortie du 1er sorcier à mi-anim (frame 6 / 12, anim 10 fps ≈ 0,6 s)
	var delai := frame_seconds() * 6.0
	if _en_attente.is_empty() or _en_attente[0] == null:
		# Aucun sorcier à faire sortir : referme la porte en fin d'anim
		# (sinon elle resterait ouverte et la scène gelée pour toujours)
		get_tree().create_timer(delai).timeout.connect(porte_dernier_sorcier_sorti)
		return
	get_tree().create_timer(delai).timeout.connect(_sortie_suivante)


func frame_seconds() -> float:
	var fps := sprite_frames.get_animation_speed("default")
	if fps <= 0.0:
		return 0.1
	return 1.0 / fps


func _sortie_suivante() -> void:
	if _deja_sortis >= _en_attente.size():
		return
	var sorcier: Sorcerer = _en_attente[_deja_sortis]
	_deja_sortis += 1
	if sorcier != null and is_instance_valid(sorcier):
		var dernier: bool = _deja_sortis >= _en_attente.size()
		sorcier.start_door_exit(_position_finale(sorcier), dernier)
		# Le sorcier suivant ne sort QUE lorsque celui-ci a terminé sa
		# sortie complète (fade + décalage sur le côté) : door_exit_done
		# est émis par le sorcier dans _finish_door_exit
		sorcier.door_exit_done.connect(_sortie_suivante)
		return
	# Sorcier absent/libéré : on enchaîne directement ; si c'était le
	# dernier, referme la porte après un délai de sécurité (il n'y aura
	# aucun signal de fin de sortie)
	if _deja_sortis >= _en_attente.size():
		get_tree().create_timer(3.0).timeout.connect(
			func():
				if not _fermeture_lancee:
					porte_dernier_sorcier_sorti()
		)
	else:
		_sortie_suivante()


## Position finale du sorcier de rang `rang` : répartition alternée autour
## de la porte. Le 1er sort vers la DROITE, le 2e vers la GAUCHE, etc.
## Le CENTRE reste libre pendant les sorties, sauf :
##  - porte à un seul sorcier (shop race : 1 couloir/joueur) → centre ;
##  - 3 joueurs : le 3e (rang 2) s'arrête au milieu.
## Écart de 64 px (coords locales, = 1 largeur de porte / 2).
func _offset_rang(rang: int) -> Vector2:
	if _en_attente.size() <= 1:
		return Vector2.ZERO
	if _en_attente.size() == 3 and rang == 2:
		return Vector2.ZERO
	if rang % 2 == 0:
		return Vector2(float(rang / 2 + 1) * 64.0, 0.0)   # droite
	return Vector2(-float((rang + 1) / 2) * 64.0, 0.0)    # gauche


func _position_finale(sorcier: Sorcerer) -> Vector2:
	var rang: int = _en_attente.find(sorcier)
	# Coordonnées LOCALES au parent (le sorcier est frère de la porte, dans
	# le level/magasin scale 0.7) : ne PAS utiliser global_position (coords
	# monde, écrasées par le scale du parent)
	return position + _offset_rang(rang)


func _on_animation_finished() -> void:
	# Fin de l'anim d'ouverture : la porte reste ouverte (dernière frame)
	# jusqu'à la refermeture déclenchée par le dernier sorcier
	_porte_ouverte = true


## Appelé par le DERNIER sorcier quand son fade d'arrivée est terminé :
## referme la porte (anim à l'envers) puis émet le signal de fin.
var _fermeture_lancee := false

func porte_dernier_sorcier_sorti() -> void:
	if _fermeture_lancee:
		return
	_fermeture_lancee = true
	if not _porte_ouverte:
		# L'anim d'ouverture n'est pas finie : attends-la avant de refermer
		await animation_finished
		_porte_ouverte = true
	_refermer()


func _refermer() -> void:
	# Anim d'ouverture jouée À L'ENVERS : play_backwards depuis la fin
	if not animation_finished.is_connected(_on_fermeture_finie):
		animation_finished.connect(_on_fermeture_finie)
	play_backwards("default")


func _on_fermeture_finie() -> void:
	# La porte est refermée : dégel de tous les sorciers sortis par les
	# portes (contrôles actifs), puis la scène (spawners) est libérée
	animation_finished.disconnect(_on_fermeture_finie)
	for sorcier in _en_attente:
		if sorcier != null and is_instance_valid(sorcier):
			sorcier.frozen = false
	cinematique_terminee.emit()
