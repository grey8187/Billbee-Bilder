#!/usr/bin/env bash
# Schritt 0: Bestand pruefen und migration/bilder-index.csv erzeugen.
#
# Aendert nichts am Server und nichts an den Bildern - reine Analyse.
# Erzeugt die Index-Datei, auf der die spaeteren Schritte aufbauen.

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

werkzeug_pruefen sha256sum "Unter Debian/Ubuntu steckt es in 'coreutils'."
werkzeug_pruefen file "Unter Debian/Ubuntu: apt install file"

if ! config_laden optional; then
  ZIEL_BASIS_URL="https://www.stegplattenversand.de/bilder/"
  warnung "Keine migration/config.env vorhanden - Spalte 'neue_url' nutzt die"
  warnung "Vorgabe $ZIEL_BASIS_URL. Fuer den echten Lauf bitte Konfiguration anlegen."
fi

cd "$REPO_DIR"
ARBEIT="$(mktemp -d)"
trap 'rm -rf "$ARBEIT"' EXIT

dateiliste > "$ARBEIT/dateien.txt"
ANZAHL=$(wc -l < "$ARBEIT/dateien.txt")
[ "$ANZAHL" -gt 0 ] || abbruch "Keine Bilddateien im Repo-Wurzelverzeichnis gefunden."

ueberschrift "Bestand"
BYTES=$(xargs -d '\n' -a "$ARBEIT/dateien.txt" stat -c %s | awk '{s+=$1} END {print s}')
info "Dateien:      $ANZAHL"
info "Gesamtgroesse: $(numfmt --to=iec --suffix=B "$BYTES" 2>/dev/null || echo "$BYTES Bytes")"
info "Zieladresse:  $ZIEL_BASIS_URL"

ueberschrift "Dateinamen"
# Ein Webserver liefert nur aus, was sich sauber in eine URL schreiben laesst.
if PROBLEM=$(LC_ALL=C grep -nP '[^A-Za-z0-9._-]' "$ARBEIT/dateien.txt"); then
  fehler "Namen mit Zeichen, die in einer URL Aerger machen (Leerzeichen, Umlaute, ...):"
  printf '%s\n' "$PROBLEM" | sed 's/^/    /'
  NAMEN_OK=nein
else
  erfolg "Alle Namen bestehen nur aus A-Z a-z 0-9 . _ - "
  NAMEN_OK=ja
fi

# Auf einem Linux-Server sind Gross- und Kleinschreibung verschieden, auf
# manchen Systemen nicht. Namen, die sich nur darin unterscheiden, koennen
# sich beim Upload gegenseitig ueberschreiben.
if KOLLISION=$(tr 'A-Z' 'a-z' < "$ARBEIT/dateien.txt" | LC_ALL=C sort | uniq -d) && [ -n "$KOLLISION" ]; then
  fehler "Namen, die sich nur in der Gross-/Kleinschreibung unterscheiden:"
  printf '%s\n' "$KOLLISION" | sed 's/^/    /'
  NAMEN_OK=nein
else
  erfolg "Keine Namenskollisionen bei Gross-/Kleinschreibung"
fi

ueberschrift "Dateitypen"
: > "$ARBEIT/typfehler.txt"
while IFS= read -r f; do
  typ=$(file -b --mime-type -- "$f")
  endung=$(printf '%s' "${f##*.}" | tr 'A-Z' 'a-z')
  case "$typ|$endung" in
    'image/jpeg|jpg'|'image/jpeg|jpeg'|'image/png|png') : ;;
    *) printf '%s (Endung .%s, tatsaechlich %s)\n' "$f" "$endung" "$typ" >> "$ARBEIT/typfehler.txt" ;;
  esac
done < "$ARBEIT/dateien.txt"
if [ -s "$ARBEIT/typfehler.txt" ]; then
  # Falscher Typ heisst: der Server schickt den falschen Content-Type mit,
  # und manche Marktplaetze weisen das Bild dann zurueck.
  fehler "Endung passt nicht zum Inhalt:"
  sed 's/^/    /' "$ARBEIT/typfehler.txt"
else
  erfolg "Bei allen $ANZAHL Dateien passt die Endung zum tatsaechlichen Bildformat"
fi

ueberschrift "Dubletten"
xargs -d '\n' -a "$ARBEIT/dateien.txt" sha256sum -- \
  | sed 's/^\([0-9a-f]*\)  /\1\t/' | LC_ALL=C sort > "$ARBEIT/summen.tsv"
EINDEUTIG=$(cut -f1 "$ARBEIT/summen.tsv" | LC_ALL=C uniq | wc -l)
IN_GRUPPEN=$(cut -f1 "$ARBEIT/summen.tsv" | LC_ALL=C uniq -d \
  | grep -Ff - "$ARBEIT/summen.tsv" 2>/dev/null | wc -l || echo 0)
info "Verschiedene Bilder: $EINDEUTIG von $ANZAHL Dateien"
if [ "$IN_GRUPPEN" -gt 0 ]; then
  info "Davon $IN_GRUPPEN Dateien mit identischem Inhalt unter mehreren Namen."
  info "Das ist gewollt und bleibt so: die Namen werden von verschiedenen Stellen"
  info "verlinkt (Artikelnummer aus Billbee, Slug aus dem Shop). Wer hier"
  info "zusammenlegt, zerschiesst die jeweils andere Seite."
fi

ueberschrift "Index"
# Dublettengruppe = der alphabetisch erste Dateiname mit demselben Inhalt.
awk -F'\t' '
  NR==FNR { if (!(($1) in erster)) erster[$1] = $2; next }
  { print $2 "\t" $1 "\t" erster[$1] }
' "$ARBEIT/summen.tsv" "$ARBEIT/summen.tsv" | LC_ALL=C sort > "$ARBEIT/index.tsv"

{
  printf 'dateiname;bytes;sha256;dublettengruppe;alte_url;neue_url\n'
  while IFS=$'\t' read -r name summe gruppe; do
    printf '%s;%s;%s;%s;%s%s;%s%s\n' \
      "$name" "$(stat -c %s -- "$name")" "$summe" "$gruppe" \
      "$ALTE_BASIS_URL" "$name" "$ZIEL_BASIS_URL" "$name"
  done < "$ARBEIT/index.tsv"
} > "$INDEX_DATEI"

erfolg "$INDEX_DATEI geschrieben ($ANZAHL Zeilen, Trennzeichen Semikolon)"

if [ "$NAMEN_OK" = "nein" ] || [ -s "$ARBEIT/typfehler.txt" ]; then
  echo
  abbruch "Bitte erst die oben rot markierten Punkte klaeren, dann Schritt 1."
fi
echo
erfolg "Bestand ist sauber. Weiter mit: migration/01-hochladen.sh"
