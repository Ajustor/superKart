# Modes de jeu

Le menu « Jouer » propose trois modes et, sauf en contre-la-montre, une
cylindrée. Tout se règle dans `RaceSetup` ; `RaceLauncher.monter` en tire la
course.

## Fin de course

La course s'arrête quand tous les concurrents sauf un ont franchi la ligne :
le dernier est classé d'office à la dernière place, sans temps (« — » aux
résultats), et son chrono ne compte ni pour les records ni pour le fantôme.
Si c'est le joueur, il passe en pilote automatique comme à une arrivée.

- En contre-la-montre, on court seul : la course attend son arrivée.
- En bataille, c'est `Bataille` qui classe, pas la session.
- En réseau, l'hôte décide et envoie cette arrivée comme les autres.

## Cylindrées (`Cylindree`)

| | Vitesse et accélération | Allure de l'IA |
|---|---|---|
| 50cc | 78 % | 95 % de celle du joueur |
| 100cc | 89 % | 97,5 % |
| 150cc | 100 % (réglage d'origine) | 100 % |
| 200cc | 118 %, braquage compris | 100 % |

- En 50, 100 et 150cc, le braquage ne change pas : plus lent, on tourne plus
  serré. En 200cc, il suit la vitesse, sans quoi un rayon de braquage de
  14 m ne passait plus les épingles de 12,5 m.
- La gravité suit le carré du facteur de vitesse, et l'impulsion des tremplins
  le facteur lui-même. Chaque saut garde ainsi sa trajectoire. Sans ça, en
  50cc, toute l'IA tombait dans le gouffre de la mine.
- Chaque kart reçoit une copie de ses caractéristiques. La ressource
  `default_kart.tres` reste intacte.
- Les records sont rangés par cylindrée. La 150cc garde la clé d'avant
  (l'identifiant du circuit seul), les autres ajoutent `@50cc` ou `@100cc`.
- Le choix de cylindrée est enregistré dans les réglages.
- Le harnais IA la prend en troisième argument :
  `tools/essai_circuit.gd -- <id> <tours> 50`.

## Déblocages

| | Se débloque par | Ce que c'est |
|---|---|---|
| 200cc | l'or dans toutes les coupes en 150cc | vitesse ×1,18 ; le braquage suit, pour que les virages gardent leur forme |
| Miroir | l'or dans toutes les coupes en 100cc | le circuit retourné gauche-droite (`Miroir`) : courbe en x → -x, dévers et écarts latéraux inversés, murs de l'autre côté |

- Les deux ont leurs propres records (`@200cc`, `@miroir`).
- Un déblocage gagné reste gagné (section `deblocages` des réglages) :
  l'arrivée des coupes Aventure et Tempête ne reprend rien à qui avait l'or dans
  les deux premières, mais une nouvelle partie doit gagner les quatre.
- Le podium annonce ce qu'un trophée vient de débloquer.
- En réseau, c'est ce que l'hôte a débloqué qui compte.

## Grand Prix (`GrandPrix`)

- Cinq coupes, définies dans `TrackCatalog.COUPES` :
  - Coupe Grand Air : Collines, Jardin, Plage, Mine ;
  - Coupe Bolide : Forteresse, Ville, Neiges, Ruban ;
  - Coupe Aventure : Canyon, Grotte, Usine, Temple ;
  - Coupe Tempête : Lune, Port, Château, Citadelle ;
  - Coupe Vertige : Grand Huit, Pic des Lacets, Échelle Céleste (2 tours
    chacun) et Cœur de la Terre (3 tours) — des circuits très longs. Une manche se court au nombre de tours de la
    fiche du circuit (`TrackInfo.tours`).
- Chaque manche se court en trois tours (sauf la coupe Vertige). Le barème de `RaceScoring`
  s'additionne d'une course à l'autre.
- Ceux qui n'ont pas franchi la ligne quand le joueur passe à la suite
  prennent la place qu'ils occupaient.
- À égalité de points, le mieux placé à la dernière course passe devant.
- Première course : le joueur choisit sa case. Ensuite, chacun repart de la
  place où il a fini la course précédente (le vainqueur en pole).
- L'écran de résultats ajoute une colonne « Coupe » (le total, cette course
  comprise) et un bouton « Course suivante », puis « Podium ».
- Le podium (`PodiumScreen`) enregistre le meilleur trophée par coupe et par
  cylindrée (or, argent, bronze). Le menu l'affiche sur le bouton de la coupe.

## Contre-la-montre (`FantomeCourse`, `Fantome`)

- Le joueur est seul, en 150cc, sans boîtes, avec un triple champignon au
  départ. Ses records sont à part (`<id>@clm`).
- Le parcours est échantillonné vingt fois par seconde à partir du vert :
  - la position ;
  - l'orientation du kart ;
  - celle de sa caisse, pour que le fantôme dérape aussi.
- Si le temps bat le fantôme enregistré, le parcours le remplace dans
  `user://fantomes/<clé>.fantome`.
- Le fantôme rejoue le meilleur parcours à partir du vert : une copie
  translucide de la caisse et des roues, sans script ni collision.
- Un fichier qui ne commence pas par la signature, ou d'une autre version,
  est ignoré.
- Le fantôme garde aussi son temps de passage à chaque tour. Le joueur voit,
  sous le chrono, son écart au fantôme au même passage : en vert quand il est
  en avance, en rouge quand il est en retard.

## Objets (`ItemManager`, `ItemKind`, `ItemTable`)

Dix objets, tirés selon la place au classement (`ItemTable`, une ligne par
tranche du peloton, une colonne par objet) :

| Objet | Effet |
| --- | --- |
| Champignon, triple champignon | turbo |
| Banane | posée derrière ; qui roule dessus part en tête-à-queue |
| Fausse boîte | comme une banane, déguisée en boîte (rougeâtre, « ¿ ») |
| Carapace verte | tout droit, rebondit sur les murs |
| Carapace rouge | suit la route jusqu'au kart de devant |
| Carapace bleue | survole le peloton jusqu'au premier (le second si c'est lui qui la lance) et explose : tout kart à moins de 4,5 m du premier y passe |
| Éclair | tous les autres karts : tête-à-queue, rétrécis 5 s (vitesse ×0,72), objet perdu |
| Étoile | 7 s intouchable, plus rapide, l'herbe ne freine plus ; les karts percutés partent en tête-à-queue |
| Pièces | +2 pièces (10 au plus) ; chacune donne +1 % de vitesse de pointe ; un choc ou une remise en piste en coûte 3 |

