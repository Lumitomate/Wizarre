extends Node
## Run — l'état d'une partie : la vague atteinte, la durée, les joueurs.
## Source de vérité unique de l'état de la partie ; le Dictionary brut est
## un détail d'implémentation : les consommateurs passent par l'interface.
## (L'autoload s'appelle « Run » ; l'ancien « GlobalInfo » ne subsiste plus.)

# EnergyType is defined in GlobalEnum
# Maps directly to tube index: Fossil=0 (tube 1), Pure=1 (tube 2), Tainted=2 (tube 3)

# Numéro de vague interne : commence à 0, l'écran affiche ce numéro + 1
# en chiffres romains (vague I = 0). La redirection vers le boss
# (global.gd) consomme le créneau de la vague affichée V.
var level_number: int = 0

var run_duration: int = 0 # en millisecondes

# Les joueurs arrivent depuis la homepage : leur run doit être rechargée
# par le niveau (lecture à usage unique : consume_from_homepage()).
var from_homepage: bool = false

var players_info: Dictionary = {
	"default" : {
		"lives": 3,
		"energy_counts": [3, 3, 3],  # Fossil, Pure, Tainted
		"spells": {
			# Each tube contains one spell; the tube determines the energy type needed
			0: {  # Tube 1 → Fossil : G1 = IceBall tier I
				"attack_type" : GlobalEnum.AttackType.F1,
				"attack_tier" : 0
			},
			1: {  # Tube 2 → Pure : G3 = IceBlade tier III
				"attack_type" : GlobalEnum.AttackType.G1,
				"attack_tier" : 2
			},
			2: {  # Tube 3 → Tainted : L1 = LightRay tier I
				"attack_type" : GlobalEnum.AttackType.L1,
				"attack_tier" : 0
			},
		}
	}
}


# ── Vague ────────────────────────────────────────────────────────────────────

## La vague interne (0 pour la vague affichée I).
func wave_number() -> int:
	return level_number


## La vague avance (fin de niveau : level.gd, boss_controller).
func advance_wave() -> void:
	level_number += 1


## Réglage direct du compteur de vague — uniquement pour le routage
## (_redirection_boss) et les tests.
func set_wave_number(n: int) -> void:
	level_number = n


## La redirection vers le boss consomme le créneau de la vague affichée V
## (voir global.gd _redirection_boss) : le +1 supplémentaire empêche de
## retomber sur le boss au magasin suivant.
func consume_boss_slot() -> void:
	level_number += 1


# ── Durée ────────────────────────────────────────────────────────────────────

## La durée de la run est arrêtée (fin de niveau : level.gd, boss_controller).
func set_run_duration(ms: int) -> void:
	run_duration = ms


# ── Homepage ─────────────────────────────────────────────────────────────────

## Les joueurs arrivent depuis la homepage : le niveau doit recharger leur
## run (vies et énergies).
func mark_from_homepage() -> void:
	from_homepage = true


## Lecture à usage unique : le niveau consomme le drapeau et recharge
## vies/énergies si besoin.
func consume_from_homepage() -> bool:
	var was := from_homepage
	from_homepage = false
	return was


# ── Joueurs ──────────────────────────────────────────────────────────────────

## Un joueur quitte la run (cadavre oublié au respawn : sorcerer_corpse).
func forget_player(controller_id: int) -> void:
	players_info.erase(controller_id)


## Snapshot des données d'un joueur pour un HUD : ses données si présentes,
## sinon la configuration de départ (joueur pas encore entré dans la run).
## Snapshot copié : le HUD ne doit pas écrire dans la run (il ne fait que
## suivre ses valeurs via les signaux).
func player_snapshot(controller_id: int) -> Dictionary:
	if controller_id in players_info:
		return players_info[controller_id].duplicate(true)
	return players_info["default"].duplicate(true)


## Y a-t-il au moins un joueur en vie ? ("default" n'est pas un joueur —
## seuls les controller_id int comptent ; un int == String plante en GDScript.)
func any_player_dead() -> bool:
	for controller_id in players_info:
		if controller_id is int and players_info[controller_id]["lives"] == 0:
			return true
	return false


## Tous les joueurs ont-ils leurs vies pleines ? (porte NO_DAMAGE du magasin)
func all_players_full_lives() -> bool:
	for controller_id in players_info:
		if controller_id is int and players_info[controller_id]["lives"] != 3:
			return false
	return true


## Le sorcier sauvegarde son état dans la run (référence partagée : le
## dictionnaire de sorts du sorcier EST celui de la run pendant le jeu).
func save_sorcerer(sorcier) -> void:
	players_info[sorcier.controller_id] = {
		"lives": sorcier.lives,
		"energy_counts": sorcier.energy_counts,
		"spells": sorcier.spells
	}


## Le sorcier charge son état depuis la run : ses données si présentes,
## sinon la configuration de départ (dupliquée pour ne pas écraser "default").
## Les dictionnaires de la run ne sont PAS dupliqués : le dictionnaire de
## sorts du sorcier EST celui de la run pendant le jeu (load_data retombe
## dessus à chaque respawn, et le reset du niveau écrit dedans).
func load_sorcerer(sorcier) -> void:
	var data_to_load: Dictionary = _default_data().duplicate(true)
	if sorcier.controller_id in players_info:
		data_to_load = players_info[sorcier.controller_id]
	sorcier.lives = data_to_load["lives"]
	sorcier.energy_counts = data_to_load["energy_counts"]
	sorcier.spells = data_to_load["spells"]


## ── Resets ───────────────────────────────────────────────────────────────────

## Arrivée depuis la homepage : vies et énergies rechargées pour chaque
## joueur de la run (le niveau appelle après consume_from_homepage()).
func reset_lives_and_energies() -> void:
	var default_data: Dictionary = _default_data()
	for controller_id in players_info:
		if controller_id is int:
			players_info[controller_id]["energy_counts"] = default_data["energy_counts"].duplicate(true)
			players_info[controller_id]["lives"] = default_data["lives"]


## Game over (retour à l'écran home après mort de tous les joueurs) : les
## sorts de la run perdue ne doivent pas se retrouver sur la run suivante
## (load_data relit players_info à chaque spawn). On remet les sorts de
## chaque joueur sur la configuration de départ ("default").
func reset_players_spells() -> void:
	var default_spells: Dictionary = _default_data()["spells"].duplicate(true)
	for controller_id in players_info.keys():
		# Les joueurs sont indexés par des ints ; "default" est la seule
		# clé String (et un int == String plante en GDScript)
		if not (controller_id is int):
			continue
		players_info[controller_id]["spells"] = default_spells.duplicate(true)


## Reset complet de la run (game over : retour à la homepage) — comme si
## on relançait le jeu depuis le début :
## - niveau de vague atteint remis à 0 (sinon la run suivante repart sur
##   la difficulté de la vague où tout le monde est mort) ;
## - durée de run remise à 0 ;
## - entrées par manette supprimées : vies, énergies et sorts reviennent
##   à "default" au prochain spawn (load_data retombe dessus).
func reset_run() -> void:
	level_number = 0
	run_duration = 0
	from_homepage = false
	for controller_id in players_info.keys():
		if controller_id is int:
			players_info.erase(controller_id)


## La configuration de départ d'un joueur (le "default" du Dictionary).
func _default_data() -> Dictionary:
	return players_info["default"]
