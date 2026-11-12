extends Node

## Test headless (lancer : godot --headless res://tests/test_noeuds_references.tscn)
## Vérifie mécaniquement que chaque référence de nœud racine `$Nom` des scripts
## de shop (`res://scripts/shop_*.gd`) existe bien comme nœud dans la scène
## `scenes/niveaux/magasin/**` dont le script est le script racine.
##
## Périmètre volontairement statique et sans faux positif :
## - seule la forme `$Nom` (un seul niveau) est vérifiée ;
## - les chemins imbriqués `$A/B`, les `get_node` dynamiques et les références
##   d'autoload sont ignorés (invérifiables statiquement) ;
## - le script est nettoyé des chaînes et des commentaires avant l'extraction,
##   pour ne pas confondre une mention dans un commentaire avec une référence.
##
## Le test inclut une « vérification du vérificateur » : un mini-fixture
## texte de scène/script volontairement faux ($NoeudAbsent) doit être signalé.

const AUTOLOADS := ["Global", "GlobalInfo", "PlayerManager", "ShopRouter", "PauseManager"]
const DOSSIER_SCENES := "res://scenes/niveaux/magasin"
const MOTIF_SCRIPT := "shop_*.gd"

var _regex_ref := RegEx.new()
var _regex_script_racine := RegEx.new()
var _regex_nom_noeud := RegEx.new()
var _regex_chemin_ext := RegEx.new()

var _failures: Array[String] = []


func _init() -> void:
	_regex_ref.compile("\\$([A-Za-z_][A-Za-z0-9_]*)")
	_regex_script_racine.compile('^script = ExtResource\\("([^"]+)"\\)')
	_regex_nom_noeud.compile('^\\[node name="([^"]+)"')
	_regex_chemin_ext.compile('path="([^"]+)"')


func _ready() -> void:
	_verifier_le_verificateur()

	var couples := _lister_couples()
	if couples.is_empty():
		_failures.append(
			"aucun couple scène/script trouvé : scenes/niveaux/magasin/** avec script racine res://scripts/%s"
			% MOTIF_SCRIPT)
	for couple in couples:
		var erreurs := _detecter_erreurs(_lire_fichier(couple[1]), _lire_fichier(couple[0]))
		if erreurs.is_empty():
			print("OK: %s <-> %s" % [couple[0], couple[1]])
		else:
			_failures.append_array(erreurs)
	print("couples scène/script shop vérifiés : %d" % couples.size())

	if _failures.is_empty():
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL (%d)" % _failures.size())
		for echec in _failures:
			print("  - ", echec)
		get_tree().quit(1)


## Vérification du vérificateur : le mini-fixture faux ($NoeudAbsent) doit
## produire exactement une erreur, et lui seul ($NoeudPresent passe,
## $NoeudAbsent/Enfant est ignoré comme chemin imbriqué).
func _verifier_le_verificateur() -> void:
	var scene_factice := """[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/factice.gd" id="1_x"]

[node name="ShopFactice" type="Node2D"]
script = ExtResource("1_x")

[node name="NoeudPresent" type="Node2D" parent="."]
"""
	var script_factice := """extends Node2D

func _ready() -> void:
	$NoeudPresent.jouer()
	$NoeudAbsent.jouer()
	$NoeudAbsent/Enfant.jouer()
"""
	var refs := _references_racine(script_factice)
	if not refs.has("NoeudPresent") or not refs.has("NoeudAbsent"):
		_failures.append("vérification du vérificateur : références extraites = %s (attendu NoeudPresent + NoeudAbsent)" % [refs])
	if refs.has("Enfant"):
		_failures.append("vérification du vérificateur : le chemin imbriqué $NoeudAbsent/Enfant n'aurait pas dû être extrait")
	var erreurs := _detecter_erreurs(script_factice, scene_factice)
	if erreurs.size() != 1 or not erreurs[0].contains("NoeudAbsent"):
		_failures.append(
			"vérification du vérificateur : attendu exactement 1 erreur sur NoeudAbsent, obtenu : %s" % [erreurs])


## Construit la liste des couples [chemin_scène, chemin_script] dont le script
## racine de la scène est un script de shop res://scripts/shop_*.gd.
func _lister_couples() -> Array:
	var couples: Array = []
	for chemin in _lister_tscn_recursif(DOSSIER_SCENES):
		var script := _script_racine(_lire_fichier(chemin))
		if script == "":
			continue
		if not script.begins_with("res://scripts/"):
			continue
		if not script.get_file().match(MOTIF_SCRIPT):
			continue
		couples.append([chemin, script])
	return couples


