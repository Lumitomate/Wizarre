extends Area2D

@export var destination : GlobalEnum.Location

func _on_body_entered(body):
	if body.is_in_group("player_group"):
		Global.goto_scene(destination_finale())


## Destination réellement prise, après routage de la première salle :
## l'ascenseur de la homepage mène au magasin intro à 1 ou 2 joueurs
## (tubes vides, premier objet), et au magasin intro à 3-4 joueurs à
## partir de 3. Le nombre de joueurs est lu AVANT start_game : sur la
## homepage, active_player_ids() retourne les joueurs présents à l'écran
## (game_active est encore faux). Factorisée pour être testable.
func destination_finale() -> GlobalEnum.Location:
	if destination != GlobalEnum.Location.LEVEL:
		return destination
	GlobalInfo.run_info["from_homepage"] = true
	if PlayerManager.active_player_ids().size() <= 2:
		return GlobalEnum.Location.SHOP_2PLAYERS_INTRO
	return GlobalEnum.Location.SHOP_4PLAYERS_INTRO
