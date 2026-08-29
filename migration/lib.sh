#!/usr/bin/env bash
# Gemeinsame Helfer fuer die Migrationsskripte. Wird von den anderen
# Skripten eingebunden, nicht direkt aufgerufen.

set -euo pipefail

MIGRATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$MIGRATION_DIR/.." && pwd)"
# Laesst sich per Umgebungsvariable ueberschreiben - der Selbsttest
# arbeitet damit auf einem eigenen Index statt auf dem echten Bestand.
INDEX_DATEI="${INDEX_DATEI:-$MIGRATION_DIR/bilder-index.csv}"

# Alte Adresse, unter der die Bilder bisher ausgeliefert wurden
GITHUB_BENUTZER="grey8187"
GITHUB_REPO="Billbee-Bilder"
ALTE_BASIS_URL="https://raw.githubusercontent.com/$GITHUB_BENUTZER/$GITHUB_REPO/main/"

if [ -t 1 ]; then
  ROT=$'\033[31m'; GRUEN=$'\033[32m'; GELB=$'\033[33m'; FETT=$'\033[1m'; AUS=$'\033[0m'
else
  ROT=""; GRUEN=""; GELB=""; FETT=""; AUS=""
fi

info()    { printf '%s\n' "$*"; }
erfolg()  { printf '%s%s%s\n' "$GRUEN" "$*" "$AUS"; }
warnung() { printf '%s%s%s\n' "$GELB" "$*" "$AUS" >&2; }
fehler()  { printf '%s%s%s\n' "$ROT" "$*" "$AUS" >&2; }
abbruch() { fehler "$*"; exit 1; }

ueberschrift() {
  printf '\n%s%s%s\n' "$FETT" "$*" "$AUS"
  printf '%s\n' "$(printf '%*s' "${#1}" '' | tr ' ' '-')"
}

# Liest migration/config.env ein. Argument "optional" laesst das Skript auch
# ohne Konfiguration weiterlaufen (z.B. fuer die reine Vorpruefung).
config_laden() {
  local modus="${1:-pflicht}"
  local datei="$MIGRATION_DIR/config.env"

  if [ -f "$datei" ]; then
    # shellcheck disable=SC1090
    set -a; . "$datei"; set +a
  elif [ -n "${ZIEL_BASIS_URL:-}" ]; then
    # Zieladresse kommt aus der Umgebung - so ruft der Selbsttest die
    # Skripte auf, ohne dass eine Konfiguration angelegt sein muss.
    :
  elif [ "$modus" = "optional" ]; then
    return 1
  else
    abbruch "Keine Konfiguration gefunden.

  cp migration/config.env.beispiel migration/config.env

und die Datei ausfuellen (Zieladresse und Zugangsdaten)."
  fi

  [ -n "${ZIEL_BASIS_URL:-}" ] || abbruch "ZIEL_BASIS_URL fehlt in migration/config.env"
  case "$ZIEL_BASIS_URL" in
    */) : ;;
    *)  ZIEL_BASIS_URL="$ZIEL_BASIS_URL/" ;;
  esac
  return 0
}

# Alle Bilddateien im Repo-Wurzelverzeichnis, alphabetisch, ein Name pro Zeile.
# Bewusst nur die oberste Ebene: das Repo ist flach, migration/ und .git
# gehoeren nicht dazu.
dateiliste() {
  find "$REPO_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
    -printf '%f\n' | LC_ALL=C sort
}

werkzeug_pruefen() {
  command -v "$1" >/dev/null 2>&1 || abbruch "Das Programm '$1' fehlt. $2"
}
