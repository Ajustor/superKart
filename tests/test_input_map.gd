extends GutTest

const ACTIONS := [
	"steer_left", "steer_right", "throttle", "brake", "drift", "use_item",
]


func test_toutes_les_actions_de_pilotage_sont_declarees() -> void:
	for action in ACTIONS:
		assert_true(InputMap.has_action(action), "action manquante : %s" % action)


func test_chaque_action_a_au_moins_une_liaison() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			continue
		assert_gt(InputMap.action_get_events(action).size(), 0,
			"l'action %s n'a aucune liaison" % action)
