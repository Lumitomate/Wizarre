class_name AttackSpawner

## ═══════════════════════════════════════════════════════════════════════
##  FABRIQUE D'ATTAQUES — point d'entrée unique de tout projectile de jeu
## ═══════════════════════════════════════════════════════════════════════
##
##  FLUX D'UN TIR (de bout en bout) :
##    1. le Sorcerer décide de tirer (scripts/sorcerer.gd — tube sélectionné)
##    2. il appelle AttackSpawner.spawn_attack(type, tier, position,
##       direction, screen_size, level_scale, self)
##    3. spawn_attack résout REGISTRE[type] → le script de l'attaque
##    4. le script exécute son contrat statique setup_spawn(...) :
##       instanciation, positionnement, configuration des nœuds
##    5. spawn_attack retourne Array[Node] ; l'appelant les ajoute à l'arbre
##    6. chaque attaque gère sa propre fin de vie (queue_free)
##
##  CONTRAT setup_spawn — exposé par CHAQUE script d'attaque (atk_*.gd) :
##    static func setup_spawn(
##        spawn_tier: int,          # 1-based : I = 1, II = 2, III = 3
##        spawn_position: Vector2,  # position du sorcier (coords locales Level)
##        spawn_direction: Vector2, # direction de visée
##        spawn_screen_size: Vector2,  # taille de l'écran (attaques plein écran)
##        spawn_level_scale: Vector2,  # échelle du niveau (taille des sprites)
##        spawn_caster: Node2D,        # sorcier lanceur (représailles, immunité…)
##    ) -> Array[Node]               # les nœuds à ajouter à l'arbre
##
##  POURQUOI le préfixe spawn_ : ces six paramètres sont des ENTRÉES, et
##  leurs noms naturels (position, direction, caster, attack_tier,
##  level_scale) sont aussi des membres des nœuds créés — position est même
##  une propriété de Node2D. Sans préfixe, GDScript signale un masquage
##  (SHADOWED_VARIABLE_BASE_CLASS) sur chaque attaque, et le lecteur ne
##  sait plus si `caster` désigne l'entrée ou le membre de l'objet. Les
##  paramètres INUTILISÉS gardent le préfixe souligné : _spawn_screen_size.
##
##  CONVENTIONS :
##    • setup_spawn N'AJOUTE JAMAIS les nœuds à l'arbre (c'est à l'appelant)
##    • spawn_position : l'attaque multiplie elle-même par spawn_level_scale
##      si besoin
##    • spawn_direction : normalisée par l'attaque avant usage
##    • tier 1-based (I/II/III) : PAS de conversion dans le spawner — chaque
##      attaque reçoit directement int(AttackTier) + 1
##    • ajouter une attaque = nouveau script avec setup_spawn
##      + entrée dans GlobalEnum.AttackType + une ligne dans REGISTRE
##
##  LES 13 ATTAQUES (GlobalEnum.AttackType), par famille :
##    Feu     : F0 boule de feu · F1 colonne de feu · F2 vague · F3 mine
##    Glace   : G1 boule de glace · G2 anneau de piques · G3 lames orbitantes
##    Lumière : L1 rideau de rayons · L2 cible lumineuse · L3 arc chargé
##    Plante  : P1 graine carnivore · P2 boule de plante · P3 ronce (stick)
static var REGISTRE: Dictionary = {
	GlobalEnum.AttackType.F0: AttackFireBall,        # éventail de boules de feu
	GlobalEnum.AttackType.F1: AttackFireColumn,      # chaîne de colonnes de feu
	GlobalEnum.AttackType.F2: AttackFireWave,        # vague de feu grandissante
	GlobalEnum.AttackType.F3: AttackFireMine,        # mine posable IDLE → FALL → EXPLODE
	GlobalEnum.AttackType.G1: AttackIceBall,         # boule de glace physique (rebonds)
	GlobalEnum.AttackType.G2: AttackIceSpike,        # anneau de piques de glace
	GlobalEnum.AttackType.G3: AttackIceBlade,        # lames orbitantes autour du lanceur
	GlobalEnum.AttackType.L1: AttackLightRay,        # rideau de rayons de lumière
	GlobalEnum.AttackType.L2: AttackLightTarget,     # cible lumineuse posée (TARGETING → EXPLODING)
	GlobalEnum.AttackType.L3: AttackLightBow,        # arc chargé à distance
	GlobalEnum.AttackType.P1: AttackCarnivorousSeed, # graine → tête carnivore qui mord
	GlobalEnum.AttackType.P2: AttackPlantBall,       # boule de plante roulante qui explose
	GlobalEnum.AttackType.P3: AttackPlantBramble,    # ronce de tiges pilotée au stick
}


## Direction de lancer JAMAIS exactement verticale : si la visée est pile
## au-dessus (ou en dessous), on incline légèrement vers l'avant du sorcier
## (10°). Sinon une graine retombe pile sur la tête de son lanceur et y
## rebondit indéfiniment sans jamais s'écarter.
static func _direction_sans_vertical(direction: Vector2, caster: Node2D) -> Vector2:
	var dir := direction.normalized()
	if absf(dir.x) < 0.08:
		var cote := 1.0
		if caster != null and is_instance_valid(caster) and caster.has_node("AnimatedSprite2D"):
			cote = -1.0 if caster.get_node("AnimatedSprite2D").flip_h else 1.0
		dir = dir.rotated(cote * deg_to_rad(10.0))
	return dir


## Instancie et configure l'attaque de type donné via le registre.
## Retourne les nœuds à ajouter à l'arbre par l'appelant.
static func spawn_attack(attack_type: GlobalEnum.AttackType, attack_tier: GlobalEnum.AttackTier, player_position: Vector2, player_direction: Vector2, screen_size: Vector2, level_scale: Vector2, caster: Node2D) -> Array[Node]:
	# Tier 1-based : 0 → I, 1 → II, 2 → III
	var int_attack_tier: int = int(attack_tier) + 1
	var script: GDScript = REGISTRE.get(attack_type)
	if script == null:
		return []
	return script.setup_spawn(int_attack_tier, player_position, player_direction, screen_size, level_scale, caster)
