extends SceneTree

## Génère la courbe d'un des circuits dessinés ici, et l'enregistre en
## ressource. Comme build_track_01.gd : à lancer une fois, puis la courbe se
## retouche à la souris dans l'éditeur.
##
##   godot --headless --path . -s tools/build_track_curves.gd -- <id> [--force]
##   godot --headless --path . -s tools/shape_track_curve.gd -- <courbe> <rayon_min> <devers_max>
##
## Le second passage ouvre les virages trop serrés et relève les autres ; les
## éléments (murs, rampes, trous…) se placent ensuite, dans la scène du
## circuit, aux distances que donne tools/profil_circuit.gd.
##
## Les points sont donnés dans le sens de la marche, altitude comprise. Le
## premier est la ligne de départ : le dernier tronçon, qui y ramène, doit
## être droit, la grille s'y range.

const CIRCUITS := {
	# Un bord de mer : une ligne droite sur la plage, une dune qu'on
	# franchit d'un bond, un lacet autour du phare, et un bras de mer à
	# sauter avant de revenir.
	"plage_palmiers": [
		Vector3(0, 0, 0),
		Vector3(80, 0, 0),
		Vector3(140, 1, -25),
		Vector3(165, 3, -85),
		Vector3(145, 4, -145),
		Vector3(95, 1, -170),
		Vector3(40, 0, -150),
		Vector3(-5, 0, -175),
		Vector3(-35, 0, -230),
		Vector3(-15, 0, -285),
		Vector3(-75, 0, -300),
		Vector3(-120, 0, -250),
		Vector3(-130, 0, -165),
		Vector3(-130, 0, -85),
		Vector3(-105, 0, -30),
		Vector3(-55, 0, 0),
	],
	# Un château : des couloirs droits, des virages à angle droit, une montée
	# vers les remparts, une chicane là-haut, et une douve de lave à sauter.
	"forteresse_lave": [
		Vector3(0, 0, 0),
		Vector3(90, 0, 0),
		Vector3(125, 0, -30),
		Vector3(125, 2, -95),
		Vector3(100, 6, -135),
		Vector3(40, 10, -140),
		Vector3(5, 10, -120),
		Vector3(-35, 10, -145),
		Vector3(-75, 10, -122),
		Vector3(-112, 7, -148),
		Vector3(-140, 2, -125),
		Vector3(-145, 0, -45),
		Vector3(-105, 0, 0),
	],
	# Un ruban suspendu dans le vide, en huit : il passe sous lui-même au
	# centre, vingt mètres plus bas, et finit sa boucle ouest par un grand saut.
	"ruban_celeste": [
		Vector3(-40, 20, -40),
		Vector3(40, 20, 40),
		Vector3(100, 24, 95),
		Vector3(170, 30, 65),
		Vector3(185, 34, -20),
		Vector3(135, 38, -75),
		Vector3(60, 40, -60),
		Vector3(-60, 40, 60),
		Vector3(-130, 36, 70),
		Vector3(-175, 31, 5),
		Vector3(-160, 26, -80),
		Vector3(-105, 22, -110),
		Vector3(-65, 20, -75),
	],
	# Un jardin de champignons géants : des bosses qui roulent, un S entre
	# les chapeaux, et un champignon rebondissant au milieu du parcours.
	"jardin_champignon": [
		# Un trèfle à trois feuilles vu du ciel : trois grands lobes qui
		# ondulent entre les chapeaux, et trois resserrements au cœur du
		# jardin, où les champignons font rebondir.
		Vector3(104, 6, -60),
		Vector3(59, 3, -59),
		Vector3(34, 0, -59),
		Vector3(22, 0, -80),
		Vector3(0, 3, -120),
		Vector3(-41, 6, -151),
		Vector3(-86, 6, -149),
		Vector3(-111, 3, -111),
		Vector3(-104, 0, -60),
		Vector3(-80, 0, -22),
		Vector3(-68, 3, -0),
		Vector3(-80, 6, 22),
		Vector3(-104, 6, 60),
		Vector3(-111, 3, 111),
		Vector3(-86, 0, 149),
		Vector3(-41, 0, 151),
		Vector3(-0, 3, 120),
		Vector3(22, 6, 80),
		Vector3(34, 6, 59),
		Vector3(59, 3, 59),
		Vector3(104, 0, 60),
		Vector3(151, 0, 41),
		Vector3(172, 3, 0),
		Vector3(151, 6, -41),
	],
	# Une mine : on descend dans les galeries entre des parois, on longe les
	# cristaux au fond, on saute un gouffre et on remonte au jour.
	"mine_scintillante": [
		Vector3(0, 0, 0),
		Vector3(80, 0, 0),
		Vector3(130, -4, -40),
		Vector3(125, -10, -100),
		Vector3(70, -14, -125),
		Vector3(10, -14, -95),
		Vector3(-45, -14, -130),
		Vector3(-110, -12, -125),
		Vector3(-145, -7, -65),
		Vector3(-115, -2, -12),
		Vector3(-60, 0, 0),
	],
	# Une ville la nuit : des rues à angle droit entre les tours, et une
	# avenue coupée par des travaux qu'on franchit d'un saut.
	"ville_neon": [
		Vector3(0, 0, 0),
		Vector3(80, 0, 0),
		Vector3(125, 0, -30),
		Vector3(130, 0, -75),
		Vector3(100, 0, -115),
		Vector3(55, 0, -115),
		Vector3(25, 0, -140),
		Vector3(20, 0, -180),
		Vector3(-10, 0, -215),
		Vector3(-55, 0, -215),
		Vector3(-85, 0, -180),
		Vector3(-90, 0, -90),
		Vector3(-85, 0, -35),
		Vector3(-45, 0, 0),
	],
	# Une station de ski : départ au sommet, une longue descente à bosses
	# jusqu'au fond de la vallée, et la remontée par le col.
	"station_neiges": [
		# Une vraie piste de ski : quatre traversées de la pente en
		# descendant, reliées par des épingles, puis la longue remontée
		# du télésiège par la vallée.
		Vector3(0, 32, 0),
		Vector3(95, 32, 0),
		Vector3(145, 30, 15),
		Vector3(160, 28, 45),
		Vector3(130, 26, 72),
		Vector3(65, 25, 78),
		Vector3(10, 23, 70),
		Vector3(-35, 21, 85),
		Vector3(-45, 19, 120),
		Vector3(-15, 17, 145),
		Vector3(45, 16, 138),
		Vector3(105, 14, 148),
		Vector3(150, 13, 175),
		Vector3(140, 12, 210),
		Vector3(95, 10, 225),
		Vector3(30, 9, 222),
		Vector3(-40, 9, 225),
		Vector3(-95, 10, 200),
		Vector3(-115, 15, 140),
		Vector3(-115, 22, 70),
		Vector3(-105, 28, 30),
		Vector3(-75, 32, 5),
	],
	# Un canyon de grès : une ligne droite balayée par les rafales, un
	# tunnel creusé dans une mesa, et un ravin à sauter dans un anneau d'or.
	"canyon_venteux": [
		Vector3(0, 0, 0),
		Vector3(90, 0, 0),
		Vector3(145, 1, -30),
		Vector3(160, 3, -90),
		Vector3(130, 5, -140),
		Vector3(70, 6, -150),
		Vector3(20, 6, -185),
		Vector3(-20, 4, -240),
		Vector3(-85, 2, -250),
		Vector3(-140, 0, -200),
		Vector3(-150, 0, -130),
		Vector3(-115, 0, -80),
		Vector3(-140, 0, -30),
		Vector3(-105, 0, -5),
		Vector3(-55, 0, 0),
	],
	# Une grotte de glace, en huit : on plonge sous le glacier, et la galerie
	# passe vingt-deux mètres sous la ligne de départ avant de remonter.
	"grotte_glacee": [
		Vector3(-40, 0, -40),
		Vector3(40, 0, 40),
		Vector3(100, -3, 95),
		Vector3(170, -8, 65),
		Vector3(185, -14, -20),
		Vector3(135, -19, -75),
		Vector3(60, -22, -60),
		Vector3(-60, -22, 60),
		Vector3(-130, -18, 70),
		Vector3(-175, -12, 5),
		Vector3(-160, -6, -80),
		Vector3(-105, -2, -110),
		Vector3(-65, 0, -75),
	],
	# Une usine : des allées à angle droit, des tapis roulants, des pilons,
	# et un passage sous la grande presse.
	"usine_engrenages": [
		Vector3(0, 0, 0),
		Vector3(100, 0, 0),
		Vector3(150, 0, -35),
		Vector3(155, 0, -100),
		Vector3(115, 0, -135),
		Vector3(60, 0, -120),
		Vector3(15, 0, -150),
		Vector3(10, 0, -210),
		Vector3(-40, 0, -240),
		Vector3(-100, 0, -215),
		Vector3(-110, 0, -150),
		Vector3(-70, 0, -105),
		Vector3(-120, 0, -55),
		Vector3(-105, 0, -5),
		Vector3(-55, 0, 0),
	],
	# Une jungle : un gué dans le courant de la rivière, un temple qu'on
	# traverse par ses galeries, et un couloir de marteaux qui balancent.
	"temple_jungle": [
		# Un fleuve qui serpente dans la jungle : la gorge à sauter au
		# départ, trois grands méandres où se cache le temple, un demi-tour
		# au bout du fleuve et le retour par la piste de la jungle.
		Vector3(0, 0, 0),
		Vector3(90, 0, 0),
		Vector3(162, 1, -42),
		Vector3(194, 1, -54),
		Vector3(226, 0, -30),
		Vector3(258, -1, 15),
		Vector3(290, -1, 50),
		Vector3(322, -0, 50),
		Vector3(354, 1, 15),
		Vector3(386, 1, -30),
		Vector3(418, 1, -54),
		Vector3(450, -1, -42),
		Vector3(495, 1, 30),
		Vector3(540, 2, -20),
		Vector3(545, 3, -110),
		Vector3(500, 4, -180),
		Vector3(400, 5, -200),
		Vector3(300, 6, -195),
		Vector3(200, 5, -205),
		Vector3(100, 3, -195),
		Vector3(10, 2, -180),
		Vector3(-60, 1, -140),
		Vector3(-80, 0, -75),
		Vector3(-55, 0, -20),
	],
	# Une base sur la Lune : la gravité y faiblit par endroits, et l'on
	# saute les cratères en visant des anneaux d'or.
	"base_lunaire": [
		# Un croissant de lune : une ligne droite au bas, une épingle à
		# chaque pointe, l'arc intérieur sous les dômes de la base et le
		# grand arc extérieur, où l'on vole par-dessus les cratères.
		Vector3(-60, 0, 150),
		Vector3(20, 0, 152),
		Vector3(80, 1, 158),
		Vector3(125, 2, 140),
		Vector3(132, 3, 108),
		Vector3(105, 4, 92),
		Vector3(42, 4, 88),
		Vector3(22, 4, 63),
		Vector3(9, 4, 32),
		Vector3(5, 4, -0),
		Vector3(9, 4, -32),
		Vector3(22, 4, -62),
		Vector3(42, 4, -88),
		Vector3(105, 4, -92),
		Vector3(132, 3, -108),
		Vector3(125, 2, -140),
		Vector3(80, 1, -170),
		Vector3(30, 0, -188),
		Vector3(-65, 0, -179),
		Vector3(-134, 4, -134),
		Vector3(-179, 5, -65),
		Vector3(-189, 1, 17),
		Vector3(-165, -1, 95),
		Vector3(-127, 0, 141),
		Vector3(-100, 0, 152),
	],
	# Un port de pirates : des quais où roulent les tonneaux, une crique au
	# courant traître, une grotte marine, et un saut depuis le pont d'un
	# galion.
	"port_pirate": [
		Vector3(0, 0, 0),
		Vector3(90, 0, 0),
		Vector3(135, 0, 30),
		Vector3(140, 0, 95),
		Vector3(95, 2, 135),
		Vector3(30, 4, 125),
		Vector3(-15, 4, 160),
		Vector3(-75, 2, 175),
		Vector3(-125, 0, 140),
		Vector3(-130, 0, 75),
		Vector3(-175, 0, 40),
		Vector3(-170, 0, -20),
		Vector3(-120, 0, -30),
		Vector3(-100, 0, -5),
		Vector3(-55, 0, 0),
	],
	# Un manoir la nuit : on descend dans la crypte, qui passe vingt-deux
	# mètres sous la cour du départ, entre des lames qui balancent.
	"manoir_hante": [
		Vector3(0, 0, 0),
		Vector3(70, 0, 0),
		Vector3(125, -3, 30),
		Vector3(125, -9, 95),
		Vector3(80, -15, 130),
		Vector3(30, -21, 100),
		Vector3(25, -22, 40),
		Vector3(25, -22, -50),
		Vector3(10, -19, -115),
		Vector3(-50, -13, -140),
		Vector3(-115, -7, -110),
		Vector3(-130, -3, -50),
		Vector3(-100, 0, -5),
		Vector3(-50, 0, 0),
	],
	# Une citadelle dans les nuages, sous l'orage : des rafales qui
	# soufflent tour à tour, des trous dans le vide, des marteaux de foudre.
	"citadelle_orages": [
		Vector3(0, 40, 0),
		Vector3(100, 40, 0),
		Vector3(160, 44, -40),
		Vector3(170, 50, -110),
		Vector3(120, 55, -160),
		Vector3(50, 55, -150),
		Vector3(10, 52, -200),
		Vector3(-50, 48, -240),
		Vector3(-120, 44, -220),
		Vector3(-160, 42, -150),
		Vector3(-130, 40, -90),
		Vector3(-160, 40, -40),
		Vector3(-110, 40, -5),
		Vector3(-55, 40, 0),
	],
	# Le cœur de la Terre : un puits en hélice qui plonge à 85 m sous la
	# surface — chaque tour passe sous le précédent —, une galerie au-dessus
	# d'un lac de magma, et un second puits pour remonter au jour.
	"coeur_terre": [
		Vector3(0, 0, 0),
		Vector3(60, 0, 0),
		Vector3(110, 0, 0),
		Vector3(129.8, -1, 8.2),
		Vector3(138, -4, 28),
		Vector3(129.8, -8.7, 47.8),
		Vector3(110, -13.5, 56),
		Vector3(90.2, -18.4, 47.8),
		Vector3(82, -23.2, 28),
		Vector3(90.2, -28, 8.2),
		Vector3(110, -32.8, 0),
		Vector3(129.8, -37.7, 8.2),
		Vector3(138, -42.5, 28),
		Vector3(129.8, -47.3, 47.8),
		Vector3(110, -52.2, 56),
		Vector3(90.2, -57, 47.8),
		Vector3(82, -61.8, 28),
		Vector3(90.2, -66.6, 8.2),
		Vector3(110, -71.5, 0),
		Vector3(129.8, -76.3, 8.2),
		Vector3(138, -81, 28),
		Vector3(129.8, -84, 47.8),
		Vector3(110, -85, 56),
		Vector3(50, -85, 56),
		Vector3(-5, -85, 56),
		Vector3(-60, -85, 56),
		Vector3(-79.8, -84, 47.8),
		Vector3(-88, -81, 28),
		Vector3(-79.8, -76.3, 8.2),
		Vector3(-60, -71.5, 0),
		Vector3(-40.2, -66.6, 8.2),
		Vector3(-32, -61.8, 28),
		Vector3(-40.2, -57, 47.8),
		Vector3(-60, -52.2, 56),
		Vector3(-79.8, -47.3, 47.8),
		Vector3(-88, -42.5, 28),
		Vector3(-79.8, -37.7, 8.2),
		Vector3(-60, -32.8, 0),
		Vector3(-40.2, -28, 8.2),
		Vector3(-32, -23.2, 28),
		Vector3(-40.2, -18.4, 47.8),
		Vector3(-60, -13.5, 56),
		Vector3(-79.8, -8.7, 47.8),
		Vector3(-88, -4, 28),
		Vector3(-79.8, -1, 8.2),
		Vector3(-60, 0, 0),
	],
	# Une échelle vers le ciel : une hélice qui monte à 105 m autour d'une
	# tour — chaque tour passe au-dessus du précédent —, un pont dans les
	# nuages, et une large hélice pour redescendre.
	"echelle_celeste": [
		Vector3(0, 0, 0),
		Vector3(60, 0, 0),
		Vector3(110, 0, 0),
		Vector3(131.2, 0.6, 8.8),
		Vector3(140, 2.5, 30),
		Vector3(131.2, 5.7, 51.2),
		Vector3(110, 9.9, 60),
		Vector3(88.8, 14.1, 51.2),
		Vector3(80, 18.4, 30),
		Vector3(88.8, 22.7, 8.8),
		Vector3(110, 26.9, 0),
		Vector3(131.2, 31.2, 8.8),
		Vector3(140, 35.5, 30),
		Vector3(131.2, 39.7, 51.2),
		Vector3(110, 44, 60),
		Vector3(88.8, 48.2, 51.2),
		Vector3(80, 52.5, 30),
		Vector3(88.8, 56.8, 8.8),
		Vector3(110, 61, 0),
		Vector3(131.2, 65.3, 8.8),
		Vector3(140, 69.5, 30),
		Vector3(131.2, 73.8, 51.2),
		Vector3(110, 78.1, 60),
		Vector3(88.8, 82.3, 51.2),
		Vector3(80, 86.6, 30),
		Vector3(88.8, 90.9, 8.8),
		Vector3(110, 95.1, 0),
		Vector3(131.2, 99.3, 8.8),
		Vector3(140, 102.5, 30),
		Vector3(131.2, 104.4, 51.2),
		Vector3(110, 105, 60),
		Vector3(60, 106, 64),
		Vector3(10, 107, 74),
		Vector3(-40, 106, 80),
		Vector3(-90, 105, 80),
		Vector3(-118.3, 103.8, 68.3),
		Vector3(-130, 100, 40),
		Vector3(-118.3, 94.3, 11.7),
		Vector3(-90, 88.3, 0),
		Vector3(-61.7, 82.3, 11.7),
		Vector3(-50, 76.4, 40),
		Vector3(-61.7, 70.4, 68.3),
		Vector3(-90, 64.4, 80),
		Vector3(-118.3, 58.5, 68.3),
		Vector3(-130, 52.5, 40),
		Vector3(-118.3, 46.5, 11.7),
		Vector3(-90, 40.6, 0),
		Vector3(-61.7, 34.6, 11.7),
		Vector3(-50, 28.6, 40),
		Vector3(-61.7, 22.7, 68.3),
		Vector3(-90, 16.7, 80),
		Vector3(-118.3, 10.7, 68.3),
		Vector3(-130, 5, 40),
		Vector3(-118.3, 1.2, 11.7),
		Vector3(-90, 0, 0),
	],
	# Un pic : on monte dans la montagne par un tunnel en spirale — chaque
	# tour passe au-dessus du précédent —, puis on redescend la face sud en
	# lacets, et un dernier tunnel repasse sous les lacets jusqu'au départ.
	"pic_lacets": [
		Vector3(0, 0, 0),
		Vector3(60, 0, 0),
		Vector3(110, 0, 0),
		Vector3(131.2, 0.9, 8.8),
		Vector3(140, 3.8, 30),
		Vector3(131.2, 8.2, 51.2),
		Vector3(110, 12.7, 60),
		Vector3(88.8, 17.3, 51.2),
		Vector3(80, 21.8, 30),
		Vector3(88.8, 26.4, 8.8),
		Vector3(110, 30.9, 0),
		Vector3(131.2, 35.5, 8.8),
		Vector3(140, 40, 30),
		Vector3(131.2, 44.5, 51.2),
		Vector3(110, 49.1, 60),
		Vector3(88.8, 53.6, 51.2),
		Vector3(80, 58.2, 30),
		Vector3(88.8, 62.7, 8.8),
		Vector3(110, 67.3, 0),
		Vector3(131.2, 71.8, 8.8),
		Vector3(140, 76.2, 30),
		Vector3(131.2, 79.1, 51.2),
		Vector3(110, 80, 60),
		Vector3(70, 80.5, 64),
		Vector3(20, 80, 70),
		Vector3(-40, 75, 70),
		Vector3(-85, 70.5, 70),
		Vector3(-110, 68, 70),
		Vector3(-127.7, 66, 77.3),
		Vector3(-135, 64, 95),
		Vector3(-127.7, 62, 112.7),
		Vector3(-110, 60, 120),
		Vector3(-60, 56, 120),
		Vector3(0, 50, 120),
		Vector3(35, 46, 120),
		Vector3(52.7, 44, 127.3),
		Vector3(60, 42, 145),
		Vector3(52.7, 40, 162.7),
		Vector3(35, 38, 170),
		Vector3(-10, 34, 170),
		Vector3(-50, 29, 170),
		Vector3(-78, 24, 162),
		Vector3(-95, 20, 145),
		Vector3(-102, 15, 115),
		Vector3(-102, 10, 82),
		Vector3(-96, 6, 50),
		Vector3(-78, 2, 15),
		Vector3(-40, 0, 0),
	],
	# Des montagnes russes en nœud de trèfle : la piste se croise trois fois,
	# chaque fois sur un pont, vingt mètres au-dessus d'elle-même.
	"grand_huit": [
		Vector3(-81.3, 10.5, -123.2),
		Vector3(-68.1, 11.7, -154.3),
		Vector3(-48.9, 15, -178.1),
		Vector3(-25.5, 20.1, -192.9),
		Vector3(-0, 26, -198),
		Vector3(25.5, 31.9, -192.9),
		Vector3(48.9, 37, -178.1),
		Vector3(68.1, 40.3, -154.3),
		Vector3(81.3, 41.5, -123.2),
		Vector3(87.3, 40.3, -86.5),
		Vector3(85.3, 37, -46.7),
		Vector3(75.1, 31.9, -6),
		Vector3(57.2, 26, 33),
		Vector3(32.4, 20.1, 68.1),
		Vector3(2.2, 15, 97.2),
		Vector3(-31.3, 11.7, 118.9),
		Vector3(-66, 10.5, 132),
		Vector3(-99.6, 11.7, 136.1),
		Vector3(-129.8, 15, 131.4),
		Vector3(-154.3, 20.1, 118.6),
		Vector3(-171.5, 26, 99),
		Vector3(-179.9, 31.9, 74.3),
		Vector3(-178.7, 37, 46.7),
		Vector3(-167.7, 40.3, 18.2),
		Vector3(-147.3, 41.5, -8.8),
		Vector3(-118.6, 40.3, -32.4),
		Vector3(-83.1, 37, -50.6),
		Vector3(-42.8, 31.9, -62.1),
		Vector3(-0, 26, -66),
		Vector3(42.8, 20.1, -62.1),
		Vector3(83.1, 15, -50.6),
		Vector3(118.6, 11.7, -32.4),
		Vector3(147.3, 10.5, -8.8),
		Vector3(167.7, 11.7, 18.2),
		Vector3(178.7, 15, 46.7),
		Vector3(179.9, 20.1, 74.3),
		Vector3(171.5, 26, 99),
		Vector3(154.3, 31.9, 118.6),
		Vector3(129.8, 37, 131.4),
		Vector3(99.6, 40.3, 136.1),
		Vector3(66, 41.5, 132),
		Vector3(31.3, 40.3, 118.9),
		Vector3(-2.2, 37, 97.2),
		Vector3(-32.4, 31.9, 68.1),
		Vector3(-57.2, 26, 33),
		Vector3(-75.1, 20.1, -6),
		Vector3(-85.3, 15, -46.7),
		Vector3(-87.3, 11.7, -86.5),
	],
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if not args.is_empty() else ""
	if not CIRCUITS.has(id):
		printerr("circuits connus : %s" % ", ".join(CIRCUITS.keys()))
		quit(1)
		return
	var sortie := "res://resources/tracks/%s_curve.tres" % id
	if FileAccess.file_exists(sortie) and not "--force" in args:
		printerr("%s existe déjà, et a peut-être été retouché à la souris depuis." % sortie)
		printerr("Relancer avec  --force  pour l'écraser délibérément.")
		quit(1)
		return

	var points: Array = CIRCUITS[id]
	var courbe := Curve3D.new()
	var n := points.size()
	for i in n:
		var precedent: Vector3 = points[(i - 1 + n) % n]
		var suivant: Vector3 = points[(i + 1) % n]
		# Poignées façon Catmull-Rom, comme pour le circuit 1.
		var tangente := (suivant - precedent) / 6.0
		courbe.add_point(points[i], -tangente, tangente)
	courbe.add_point(points[0], -courbe.get_point_out(0), courbe.get_point_out(0))

	var err := ResourceSaver.save(courbe, sortie)
	if err != OK:
		printerr("échec de l'écriture de la courbe : %d" % err)
		quit(1)
		return
	print("%s écrit, longueur %.1f m" % [sortie, courbe.get_baked_length()])
	quit()
