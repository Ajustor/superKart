# Plan 3 — IA, grille et classement, plus le relief et le kart

## Ce que ça apporte

- **Sept adversaires qui pilotent pour de vrai.** `AIInput` produit le même `KartCommand` que le joueur, donc elle subit la même physique : elle ne peut pas prendre un virage que le joueur ne pourrait pas prendre, et elle dérape avec les mêmes étincelles.
- **Une grille de départ sur deux colonnes** et **un classement trié sur un seul nombre** — la distance parcourue que `RaceProgress` tenait déjà. Trier là-dessus et sur rien d'autre est ce qui rend la grille décalée équitable.
- **Une piste en trois dimensions** : pente, dévers, et un kart qui se couche dessus.
- **Un vrai kart** sur quatre roues et quatre amortisseurs, à la place de la boîte.
- **La manette**, qui ne marchait pas.

La branche dépasse le périmètre du plan 3 : le relief, le dérapage, la manette et le modèle de kart sont venus de demandes faites en cours de route.

## Ce que la mesure a trouvé, et que les tests n'avaient pas vu

Neuf défauts réels ont vécu sous une campagne verte. Tous trouvés en mesurant, jamais en lisant.

| défaut | mesure |
|---|---|
| l'IA ne dérapait **jamais** | 0 entrée en glisse sur un tour complet |
| la manette ne répondait qu'au périphérique d'index 0 | `device = 0` au lieu de `-1` |
| la piste à plusieurs niveaux téléportait le kart | 1575 téléportations sur 1800 images |
| le kart volait au lieu de suivre la pente | 74 % du tour en l'air |
| un virage se repliait sur lui-même | vitesse réelle (0,0,0) pendant 30 s, moteur à fond |
| s'engager dans une glisse **élargissait** la trajectoire | 13,97 m de rayon contre 12,22 m en adhérence |
| les trois mini-turbos poussaient à la même vitesse | 29,70 m/s pour les trois paliers |
| l'ancrage de suspension suivait la roue qu'il portait | les 4 ressorts collés à leurs butées |
| la chaussée roulait sans qu'on le lui demande | 27° de roulis pour 14 tilts à zéro |

Trois d'entre eux ont demandé plusieurs diagnostics faux avant le bon. L'IA qui ne dérape pas en a coûté trois : elle décidait sur son écart de cap — une erreur de *suivi* — donc plus elle pilotait bien, moins elle dérapait ; puis son hystérésis ne couvrait pas le saut, qu'elle ratait d'une image ; puis elle jugeait le virage à sa distance de mire, déjà 10 m après l'apex quand ses roues y entraient.

## Ce que ça a coûté aux tests

96 → 195, sur 16 scripts. Les ajouts notables :

- `TrackSmoother` (13) — ouvrir un virage impraticable, incliner la piste
- `KartSpring` (12) — rebond, amortissement, butées
- `TrackCurve` (+13) — pente, dévers, repère 3D, détection des plis
- `AIInput` (+3 réécrits) — la décision de déraper, sur la sévérité du virage
- carte d'entrées (+5) — chaque action jouable clavier **et** manette

Deux tests ont été supprimés parce qu'ils figeaient une supposition erronée de ma part, pas un comportement voulu : l'un exigeait des gaz analogiques à la manette, l'autre affirmait qu'un ressort sans amortisseur oscille sans fin.

## Plan de vérification

- [x] 195 tests verts, 16 scripts, sur Godot 4.7.2
- [x] `scenes/race.tscn` charge 300 images sans `ERROR` ni `SCRIPT ERROR`
- [x] L'éditeur s'ouvre sans erreur de script
- [x] Les 7 IA bouclent 3 tours : 109,23 à 126,70 s, 8 à 11 glisses chacune
- [x] Suspension : 103 à 130 mm de course sur 130, tangage −2,2 à +5,9°
- [ ] **Session de conduite humaine** — rien de tout ça n'a été conduit. Le headless ne rastérise pas : il ne dit ni si le kart est beau, ni si la suspension se sent, ni si la manette tombe bien sous les doigts.

## Réserves connues

- **Le dévers plafonne à 15°.** Mesuré : l'IA boucle à 0, 10 et 18° et n'y arrive plus du tout à 22. Le défaut est dans `TrackBuilder`, qui relie deux sections par deux triangles sans rien savoir de leur inclinaison relative. Il faudra le reprendre pour aller plus haut.
- **L'IA n'encaisse aucun mini-turbo.** L'épingle donne 0,50 s de charge quand le palier 1 en demande 0,60. Aller au-delà l'envoyait hors du bitume. Les leviers restants sont `drift_tiers[0]`, qui touche au pilotage du joueur, ou un virage plus long.
- **L'accélération n'est plus analogique** à la manette : les gâchettes servent au saut et à l'objet, comme dans un Mario Kart. C'est fidèle, mais c'est un changement.
- **La suspension est cosmétique.** Délibérément : lui confier la trajectoire reviendrait à réécrire `KartMotor` et à jeter ses 45 tests, pour un réalisme qu'aucun jeu de kart ne demande.
- **Pas de collision entre karts gérée.** Mesuré sur une course à huit : chacun reste immobile 150 à 620 images sur 9000, et toujours dans des sections larges — rayon 75 à 140 m, pente nulle. Ce ne sont donc pas des virages ratés, ce sont les karts qui se rentrent dedans. Pas de décompte au départ, pas d'objets, pas d'écran de fin non plus. `motor.speed` n'est toujours pas réconcilié après un `move_and_slide()` — sans mur ni choc, c'est sans effet aujourd'hui.
- **Un virage à 12,5 m de rayon** subsiste, juste au-dessus des 12,2 m de braquage du kart. Le nœud `Track` prévient dans l'éditeur tant que quelque chose passe en dessous.

## Une erreur à signaler

Le commit `7068ae1` affirmait que `spawn_at` rendait le repère complet de la route. C'était faux : la substitution n'avait jamais mordu et mon script avait annoncé sa réussite sans la vérifier. Le kart naissait encore à plat au milieu des pentes. Corrigé dans `81d32cb`, avec une assertion cette fois.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