En tête surtout des bananes, fausses boîtes et pièces ; en queue des
carapaces rouges, triples champignons, étoiles, et les rares carapaces
bleues et éclairs.

En réseau, l'hôte décide de tout, comme pour les autres objets ; les effets
sur un kart (étoile, pièces, éclair) sont appliqués par la machine qui le
simule, et l'étoile et le rétrécissement voyagent dans l'instantané du kart
(`KartSnapshot`) : l'hôte doit savoir qu'une carapace ne touche pas un kart
sous étoile.

### Tenir, lancer devant ou derrière, klaxon

Le bouton OBJET se tient (`KartCommand.item_held`, `KartInventory.tenu`) :

- **Appui bref** : l'usage habituel, la banane tombe derrière, la carapace
  part devant.
- **Maintenu** avec une banane, une fausse boîte, une carapace verte ou
  rouge : l'objet traîne derrière le kart (`DISTANCE_TRAINE`). Il arrête les
  carapaces qui arrivent derrière (les deux disparaissent), et un kart qui le
  percute part en tête-à-queue ; dans les deux cas l'objet est perdu, comme
  quand son porteur est sonné.
- **Au lâcher**, après un vrai maintien (`SEUIL_TAPE`) : devant, ou derrière
  si l'on freine (frein tenu, flèche bas, stick vers soi, bouton FREIN au
  doigt). Une banane lancée devant retombe une quinzaine de mètres plus loin ;
  une carapace rouge lancée derrière ne poursuit personne.
- **Sans objet**, le bouton klaxonne (`ItemManager.klaxon`, pas plus d'un coup
  toutes les 0,45 s). Chaque pilote a son ton ; les klaxons des autres
  s'entendent depuis leur kart.

