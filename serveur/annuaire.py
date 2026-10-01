"""L'annuaire du mode en ligne de SuperKart.

Un petit service HTTP (bibliothèque standard seulement) qui tient la liste des
salons et en lance à la demande. Chaque salon est un processus du jeu lancé en
serveur dédié (voir scripts/net/serveur_dedie.gd), sur son propre port UDP ;
il donne son état à l'annuaire toutes les quelques secondes, et s'arrête tout
seul quand plus personne ne l'occupe.

    GET  /sante                   « ok »
    GET  /salons                  les salons publics
    POST /salons                  crée un salon : {"nom": "...", "prive": false}
    GET  /salons/<code>           un salon, public ou privé, par son code
    POST /salons/<code>/etat      l'état d'un salon, envoyé par le salon lui-même

Les joueurs se connectent ensuite au salon en UDP, sur `hote:port`.

Réglages (variables d'environnement) :

    ANNUAIRE_PORT       port HTTP (8900)
    JEU_COMMANDE        commande qui lance le jeu en serveur
                        (« /opt/superkart/SuperKart-serveur.x86_64 --headless »)
    PORTS_SALONS        plage des ports UDP des salons (« 8910-8949 »)
    HOTE_PUBLIC         l'adresse que les joueurs utilisent pour joindre les
                        salons (le nom de domaine du serveur)
    SALONS_MAX          nombre de salons en même temps (20)
    SALONS_PERMANENTS   salons publics toujours ouverts (1)
    CREATIONS_PAR_MINUTE  créations par adresse IP et par minute (4)
"""

import json
import os
import re
import secrets
import shlex
import signal
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # sans I, O, 0, 1 : on les confond
LONGUEUR_CODE = 5
# Sans nouvelles d'un salon depuis ce temps : il est arrêté et retiré.
SILENCE_MAX = 30.0
# Le temps laissé à un salon pour s'ouvrir avant de répondre au joueur.
OUVERTURE_MAX = 20.0
NOM_MAX = 32


def nettoyer_nom(nom, defaut="Salon"):
    nom = re.sub(r"[\x00-\x1f\x7f]", " ", str(nom or "")).strip()
    return nom[:NOM_MAX] or defaut


def plage_de_ports(texte):
    debut, _, fin = str(texte).partition("-")
    debut = int(debut)
    fin = int(fin or debut)
    return list(range(debut, fin + 1))


class Salon:
    def __init__(self, code, nom, port, prive, permanent=False):
        self.code = code
        self.nom = nom
        self.port = port
        self.prive = prive
        self.permanent = permanent
        self.jeton = secrets.token_hex(16)
        self.processus = None
        self.joueurs = 0
        self.places = 8
        self.en_course = False
        self.piste = ""
        self.version = 0
        self.cree = time.monotonic()
        self.vu = time.monotonic()
        self.ouvert = threading.Event()

    def public(self, hote):
        return {
            "code": self.code, "nom": self.nom, "hote": hote, "port": self.port,
            "prive": self.prive, "joueurs": self.joueurs, "places": self.places,
            "en_course": self.en_course, "piste": self.piste, "version": self.version,
            "ouvert": self.ouvert.is_set(),
        }


