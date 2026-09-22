class_name PlayerInput

## Couche d'entrée unifiée du jeu : chaque joueur est identifié par un
## "device" — une manette physique (id 0 et plus, donné par Godot) ou un
## joueur clavier (device virtuel 100/101, voir KEYBOARD_P1/P2).
##
## Tous les scripts lisent les entrées via les fonctions statiques
## button_pressed() et direction() : elles redirigent vers la manette ou
## vers les touches du clavier selon le device.
##
## Le clavier 1 est mappé en POSITIONS PHYSIQUES de touches (ZQSD sur
## AZERTY devient automatiquement WASD sur QWERTY).

enum Action {
	JUMP,   # manette : A
	DASH,   # manette : LB (gâchette avant gauche)
	ATK1,   # manette : X
	ATK2,   # manette : Y
	ATK3,   # manette : B
	PAUSE,  # manette : Start
}

# Devices virtuels des 2 joueurs clavier (un device manette ne dépasse
# jamais quelques dizaines : aucune collision possible)
const KEYBOARD_P1 := 100
const KEYBOARD_P2 := 101

# Positions physiques des touches du clavier 1 :
# direction ZQSD (AZERTY) = positions W/A/S/D, F/T/H attaques, G dash,
# Espace ou Z (physique) = saut. Échap met le jeu en pause.
const KB1_BUTTONS := {
	Action.JUMP: [KEY_SPACE, KEY_W],
	Action.DASH: [KEY_G],
	Action.ATK1: [KEY_F],
	Action.ATK2: [KEY_T],
	Action.ATK3: [KEY_H],
	Action.PAUSE: [KEY_ESCAPE],
}
const KB1_DIRS := {
	Vector2.UP: KEY_W,
	Vector2.DOWN: KEY_S,
	Vector2.LEFT: KEY_A,
	Vector2.RIGHT: KEY_D,
}

# Clavier 2 : flèches pour la direction, pavé numérique 4/8/6 pour les
# attaques, 5 pour le dash, saut sur pavé 0, Entrée ou flèche haut. Échap met le jeu
# en pause (le pavé 0 reste réservé au saut).
const KB2_BUTTONS := {
	Action.JUMP: [KEY_KP_0, KEY_ENTER, KEY_UP],
	Action.DASH: [KEY_KP_5],
	Action.ATK1: [KEY_KP_4],
	Action.ATK2: [KEY_KP_8],
	Action.ATK3: [KEY_KP_6],
	Action.PAUSE: [KEY_ESCAPE],
}
const KB2_DIRS := {
	Vector2.UP: KEY_UP,
	Vector2.DOWN: KEY_DOWN,
	Vector2.LEFT: KEY_LEFT,
	Vector2.RIGHT: KEY_RIGHT,
}


static func is_keyboard(device: int) -> bool:
	return device >= KEYBOARD_P1


## Le bouton logique du device est-il pressé en ce moment ?
static func button_pressed(device: int, button: Action) -> bool:
	if is_keyboard(device):
		var buttons: Dictionary = KB1_BUTTONS if device == KEYBOARD_P1 else KB2_BUTTONS
		for key in buttons[button]:
			if Input.is_physical_key_pressed(key):
				return true
		return false
	match button:
		Action.JUMP:
			return Input.is_joy_button_pressed(device, JOY_BUTTON_A)
		Action.DASH:
			return Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER)
		Action.ATK1:
			return Input.is_joy_button_pressed(device, JOY_BUTTON_X)
		Action.ATK2:
			return Input.is_joy_button_pressed(device, JOY_BUTTON_Y)
		Action.ATK3:
			return Input.is_joy_button_pressed(device, JOY_BUTTON_B)
		Action.PAUSE:
			return Input.is_joy_button_pressed(device, JOY_BUTTON_START)
	return false


## Direction (aim + déplacement) du device, comme un stick analogique :
## les diagonales clavier sont normalisées à longueur 1.
static func direction(device: int) -> Vector2:
	if is_keyboard(device):
		var dirs: Dictionary = KB1_DIRS if device == KEYBOARD_P1 else KB2_DIRS
		var v := Vector2.ZERO
		if Input.is_physical_key_pressed(dirs[Vector2.RIGHT]):
			v.x += 1.0
		if Input.is_physical_key_pressed(dirs[Vector2.LEFT]):
			v.x -= 1.0
		if Input.is_physical_key_pressed(dirs[Vector2.DOWN]):
			v.y += 1.0
		if Input.is_physical_key_pressed(dirs[Vector2.UP]):
			v.y -= 1.0
		return v.limit_length(1.0)
	return Vector2(
		Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	)


## Une touche de CE joueur clavier est-elle pressée ? Utilisé par le
## PlayerManager pour détecter l'arrivée d'un joueur clavier (les touches
## de pause, partagées entre les 2 claviers, ne déclenchent pas l'arrivée).
static func join_pressed(device: int) -> bool:
	if not is_keyboard(device):
		return false
	var buttons: Dictionary = KB1_BUTTONS if device == KEYBOARD_P1 else KB2_BUTTONS
	var dirs: Dictionary = KB1_DIRS if device == KEYBOARD_P1 else KB2_DIRS
	for key in dirs.values():
		if Input.is_physical_key_pressed(key):
			return true
	for button: Action in buttons:
		if button == Action.PAUSE:
			continue
		for key in buttons[button]:
			if Input.is_physical_key_pressed(key):
				return true
	return false