L'IA se sert du même maintien : une banane, une fausse boîte ou une verte
reste derrière elle tant que personne ne la colle, et part en arrière quand un
poursuivant approche ; une carapace part devant quand un kart est aligné dans
sa file. En réseau, le client envoie l'état
du bouton à l'hôte (`RaceSync._tenue`) avant l'appui, l'objet tenu voyage
dans le classement, et l'hôte relaie les klaxons à tous les autres.

## Pilotes d'IA (`AIInput`)

L'IA ne recopie plus la trajectoire idéale : elle court comme un joueur.

- **Sa ligne.** Chaque IA choisit sa ligne autour de la ligne idéale. Elle
  flâne d'un ou deux mètres en ligne droite, et colle à la corde dans les
  virages serrés. Elle n'en change qu'à 3 m/s : elle déboîte, elle ne zigzague
  pas.
- **La course des autres.** La session lui donne, à chaque image, la position
  le long du tracé, l'écart latéral et la vitesse de chaque concurrent
  (`RaceSession.partager_la_course`).
  - Plus rapide qu'un kart dans sa file, elle le double par le côté où la
    route laisse le plus de place.
  - En ligne droite, une IA audacieuse ferme la porte à son poursuivant.
  - Les mains vides, elle va chercher la boîte la plus facile à prendre
    (`ItemManager.boite_visee`).
- **Ses erreurs.** De temps en temps, elle commet une erreur : une
  trajectoire trop large, un lever de pied, ou une glisse manquée. Chaque
  erreur dure au plus 1,2 s, et elle est d'autant plus rare que l'IA est
  régulière.
- **Ses objets.**
  - Le champignon attend une ligne droite ou un kart à doubler, sans attendre
    plus de 4 s.
  - La verte attend une cible.
- **La prudence.** Avant une rampe ou un trou, sur le verglas et dans le vent
  (`Track.zones_prudentes`), elle reprend sa ligne. Elle ne double plus, ne se
  trompe pas et ne lâche aucun objet, pour ne laisser personne sans élan
  devant le vide.

Chaque IA de `race.tscn` a son caractère, réglé par `audace` (doubler,
défendre) et `regularite` (fréquence des erreurs). Le banc d'essai
(`tools/essai_circuit.gd`) a été lancé sur les 20 circuits : aucune remise en
piste, et des temps à 1–3 % de l'ancienne IA, plus étalés d'un kart à
l'autre.

## Pilotes (`Personnage`)

Douze pilotes assis dans les karts, tirés d'œuvres et de traditions du
domaine public, redessinés en formes simples : Chevalier (légendes
arthuriennes), Pirate, Robot (R.U.R., Čapek), Sorcière, Fantôme, Chaperon
(Perrault), Viking (sagas), Momie, Renart (Roman de Renart), Chat botté
(Perrault), Tortue et Lièvre (La Fontaine). Purement d'allure : ils ne
changent que le ton du klaxon.

