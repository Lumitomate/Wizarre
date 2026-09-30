# Wizarre

A 2D local multiplayer action game for up to 4 players on one machine. Players control sorcerers who fight waves of enemies, collect power-ups, and visit a shop between levels.

## Characters

**Sorcerer**:
A player-controlled character. Each sorcerer has a color (Red, Green, Blue, Yellow), a set of lives, and three attack tubes.
_Avoid_: Mage, Wizard, Spellcaster

**Enemy**:
A hostile creature that spawns in waves. When killed, it may drop items. Enemies take damage from player attacks.
_Avoid_: Monster, Mob, Foe

## Combat

**Attack Tube**:
One of three spell slots per sorcerer, each bound to a face button (ATK1, ATK2, ATK3) and holding one attack type with its own ammunition.
_Avoid_: Tube (alone is fine), Slot, Weapon

**Attack Family**:
The energy associated with an attack tube: Fossil, Pure, or Tainted. A fourth family, Green, is currently unused.
_Avoid_: Element (reserved for attack types), Color, Category, School

**Attack Type**:
The specific spell a sorcerer fires. There are 13 types across 4 elements: Fireball (F0), FireColumn (F1), FireWave (F2), FireMine (F3), IceBall (G1), IceSpike (G2), IceBlade (G3), LightRay (L1), LightTarget (L2), LightBow (L3), Carnivorous (P1), PlantBall (P2), PlantBrush (P3).
_Avoid_: Spell, Ability, Move

**Element**:
The family of attack types sharing the first letter of their type code (F, G, L, P). All attacks of the same element owned by a sorcerer share a tier.
_Avoid_: Family (reserved for tubes), Type, Kind

**Attack Tier**:
The power level of an attack, from I (Bronze) to III (Gold). The tier is shared by every attack of the same element a sorcerer owns: collecting a second attack of an element upgrades the first one too. Higher tiers deal more damage or have larger area of effect.
_Avoid_: Level, Rank, Grade

**Ammunition**:
A limited resource that refills between levels. Each attack tube has its own ammunition count.
_Avoid_: Ammo (colloquial), Bullet, Charge

**Damage**:
Dealt to enemies or to the sorcerer. Reduces lives by the damage amount. A sorcerer with 0 lives dies.
_Avoid_: HP, Hit Points, Health

**Lives**:
A sorcerer's remaining survivability. Starts at 3. Reaching 0 means death.
_Avoid_: Hearts, Life Points

**Dash**:
A short burst of speed that makes the sorcerer briefly invincible and lets it pass through enemies and other players. Dashing also cancels an ongoing aiming action (LightBow, LightTarget).
_Avoid_: Sprint, Rush, Roll

## Progression

**Run**:
A single complete playthrough: Homepage → Level → Shop → Level → ... until all sorcerers are dead.
_Avoid_: Game, Session, Playthrough

**Level**:
A combat arena containing enemies, obstacles, and a portal to the shop. Each level requires killing a target number of enemies before the exit opens.
_Avoid_: Stage, Wave, Arena

**Shop**:
A rest area between levels where sorcerers can change their attack types and tiers. Access is automatic when the level's enemy quota is met.
_Avoid_: Store, Merchant, Upgrade Shop

**Shophands**:
The 3-4 player shop: a randomly chosen sorcerer (the Decider) is locked at the top with three pressure plates and closing hands, and sends the visit's single item to one of the other sorcerers, each locked in a side box. The exit door opens only once the item is caught.
_Avoid_: Hand Shop, Gift Shop

**Decider**:
The sorcerer randomly chosen at each Shophands visit to decide who receives the shop's single item. The Decider never receives the item.
_Avoid_: Chooser, Dealer, Giver

**Power-up**:
An item dropped by enemies or placed in the shop. Collecting it changes a sorcerer's attack configuration.
_Avoid_: Pickup, Bonus, Collectible

## World

**Controller**:
A gamepad connected to the machine. Each controller spawns one sorcerer. Up to 4 controllers supported.
_Avoid_: Joystick, Pad, Gamepad

**Homepage**:
The title screen where players connect controllers before starting a run.
_Avoid_: Title, Menu, Lobby

**Door**:
An animated barrier that opens when a condition is met (time elapsed, friendship meter full, or no damage taken). Passing through it triggers the next event.
_Avoid_: Gate, Portal, Exit

## State

**State**:
A sorcerer's current animation/movement state: Idle, Run, Jump, Fall, or Attack.
_Avoid_: Mode, Phase, Pose