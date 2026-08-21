extends Node

var run_info: Dictionary = {
	"level_number" : 0,
	"run_duration" : 0, # en millisecondes
	"players_info": {
		"default" : {
			"lives": 3,
			"ammunitions": [5, 3, 3],
			"attacks": {
				GlobalEnum.AttackFamily.Red:
					{
						"attack_type" : GlobalEnum.AttackType.ICEBLADE,
						"attack_tier" : GlobalEnum.AttackTier.I
					},
				GlobalEnum.AttackFamily.Blue:
					{
						"attack_type" : GlobalEnum.AttackType.ICESPIKE,
						"attack_tier" : GlobalEnum.AttackTier.I
					},
				GlobalEnum.AttackFamily.Yellow:
					{
						"attack_type" : GlobalEnum.AttackType.LIGHTRAY,
						"attack_tier" : GlobalEnum.AttackTier.I
					},
			}
		}
	}
}
