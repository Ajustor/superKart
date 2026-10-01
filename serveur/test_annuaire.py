"""Tests de l'annuaire : python3 -m unittest serveur/test_annuaire.py"""

import json
import os
import sys
import threading
import time
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(__file__))
import annuaire as A  # noqa: E402


class FauxProcessus:
    def __init__(self):
        self.fini = False

    def poll(self):
        return 0 if self.fini else None

    def terminate(self):
        self.fini = True


def faux_lanceur(salon):
    return FauxProcessus()


def annuaire_de_test(**reglages):
    defaut = dict(commande="jeu", ports=range(9000, 9003), hote_public="jeu.exemple.org",
                  url_interne="http://127.0.0.1:1", lanceur=faux_lanceur)
    defaut.update(reglages)
    return A.Annuaire(**defaut)


class TestAnnuaire(unittest.TestCase):
    def test_un_salon_a_un_code_lisible_et_un_port_a_lui(self):
        a = annuaire_de_test()
        s1 = a.creer("Mon salon", False)
        s2 = a.creer("Autre", True)
        self.assertEqual(len(s1.code), A.LONGUEUR_CODE)
        self.assertTrue(all(c in A.ALPHABET for c in s1.code))
        self.assertNotEqual(s1.port, s2.port)
        self.assertNotEqual(s1.jeton, s2.jeton)

    def test_plus_de_ports_plus_de_salon(self):
        a = annuaire_de_test()
        for _ in range(3):
            self.assertIsNotNone(a.creer("S", False))
        self.assertIsNone(a.creer("S", False))

    def test_le_nombre_de_salons_est_borne(self):
        a = annuaire_de_test(salons_max=1)
        self.assertIsNotNone(a.creer("S", False))
        self.assertIsNone(a.creer("S", False))

    def test_un_salon_n_est_liste_qu_une_fois_ouvert_et_s_il_est_public(self):
        a = annuaire_de_test()
        public = a.creer("Public", False)
        prive = a.creer("Privé", True)
        self.assertEqual(a.publics(), [], "pas avant d'avoir donné de ses nouvelles")
        a.recevoir_etat(public.code, {"jeton": public.jeton, "joueurs": 2})
        a.recevoir_etat(prive.code, {"jeton": prive.jeton, "joueurs": 1})
        self.assertEqual([s.code for s in a.publics()], [public.code])
        self.assertIs(a.trouver(prive.code.lower()), prive, "un privé se trouve par son code")

    def test_seul_le_salon_peut_donner_son_etat(self):
        a = annuaire_de_test()
        s = a.creer("S", False)
        self.assertFalse(a.recevoir_etat(s.code, {"jeton": "faux", "joueurs": 8}))
        self.assertEqual(s.joueurs, 0)
        self.assertTrue(a.recevoir_etat(s.code, {"jeton": s.jeton, "joueurs": 3, "en_course": True,
                                                 "piste": "Grand Huit", "version": 6}))
        self.assertEqual((s.joueurs, s.en_course, s.piste, s.version), (3, True, "Grand Huit", 6))

    def test_un_salon_qui_ferme_est_retire(self):
        a = annuaire_de_test()
        s = a.creer("S", False)
        a.recevoir_etat(s.code, {"jeton": s.jeton, "ferme": True})
        self.assertIsNone(a.trouver(s.code))
        self.assertTrue(s.processus.fini)

    def test_le_menage_retire_les_salons_arretes_et_relance_les_permanents(self):
        a = annuaire_de_test()
        temporaire = a.creer("Temporaire", False)
        permanent = a.creer("Salon public 1", False, permanent=True)
        temporaire.processus.fini = True
        permanent.processus.fini = True
        a.menage()
        self.assertIsNone(a.trouver(temporaire.code))
        self.assertIsNone(a.trouver(permanent.code))
        noms = [s.nom for s in a.salons.values()]
        self.assertEqual(noms, ["Salon public 1"], "le permanent est relancé")

    def test_un_salon_muet_est_arrete(self):
        a = annuaire_de_test()
        s = a.creer("S", False)
        s.cree -= 100
        s.vu -= 100
        a.menage()
        self.assertIsNone(a.trouver(s.code))
        self.assertTrue(s.processus.fini)

    def test_les_creations_sont_limitees_par_adresse(self):
        a = annuaire_de_test(creations_par_minute=2)
        self.assertTrue(a.autoriser("1.2.3.4"))
        self.assertTrue(a.autoriser("1.2.3.4"))
        self.assertFalse(a.autoriser("1.2.3.4"))
        self.assertTrue(a.autoriser("5.6.7.8"))

    def test_les_noms_sont_nettoyes(self):
        self.assertEqual(A.nettoyer_nom("  Salon\n de\tJo  "), "Salon  de Jo")
        self.assertEqual(A.nettoyer_nom(""), "Salon")
        self.assertEqual(len(A.nettoyer_nom("x" * 100)), A.NOM_MAX)

    def test_un_hote_derriere_cloudflare_est_repere(self):
        # superkart.darthoit.eu proxifié : les salons ne sont pas joignables en UDP.
        self.assertTrue(A.derriere_cloudflare(["172.67.206.4", "104.21.61.46"]))
        self.assertTrue(A.derriere_cloudflare(["2606:4700:3032::6815:3d2e"]))
        self.assertFalse(A.derriere_cloudflare(["51.15.20.30", "2001:db8::1", "pas une ip"]))

    def test_la_plage_de_ports(self):
        self.assertEqual(A.plage_de_ports("8910-8912"), [8910, 8911, 8912])
        self.assertEqual(A.plage_de_ports("8910"), [8910])


