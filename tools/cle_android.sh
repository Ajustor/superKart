#!/bin/sh
# Crée la clé de signature Android au nom du développeur, une fois pour toutes.
#
#   sh tools/cle_android.sh
#
# keytool demande un mot de passe (6 caractères au moins). Le script écrit
# superkart-alexandre.keystore (à garder précieusement, hors du dépôt) et
# superkart-alexandre.keystore.base64, à coller dans le secret GitHub
# ANDROID_NOUVELLE_CLE_BASE64. Voir docs/pipeline-de-build.md.
set -eu

NOM="Alexandre Gambier"
ALIAS="superkart-alexandre"
FICHIER="superkart-alexandre.keystore"

if [ -e "$FICHIER" ]; then
    echo "$FICHIER existe déjà : on ne l'écrase pas." >&2
    exit 1
fi

keytool -genkeypair -v -keystore "$FICHIER" -alias "$ALIAS" \
    -keyalg RSA -keysize 4096 -validity 10000 \
    -dname "CN=$NOM, O=$NOM, C=FR"

base64 -w0 "$FICHIER" > "$FICHIER.base64" 2>/dev/null || base64 -i "$FICHIER" | tr -d '\n' > "$FICHIER.base64"

echo
echo "Secrets GitHub à ajouter (Settings → Secrets and variables → Actions) :"
echo "  ANDROID_NOUVELLE_CLE_BASE64   = le contenu de $FICHIER.base64"
echo "  ANDROID_NOUVELLE_CLE_USER     = $ALIAS"
echo "  ANDROID_NOUVELLE_CLE_PASSWORD = le mot de passe choisi"
echo "Puis supprimer $FICHIER.base64, et garder $FICHIER en lieu sûr."