Chaque pilote est une seule maillage à couleurs de sommets, construite une
fois et partagée : huit pilotes coûtent huit appels de dessin. Le choix se
fait au garage (flèches sous l'aperçu), s'enregistre avec le kart et voyage
dans le salon en réseau ; l'IA prend les pilotes restants.

## Course en fond du menu (`CourseDeFond`)

Derrière l'accueil, huit IA courent sur un circuit tiré au sort, sans
décompte, sans son ni écran de course ; la caméra coupe d'un kart à l'autre
toutes les 8 s, et le dégradé du menu ne fait plus que voiler l'image. Coupée
en qualité basse, sans écran, et par l'option « Course en fond du menu ».

## Musique du menu (`MusiqueMenu`)

Un petit air à 104 bpm, en majeur, avec une batterie discrète et sans
charleston (`Musique.Style.MENU`). Il est composé comme les musiques de
circuit, dans un fil à part à la première ouverture, puis lancé en fondu et
joué en boucle. Il suit le volume « Musique » et se tait sur le serveur
dédié.

## Garage (`ModeleKart`, `GaragePanel`)

On monte son kart en trois pièces, comme dans les jeux de kart : une
carrosserie, des roues et un aileron, quinze de chaque. Les pièces vont des
plus sages aux plus farfelues, avec quelques clins d'œil à la culture
populaire :
- une baignoire avec son canard, un caddie, une soucoupe volante ;
- un carrosse-citrouille, un requin, une chronomobile qui file à 88 miles à
  l'heure, une chauve-souris justicière ;
- des roues en donut, en pizza ou en pierre ;
- une cape de super-héros, des ballons à soulever une maison. On choisit aussi l'une des huit
couleurs et le pilote. Le garage s'ouvre depuis l'accueil et depuis le salon
multijoueur. Chaque pièce se choisit avec ◀ ▶ ; les jauges suivent la
combinaison, et la description dit ce que fait la dernière pièce changée.

Chaque pièce multiplie les caractéristiques du kart d'origine, celui sur
lequel les circuits sont validés. Ses multiplicateurs se combinent avec ceux
des deux autres pièces :

| Carrosserie | Vitesse | Accél. | Virage | Glisse | Poids | Terrain |
| --- | --- | --- | --- | --- | --- | --- |
| Standard | 1 | 1 | 1 | 1 | 1 | 1 |
| Fusée | 1,02 | 0,8 | 1 | 0,9 | 1,1 | 0,95 |
| Plume | 0,985 | 1,3 | 1,08 | 1,05 | 0,8 | 1 |
| Dériveur | 0,995 | 0,95 | 1 | 1,3 | 0,95 | 0,95 |
| Costaud | 1,01 | 0,88 | 0,97 | 0,95 | 1,4 | 1,05 |
| Buggy | 0,99 | 1,1 | 1 | 0,95 | 1,05 | 1,3 |
| Baignoire | 0,985 | 1,15 | 1,04 | 1,1 | 0,95 | 0,9 |
| Caddie | 0,99 | 1,2 | 1,05 | 0,95 | 0,75 | 0,85 |
| Soucoupe | 1,005 | 0,9 | 1,02 | 1,1 | 0,9 | 1 |
| Citrouille | 0,98 | 1,05 | 1 | 1,05 | 1,2 | 1,15 |
| Requin | 1,015 | 0,9 | 1,03 | 0,95 | 1,1 | 0,9 |
| Chronomobile | 1,02 | 0,85 | 0,98 | 1,05 | 1,05 | 0,9 |
| Hot-dog | 0,995 | 1,05 | 1 | 1 | 1,15 | 1,05 |
| Tracteur | 0,98 | 1 | 0,97 | 0,9 | 1,5 | 1,4 |
| Chauve-souris | 1,015 | 0,95 | 1 | 1 | 1,2 | 1 |

| Roues | Vitesse | Accél. | Virage | Glisse | Poids | Terrain |
| --- | --- | --- | --- | --- | --- | --- |
| Standard | 1 | 1 | 1 | 1 | 1 | 1 |
| Slicks | 1,008 | 0,95 | 1,03 | 1 | 1 | 0,8 |
| Monstre | 0,992 | 0,9 | 0,98 | 0,97 | 1,15 | 1,35 |
| Roller | 0,992 | 1,2 | 1,02 | 1,08 | 0,9 | 0,85 |
| Néon | 1 | 1,05 | 1 | 1,1 | 1 | 0,9 |
| Donuts | 0,992 | 1,1 | 1 | 1,05 | 1 | 0,9 |
| Pizzas | 1 | 1 | 0,99 | 1,08 | 1,05 | 0,95 |
| Pierre | 0,992 | 0,85 | 1 | 0,95 | 1,25 | 1,3 |
| Vinyles | 1,004 | 1 | 1,02 | 1 | 0,95 | 0,8 |
| Bouées | 0,992 | 1,05 | 0,99 | 1,1 | 0,85 | 1 |
| Cookies | 0,996 | 1,15 | 1 | 1 | 0,95 | 0,9 |
| Engrenages | 1,004 | 0,95 | 1 | 1 | 1,1 | 1,15 |
| Bling | 1,006 | 0,97 | 1,01 | 1 | 1,05 | 0,85 |
| Fromages | 0,996 | 1 | 0,99 | 1 | 1,1 | 1,1 |
| Western | 0,996 | 1,05 | 0,99 | 1,05 | 1 | 1,05 |

| Aileron | Vitesse | Accél. | Virage | Glisse | Poids | Terrain |
| --- | --- | --- | --- | --- | --- | --- |
| Becquet | 1 | 1 | 1 | 1 | 1 | 1 |
| Grand aileron | 1,003 | 0,95 | 1,03 | 1 | 1,03 | 1 |
| Ailettes | 0,997 | 1,06 | 1,02 | 1 | 0,95 | 1 |
| Voile | 0,997 | 1 | 1 | 1,08 | 1 | 1,05 |
| Hélice | 1,003 | 0,97 | 1 | 1,05 | 1 | 1 |
| Parasol | 0,997 | 1,02 | 1 | 1,03 | 1 | 1,05 |
| Ailes d'ange | 0,997 | 1,05 | 1 | 1 | 0,92 | 1 |
| Ailes de dragon | 1,003 | 0,97 | 1 | 1,05 | 1,05 | 1 |
| Cape | 1,002 | 1 | 1,02 | 1 | 1 | 0,97 |
| Drapeau pirate | 1 | 1,03 | 1 | 1,02 | 1 | 0,97 |
| Ballons | 0,997 | 1,04 | 0,99 | 1 | 0,9 | 1 |
| Parabole | 1 | 0,98 | 1,03 | 1 | 1,02 | 1 |
| Réacteur | 1,003 | 1,04 | 0,995 | 0,97 | 1,05 | 1 |
| Nageoire | 1 | 1 | 1,01 | 1,04 | 1 | 0,96 |
| Feux d'artifice | 1,003 | 1,03 | 1 | 0,98 | 1 | 0,98 |

Aucune pièce n'est meilleure en tout : chacune gagne quelque chose et en perd
autre chose (le poids n'est compté ni comme l'un ni comme l'autre). Les
tests le vérifient, et vérifient aussi deux garde-fous sur les
3 375 combinaisons : les sauts et le rayon de braquage (voir plus bas).

La vitesse de pointe ne varie que de quelques pour cent, parce que c'est elle
qui décide d'un chrono. Mesuré en contre-la-montre, avec une IA sans erreurs
sur six circuits et en changeant une pièce à la fois
(`tools/essai_circuit.gd -- <id> 2 150 seul kart=N`) :
- **Avant réglage** : Fusée 4 % plus rapide, Plume 3 % plus lent.
- **Après** : Fusée 2 % plus rapide, Plume 1,5 % plus lent.

L'accélération, la maniabilité et la glisse paient surtout en course : après
un choc ou un objet, sous un mini-turbo, et pour un joueur qui enchaîne les
glisses.

Les caractéristiques agissent ainsi sur le kart :
- **Glisse** : divise les seuils des paliers de mini-turbo et allonge les
  mini-turbos (de sa racine carrée).
- **Poids** : pèse dans les chocs entre karts, où le plus léger prend la plus
  grande part de l'échange, et réduit la perte de vitesse contre un mur.
- **Terrain** : multiplie la vitesse gardée hors piste (bornée à 0,9).

Deux garde-fous gardent tous les circuits praticables, quelle que soit la
combinaison :
- **Les sauts** : comme pour les cylindrées, la gravité suit le carré du
  facteur de vitesse, et l'impulsion des tremplins le facteur lui-même.
  Chaque saut garde ainsi sa parabole, et un kart lent passe les trous.
- **Les épingles** : le braquage ne suit pas la vitesse, si bien qu'une
  combinaison rapide prend ses virages plus large. Le rayon de braquage
  reste pourtant sous celui de l'épingle du circuit 1 (13,3 m).

Chaque pièce a son allure : des formes simples en une seule maillage à
couleurs de sommets, peintes de la couleur du kart et partagées entre les
karts identiques.
Les formes sont dans `AtelierPieces`.
- **Carrosseries et ailerons** : ils se posent dans le repère de la caisse.
- **Roues** : chaque train a son rayon, sa largeur et ses couleurs. Leurs
  décors (vermicelles, pepperoni, sillons, pépites…) vont sur les deux faces,
  puisqu'on voit l'une à gauche du kart et l'autre à droite. Une roue plus
  grande se monte plus haut, et la suspension apprend son rayon.

Les sept adversaires de l'IA courent dans des karts variés et fixes
(`ModeleKart.KARTS_IA`) : chaque machine d'une partie en réseau les habille
de la même façon. Leurs vitesses de pointe restent à 1 % de celle d'origine :
le classement de l'IA reste une affaire de pilote. Un kart 4 % plus rapide
gagnait 37 courses sur 40, même sur un pilote moyen.

Le choix est enregistré (section `[garage]` des réglages : `modele`,
`roues`, `aileron`, `couleur`, `personnage`). En réseau, chaque joueur
l'annonce à l'hôte, qui le range dans le salon et le met dans le plan de
course. Tout le monde voit chacun dans son kart, et le poids de chacun compte
dans les chocs. L'IA prend les couleurs restantes. Le protocole passe en
version 8.

Le harnais IA accepte `kart=N`, `roues=N` et `aileron=N` pour valider une
combinaison : `tools/essai_circuit.gd -- <id> 1 200 kart=4 roues=2 aileron=1`.

## Bataille (`Bataille`, arènes de `TrackCatalog.ARENES`)

Trois ballons chacun. Chaque objet encaissé (carapace, banane, fausse boîte,
explosion) en crève un ; sans ballon, on est éliminé et classé derrière tous
ceux qui en ont encore. Le dernier en lice gagne ; au bout de 3 minutes, les
survivants sont classés au nombre de ballons.

- L'arène est un anneau large et fermé de murs (`arene_ovale`), hors du menu
  des courses et des coupes. Les karts y partent dispersés, sans grille ni
  portique.
- La session ne compte pas de tours (`RaceSession.sans_tours`) : `Bataille`
  donne les places comme des arrivées, et l'écran des résultats suit sans
  changement.
- Table d'objets à part : ni carapace bleue, ni éclair, ni pièces. La
  carapace rouge vise le kart en jeu le plus proche devant soi.
- Un kart d'IA éliminé quitte l'arène ; le joueur éliminé s'arrête et voit
  les résultats.
- Solo contre l'IA pour l'instant ; pas encore en réseau.

Harnais : `tools/essai_circuit.gd -- arene_ovale 1 150 bataille`.

## Touches (`Touches`, `TouchesPanel`)

Au clavier, chaque action a deux touches : les flèches (plus Espace, Ctrl,
Échap) et des lettres rangées par **position physique** : WASD sur un QWERTY,
ZQSD sur un AZERTY, sans rien régler (Maj pour déraper, E pour l'objet).
L'écran *Options → Changer les touches* montre ces deux emplacements et la
manette, nomme les touches telles qu'elles sont écrites sur le clavier du
joueur (`DisplayServer.keyboard_get_label_from_physical`) et affiche la
disposition détectée. Une touche ne sert qu'à une action, et qu'à un
emplacement.

## Glisse et grand turbo (`KartMotor`, `KartStats`)

Pendant une glisse, le stick choisit la courbe, en douceur : vers
l'intérieur, la plus serrée (9,6 m de rayon à 22 m/s) ; au neutre, 12,3 m ;
en contre-braquant, presque une ligne droite (environ 190 m). La charge du
mini-turbo monte à plein régime vers l'intérieur, à 70 % en contre-braquant.
Paliers à 0,6 s, 1,5 s et 2,6 s de charge pleine.

Le contre-braquage ouvrait autrefois la glisse à 27 m seulement : les grandes
courbes des circuits, de 50 à 90 m de rayon et souvent longues de plus de
cinq secondes, ne se tenaient pas en glisse, et le grand turbo n'existait que
dans les épingles. `tools/essai_glisse.gd` fait tenir la glisse à un joueur
au clavier sur des cercles de 12 à 90 m ; le palier 3 y tombe entre 3,2 et
3,9 s, à 1,7 m au plus du milieu de la route, et `tests/test_glisse.gd` le
garde ainsi. L'IA, réglée sur l'ancienne courbe, contre-braque moins fort
(`AIInput.CONTRE_BRAQUAGE_MAX`, -0,4 au lieu de -0,7) pour garder ses temps.
