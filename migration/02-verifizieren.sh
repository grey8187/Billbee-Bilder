#!/usr/bin/env bash
# Schritt 2: Pruefen, ob jedes Bild unter seiner neuen Adresse wirklich
# ausgeliefert wird - und zwar unveraendert.
#
# Fuer jede Zeile aus migration/bilder-index.csv wird die neue URL abgerufen
# und die SHA-256-Pruefsumme mit der lokalen Datei verglichen. Nur wenn das
# fuer alle Bilder aufgeht, darf Schritt 3 laufen.
#
# Optionen:
#   --stichprobe N   nur N zufaellige Bilder pruefen (schneller Vorabtest)
#   --parallel N     wieviele Abrufe gleichzeitig (Vorgabe 6)

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# --- Arbeitsmodus fuer einen einzelnen Abruf (wird vom Hauptlauf aufgerufen) --
if [ "${1:-}" = "--eine" ]; then
  IFS=$'\t' read -r name erwartet url <<< "$2"
  ablage="$3"
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  kopf="$(curl -sS -L --max-time 60 -w '%{http_code}|%{content_type}' \
          -o "$tmp" "$url" 2>/dev/null)" || {
    printf '%s\tNICHT ERREICHBAR\t%s\n' "$name" "$url" >> "$ablage"
    printf 'F'; exit 0
  }
  code="${kopf%%|*}"; typ="${kopf#*|}"

  if [ "$code" != "200" ]; then
    printf '%s\tHTTP %s\t%s\n' "$name" "$code" "$url" >> "$ablage"
    printf 'F'; exit 0
  fi
  case "$typ" in
    image/*) : ;;
    *) printf '%s\tfalscher Content-Type: %s\t%s\n' "$name" "$typ" "$url" >> "$ablage"
       printf 'F'; exit 0 ;;
  esac

  tatsaechlich="$(sha256sum < "$tmp" | cut -d' ' -f1)"
  if [ "$tatsaechlich" != "$erwartet" ]; then
    printf '%s\tanderer Inhalt als lokal\t%s\n' "$name" "$url" >> "$ablage"
    printf 'F'; exit 0
  fi

  printf '.'; exit 0
fi

# --- Hauptlauf ---------------------------------------------------------------
STICHPROBE=0
PARALLEL=6
while [ $# -gt 0 ]; do
  case "$1" in
    --stichprobe) STICHPROBE="${2:?Anzahl fehlt}"; shift 2 ;;
    --parallel)   PARALLEL="${2:?Anzahl fehlt}"; shift 2 ;;
    -h|--hilfe|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) abbruch "Unbekannte Option: $1" ;;
  esac
done

werkzeug_pruefen curl "Unter Debian/Ubuntu: apt install curl"
[ -f "$INDEX_DATEI" ] || abbruch "$INDEX_DATEI fehlt. Bitte zuerst migration/00-pruefen.sh ausfuehren."

ARBEIT="$(mktemp -d)"
trap 'rm -rf "$ARBEIT"' EXIT
FEHLERDATEI="$ARBEIT/fehler.tsv"
: > "$FEHLERDATEI"

# Spalten: 1 dateiname, 3 sha256, 6 neue_url
tail -n +2 "$INDEX_DATEI" | awk -F';' 'NF>=6 {print $1 "\t" $3 "\t" $6}' > "$ARBEIT/alle.tsv"
if [ "$STICHPROBE" -gt 0 ]; then
  shuf -n "$STICHPROBE" "$ARBEIT/alle.tsv" > "$ARBEIT/pruefen.tsv"
else
  cp "$ARBEIT/alle.tsv" "$ARBEIT/pruefen.tsv"
fi
GESAMT=$(wc -l < "$ARBEIT/pruefen.tsv")
[ "$GESAMT" -gt 0 ] || abbruch "Nichts zu pruefen."

ueberschrift "Kontrolle"
info "Zu pruefen: $GESAMT Bild(er), $PARALLEL gleichzeitig"
[ "$STICHPROBE" -gt 0 ] && warnung "Nur Stichprobe - vor dem Umstellen bitte einmal ohne --stichprobe laufen lassen."
info "Ein Punkt = in Ordnung, ein F = Problem"
echo

xargs -d '\n' -a "$ARBEIT/pruefen.tsv" -P "$PARALLEL" -I ZEILE \
  "$0" --eine ZEILE "$FEHLERDATEI"
echo; echo

FEHLER=$(wc -l < "$FEHLERDATEI")
GEPRUEFT=$((GESAMT - FEHLER))
if [ "$FEHLER" -eq 0 ]; then
  erfolg "Alle $GESAMT Bilder liegen unveraendert unter der neuen Adresse."
  echo
  if [ "$STICHPROBE" -gt 0 ]; then
    info "Naechster Schritt: derselbe Lauf ohne --stichprobe, danach migration/03-urls-ersetzen.sh"
  else
    info "Naechster Schritt: migration/03-urls-ersetzen.sh <export-datei>"
  fi
  exit 0
fi

fehler "$FEHLER von $GESAMT Bildern sind nicht in Ordnung ($GEPRUEFT ok):"
echo
column -t -s $'\t' "$FEHLERDATEI" 2>/dev/null | sed 's/^/    /' || sed 's/^/    /' "$FEHLERDATEI"
echo
warnung "Nicht umstellen, solange hier etwas rot ist - sonst zeigen Artikel ins Leere."
warnung "Haeufige Ursachen: Upload unvollstaendig, falsches ZIEL_VERZEICHNIS,"
warnung "ZIEL_BASIS_URL zeigt auf einen anderen Ordner als ZIEL_VERZEICHNIS."
exit 1