class TestHttp(unittest.TestCase):
    """Le vrai serveur HTTP, avec un lanceur qui simule un salon qui s'ouvre."""

    def setUp(self):
        self.annuaire = annuaire_de_test(lanceur=self._lanceur_qui_s_ouvre)
        self.serveur = ThreadingHTTPServer(("127.0.0.1", 0), A.fabriquer_gestionnaire(self.annuaire))
        self.url = "http://127.0.0.1:%d" % self.serveur.server_address[1]
        threading.Thread(target=self.serveur.serve_forever, daemon=True).start()

    def tearDown(self):
        self.serveur.shutdown()
        self.serveur.server_close()

    def _lanceur_qui_s_ouvre(self, salon):
        # Comme le jeu : il se déclare à l'annuaire peu après son lancement.
        def declarer():
            time.sleep(0.2)
            self._requete("POST", "/salons/%s/etat" % salon.code, {"jeton": salon.jeton, "joueurs": 0})
        threading.Thread(target=declarer, daemon=True).start()
        return FauxProcessus()

    def _requete(self, methode, chemin, corps=None):
        donnees = json.dumps(corps).encode() if corps is not None else None
        req = urllib.request.Request(self.url + chemin, data=donnees, method=methode,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=5) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read())

    def test_creer_puis_lister_puis_trouver(self):
        code, salon = self._requete("POST", "/salons", {"nom": "Chez Jo"})
        self.assertEqual(code, 201)
        self.assertEqual(salon["hote"], "jeu.exemple.org")
        self.assertTrue(salon["ouvert"])
        code, liste = self._requete("GET", "/salons")
        self.assertEqual([s["code"] for s in liste["salons"]], [salon["code"]])
        code, trouve = self._requete("GET", "/salons/" + salon["code"].lower())
        self.assertEqual((code, trouve["port"]), (200, salon["port"]))

    def test_un_salon_prive_n_est_pas_liste(self):
        code, salon = self._requete("POST", "/salons", {"nom": "Secret", "prive": True})
        self.assertEqual(code, 201)
        self.assertEqual(self._requete("GET", "/salons")[1]["salons"], [])
        self.assertEqual(self._requete("GET", "/salons/" + salon["code"])[0], 200)

    def test_un_code_inconnu(self):
        self.assertEqual(self._requete("GET", "/salons/ZZZZZ")[0], 404)

    def test_un_etat_sans_le_bon_jeton_est_refuse(self):
        _, salon = self._requete("POST", "/salons", {"nom": "S"})
        code, _ = self._requete("POST", "/salons/%s/etat" % salon["code"], {"jeton": "faux"})
        self.assertEqual(code, 403)

    def test_trop_de_creations(self):
        self.annuaire.creations_par_minute = 1
        self.assertEqual(self._requete("POST", "/salons", {})[0], 201)
        self.assertEqual(self._requete("POST", "/salons", {})[0], 429)


if __name__ == "__main__":
    unittest.main()