class Annuaire:
    """L'état de l'annuaire, sans rien d'HTTP : ce qui se teste."""

    def __init__(self, commande, ports, hote_public, url_interne, salons_max=20,
                 creations_par_minute=4, lanceur=None):
        self.commande = commande
        self.ports = list(ports)
        self.hote_public = hote_public
        self.url_interne = url_interne
        self.salons_max = salons_max
        self.creations_par_minute = creations_par_minute
        self.salons = {}
        self.verrou = threading.Lock()
        self._creations = {}
        self._lanceur = lanceur or self._lancer_processus

    # --- Créer, trouver, retirer ----------------------------------------------------

    def _nouveau_code(self):
        while True:
            code = "".join(secrets.choice(ALPHABET) for _ in range(LONGUEUR_CODE))
            if code not in self.salons:
                return code

    def _port_libre(self):
        pris = {s.port for s in self.salons.values()}
        for port in self.ports:
            if port not in pris:
                return port
        return None

    def autoriser(self, ip):
        """Pas plus de `creations_par_minute` salons par adresse et par minute."""
        maintenant = time.monotonic()
        recentes = [t for t in self._creations.get(ip, []) if maintenant - t < 60.0]
        if len(recentes) >= self.creations_par_minute:
            self._creations[ip] = recentes
            return False
        recentes.append(maintenant)
        self._creations[ip] = recentes
        return True

    def creer(self, nom, prive, permanent=False):
        """Crée et lance un salon ; None si l'annuaire est plein."""
        with self.verrou:
            if len(self.salons) >= self.salons_max:
                return None
            port = self._port_libre()
            if port is None:
                return None
            salon = Salon(self._nouveau_code(), nettoyer_nom(nom), port, bool(prive), permanent)
            self.salons[salon.code] = salon
        try:
            salon.processus = self._lanceur(salon)
        except OSError as erreur:
            print("annuaire : lancement impossible : %s" % erreur, file=sys.stderr)
            with self.verrou:
                self.salons.pop(salon.code, None)
            return None
        print("annuaire : salon %s « %s » sur le port %d%s" % (
            salon.code, salon.nom, salon.port, " (privé)" if salon.prive else ""))
        return salon

    def _lancer_processus(self, salon):
        args = shlex.split(self.commande) + [
            "--", "--serveur", "--port", str(salon.port), "--nom", salon.nom,
            "--code", salon.code, "--annuaire", self.url_interne, "--jeton", salon.jeton]
        if salon.prive:
            args.append("--prive")
        if salon.permanent:
            args.append("--permanent")
        return subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def trouver(self, code):
        return self.salons.get(str(code).upper())

    def publics(self):
        with self.verrou:
            return [s for s in self.salons.values() if not s.prive and s.ouvert.is_set()]

    def retirer(self, code):
        with self.verrou:
            salon = self.salons.pop(code, None)
        if salon is not None and salon.processus is not None and salon.processus.poll() is None:
            salon.processus.terminate()
        return salon

    # --- Ce que disent les salons ---------------------------------------------------

    def recevoir_etat(self, code, etat):
        salon = self.trouver(code)
        if salon is None or not secrets.compare_digest(str(etat.get("jeton", "")), salon.jeton):
            return False
        if etat.get("ferme"):
            self.retirer(salon.code)
            return True
        salon.joueurs = int(etat.get("joueurs", 0))
        salon.places = int(etat.get("places", 8))
        salon.en_course = bool(etat.get("en_course", False))
        salon.piste = str(etat.get("piste", ""))[:64]
        salon.version = int(etat.get("version", 0))
        salon.vu = time.monotonic()
        salon.ouvert.set()
        return True

    def menage(self):
        """Retire les salons arrêtés ou muets ; relance les permanents."""
        maintenant = time.monotonic()
        a_relancer = []
        for code, salon in list(self.salons.items()):
            arrete = salon.processus is not None and salon.processus.poll() is not None
            muet = maintenant - salon.vu > SILENCE_MAX and maintenant - salon.cree > OUVERTURE_MAX
            if arrete or muet:
                self.retirer(code)
                if salon.permanent:
                    a_relancer.append(salon.nom)
        for nom in a_relancer:
            self.creer(nom, False, permanent=True)