## Compare les références `$Nom` du script aux noms de nœuds de la scène.
## Renvoie une liste de messages d'erreur (vide = tout va bien).
func _detecter_erreurs(src_script: String, texte_scene: String) -> Array[String]:
	var erreurs: Array[String] = []
	var noms := _noms_noeuds(texte_scene)
	for nom in _references_racine(src_script):
		if not noms.has(nom):
			erreurs.append("référence $%s absente des nœuds de la scène" % nom)
	return erreurs


## Extrait les noms référencés par `$Nom` (un seul niveau) dans le script,
## hors chaînes, hors commentaires, hors chemins imbriqués `$A/B`,
## hors références d'autoload. Dédupliqué, ordre d'apparition.
func _references_racine(src: String) -> PackedStringArray:
	var trouvees: PackedStringArray = []
	for ligne in src.split("\n"):
		var propre := _sans_chaines_ni_commentaires(ligne)
		var offset := 0
		while true:
			var m := _regex_ref.search(propre, offset)
			if m == null:
				break
			var nom := m.get_string(1)
			var fin := m.get_end()
			if fin < propre.length() and propre[fin] == "/":
				offset = fin  # chemin imbriqué $A/B : invérifiable statiquement
			elif nom in AUTOLOADS:
				offset = fin  # référence d'autoload : ignorée
			else:
				if not trouvees.has(nom):
					trouvees.append(nom)
				offset = fin
	return trouvees


## Retire le contenu des chaînes et tout ce qui suit un `#` hors chaîne,
## ligne par ligne, pour ne scanner que du vrai code.
func _sans_chaines_ni_commentaires(ligne: String) -> String:
	var sortie := ""
	var dans_chaine := false
	var i := 0
	while i < ligne.length():
		var c := ligne[i]
		if dans_chaine:
			if c == "\\":
				i += 2
				continue
			if c == "\"":
				dans_chaine = false
		else:
			if c == "\"":
				dans_chaine = true
			elif c == "#":
				break
			else:
				sortie += c
		i += 1
	return sortie


## Renvoie le chemin du script du nœud racine du .tscn (texte), ou "".
func _script_racine(texte_scene: String) -> String:
	var lignes := texte_scene.split("\n")
	var racine := -1
	for i in lignes.size():
		if lignes[i].begins_with("[node "):
			racine = i
			break
	if racine == -1:
		return ""
	for j in range(racine + 1, lignes.size()):
		var ligne := lignes[j]
		if ligne.begins_with("["):
			break  # fin du bloc du nœud racine
		var m := _regex_script_racine.search(ligne)
		if m == null:
			continue
		var id_ressource := m.get_string(1)
		for k in racine:  # les ext_resource précèdent le premier [node]
			var ligne_ext := lignes[k]
			if not ligne_ext.contains('id="%s"' % id_ressource):
				continue
			var chemin := _regex_chemin_ext.search(ligne_ext)
			if chemin != null:
				return chemin.get_string(1)
	return ""


## Renvoie l'ensemble des noms de nœuds déclarés dans le .tscn (texte).
func _noms_noeuds(texte_scene: String) -> Dictionary:
	var noms := {}
	for ligne in texte_scene.split("\n"):
		if ligne.begins_with("[node "):
			var m := _regex_nom_noeud.search(ligne)
			if m != null:
				noms[m.get_string(1)] = true
	return noms


func _lister_tscn_recursif(dossier: String) -> PackedStringArray:
	var resultats: PackedStringArray = []
	var dir := DirAccess.open(dossier)
	if dir == null:
		_failures.append("impossible d'ouvrir le dossier %s" % dossier)
		return resultats
	dir.list_dir_begin()
	var nom := dir.get_next()
	while nom != "":
		var chemin := dossier.path_join(nom)
		if dir.current_is_dir():
			resultats.append_array(_lister_tscn_recursif(chemin))
		elif nom.ends_with(".tscn"):
			resultats.append(chemin)
		nom = dir.get_next()
	return resultats


func _lire_fichier(chemin: String) -> String:
	var fichier := FileAccess.open(chemin, FileAccess.READ)
	if fichier == null:
		_failures.append("impossible de lire %s" % chemin)
		return ""
	return fichier.get_as_text()
