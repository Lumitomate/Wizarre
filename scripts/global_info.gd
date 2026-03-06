extends Node

var run_info: Dictionary = {
	"run_duration" : 0, # en millisecondes
	"players_info": {
		"default" : {
			"lives": 3,
			"ammunitions": [3, 3, 3],
			"attacks": {
				Enum.AttackFamily.Red:
					{
						"attack_type" : Enum.AttackType.FIRECOLUMN,
						"attack_tier" : Enum.AttackTier.I
					},
				Enum.AttackFamily.Blue:
					{
						"attack_type" : Enum.AttackType.ICEBALL,
						"attack_tier" : Enum.AttackTier.I
					},
				Enum.AttackFamily.Yellow:
					{
						"attack_type" : Enum.AttackType.LIGHTRAY,
						"attack_tier" : Enum.AttackTier.I
					},
			}
		}
	}
}
