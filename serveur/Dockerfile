# Le serveur du mode en ligne : l'annuaire et le jeu en serveur dédié, dans
# une seule image construite depuis le dépôt (contexte : la racine du dépôt).
#
#   docker build -f serveur/Dockerfile -t superkart-serveur .
#
# Le jeu tourne depuis ses sources avec Godot, sans export : l'image suit
# exactement le commit déployé, sans attendre une Release.
FROM python:3.12-slim

# Doit rester aligné sur config/features de project.godot et la CI.
ARG GODOT_VERSION=4.7-stable

RUN python3 -c "import io, os, urllib.request, zipfile; \
v = os.environ['GODOT_VERSION']; \
u = 'https://github.com/godotengine/godot-builds/releases/download/%s/Godot_v%s_linux.x86_64.zip' % (v, v); \
z = zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(u, timeout=300).read())); \
open('/usr/local/bin/godot', 'wb').write(z.read(z.namelist()[0]))" \
    && chmod +x /usr/local/bin/godot \
    && useradd --system --create-home superkart

WORKDIR /opt/superkart
COPY --chown=superkart . jeu/
RUN mv jeu/serveur/annuaire.py . && rm -rf jeu/serveur
USER superkart
# Les ressources importées (jeu/.godot) font partie de l'image : un salon
# démarre en quelques secondes.
RUN godot --headless --path jeu --import > /dev/null 2>&1 || true; \
    test -d jeu/.godot/imported

ENV ANNUAIRE_PORT=8900 \
    PORTS_SALONS=8910-8949 \
    JEU_COMMANDE="godot --headless --path /opt/superkart/jeu" \
    PYTHONUNBUFFERED=1

EXPOSE 8900/tcp 8910-8949/udp
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
    CMD python3 -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/sante' % os.environ['ANNUAIRE_PORT'], timeout=3)"
CMD ["python3", "annuaire.py"]
