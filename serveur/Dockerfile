# L'annuaire du mode en ligne et le jeu en serveur, dans une seule image.
#
# Se construit depuis le dossier SuperKart-serveur de la Release
# (SuperKart-serveur-linux.zip), qui contient ce Dockerfile, l'annuaire et le
# jeu exporté pour Linux. Voir README.md.
FROM python:3.12-slim

WORKDIR /opt/superkart
COPY SuperKart-serveur.x86_64 SuperKart-serveur.pck annuaire.py ./
# Le jeu écrit ses réglages dans user:// : il lui faut un dossier personnel.
RUN chmod +x SuperKart-serveur.x86_64 \
    && useradd --system --create-home superkart
USER superkart

ENV ANNUAIRE_PORT=8900 \
    PORTS_SALONS=8910-8949 \
    JEU_COMMANDE="/opt/superkart/SuperKart-serveur.x86_64 --headless" \
    PYTHONUNBUFFERED=1

EXPOSE 8900/tcp 8910-8949/udp
HEALTHCHECK --interval=30s --timeout=5s \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8900/sante', timeout=3)"
CMD ["python3", "annuaire.py"]