def fabriquer_gestionnaire(annuaire):
    class Gestionnaire(BaseHTTPRequestHandler):
        server_version = "SuperKartAnnuaire/1"

        def log_message(self, format, *args):
            pass

        def _repondre(self, code, corps):
            donnees = json.dumps(corps, ensure_ascii=False).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(donnees)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(donnees)

        def _corps(self):
            longueur = min(int(self.headers.get("Content-Length") or 0), 4096)
            if longueur <= 0:
                return {}
            try:
                lu = json.loads(self.rfile.read(longueur).decode("utf-8"))
            except (ValueError, UnicodeDecodeError):
                return None
            return lu if isinstance(lu, dict) else None

        def _ip(self):
            # Derrière un proxy (Traefik pour Dokploy, ou Caddy), l'adresse du
            # joueur est la dernière de X-Forwarded-For : celle qu'a ajoutée le
            # proxy. Les précédentes viennent du client, qui peut les inventer.
            transmise = self.headers.get("X-Forwarded-For", "")
            return transmise.split(",")[-1].strip() or self.client_address[0]

        def do_GET(self):
            chemin = self.path.split("?")[0].rstrip("/")
            if chemin == "/sante":
                return self._repondre(200, {"ok": True})
            if chemin == "/salons":
                salons = [s.public(annuaire.hote_public) for s in annuaire.publics()]
                return self._repondre(200, {"salons": salons})
            m = re.fullmatch(r"/salons/([A-Za-z0-9]{%d})" % LONGUEUR_CODE, chemin)
            if m:
                salon = annuaire.trouver(m.group(1))
                if salon is None:
                    return self._repondre(404, {"erreur": "Aucun salon avec ce code."})
                return self._repondre(200, salon.public(annuaire.hote_public))
            self._repondre(404, {"erreur": "Inconnu."})

        def do_POST(self):
            chemin = self.path.split("?")[0].rstrip("/")
            corps = self._corps()
            if corps is None:
                return self._repondre(400, {"erreur": "JSON attendu."})
            m = re.fullmatch(r"/salons/([A-Za-z0-9]{%d})/etat" % LONGUEUR_CODE, chemin)
            if m:
                ok = annuaire.recevoir_etat(m.group(1), corps)
                return self._repondre(200 if ok else 403, {"ok": ok})
            if chemin == "/salons":
                if not annuaire.autoriser(self._ip()):
                    return self._repondre(429, {"erreur": "Trop de salons créés : réessaie dans une minute."})
                salon = annuaire.creer(corps.get("nom", "Salon"), bool(corps.get("prive", False)))
                if salon is None:
                    return self._repondre(503, {"erreur": "Tous les salons sont occupés : réessaie plus tard."})
                if not salon.ouvert.wait(OUVERTURE_MAX):
                    annuaire.retirer(salon.code)
                    return self._repondre(503, {"erreur": "Le salon n'a pas pu s'ouvrir."})
                return self._repondre(201, salon.public(annuaire.hote_public))
            self._repondre(404, {"erreur": "Inconnu."})

    return Gestionnaire


def main():
    port = int(os.environ.get("ANNUAIRE_PORT", "8900"))
    annuaire = Annuaire(
        commande=os.environ.get("JEU_COMMANDE", "/opt/superkart/SuperKart-serveur.x86_64 --headless"),
        ports=plage_de_ports(os.environ.get("PORTS_SALONS", "8910-8949")),
        hote_public=os.environ.get("HOTE_PUBLIC", "127.0.0.1"),
        url_interne="http://127.0.0.1:%d" % port,
        salons_max=int(os.environ.get("SALONS_MAX", "20")),
        creations_par_minute=int(os.environ.get("CREATIONS_PAR_MINUTE", "4")),
    )
    serveur = ThreadingHTTPServer(("0.0.0.0", port), fabriquer_gestionnaire(annuaire))
    serveur.daemon_threads = True
    threading.Thread(target=serveur.serve_forever, daemon=True).start()
    print("annuaire : à l'écoute sur le port %d, salons joignables sur %s" % (port, annuaire.hote_public))
    # docker stop envoie SIGTERM : on arrête proprement les salons.
    def arreter(*_):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, arreter)
    for i in range(int(os.environ.get("SALONS_PERMANENTS", "1"))):
        annuaire.creer("Salon public %d" % (i + 1), False, permanent=True)
    try:
        while True:
            time.sleep(5.0)
            annuaire.menage()
    except KeyboardInterrupt:
        pass
    finally:
        for code in list(annuaire.salons):
            annuaire.retirer(code)
        serveur.shutdown()


if __name__ == "__main__":
    main()
