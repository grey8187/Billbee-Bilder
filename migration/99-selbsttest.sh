#!/usr/bin/env bash
# Selbsttest fuer 03-urls-ersetzen.sh.
#
# Legt eine kleine Beispieldatei mit allen Schreibweisen an, die in Exporten
# vorkommen koennen, laesst die Ersetzung darueber laufen und vergleicht das
# Ergebnis mit dem, was herauskommen muss. Aendert nichts am echten Bestand.
#
# Vor dem ersten Einsatz an einer echten Export-Datei einmal ausfuehren.

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

config_laden optional || ZIEL_BASIS_URL="https://www.stegplattenversand.de/bilder/"
B="$ZIEL_BASIS_URL"

ARBEIT="$(mktemp -d)"
trap 'rm -rf "$ARBEIT"' EXIT

# Ein Index mit genau den Namen, die der Test verwendet - unabhaengig vom
# echten Bestand, damit der Test ueberall dasselbe Ergebnis liefert.
TEST_INDEX="$ARBEIT/bilder-index.csv"
{
  echo 'dateiname;bytes;sha256;dublettengruppe;alte_url;neue_url'
  for n in 10169_01.jpg 10251_01.jpg 22781_01.jpg 22781_02.jpg 2346_01.jpg 2346_03.png; do
    echo "$n;0;0;$n;${ALTE_BASIS_URL}${n};${B}${n}"
  done
} > "$TEST_INDEX"

cat > "$ARBEIT/probe.txt" <<EOF
csv_einfach;${ALTE_BASIS_URL}10169_01.jpg;ende
csv_refs;https://raw.githubusercontent.com/grey8187/Billbee-Bilder/refs/heads/main/10251_01.jpg;ende
csv_commit;https://raw.githubusercontent.com/grey8187/Billbee-Bilder/b8ec2b3b8a7cf9159b19a5130a6ba8dc577126c7/22781_01.jpg;ende
csv_raw;https://github.com/grey8187/Billbee-Bilder/raw/main/22781_02.jpg;ende
csv_blob;https://github.com/grey8187/Billbee-Bilder/blob/main/2346_03.png?raw=true;ende
csv_jsdelivr;https://cdn.jsdelivr.net/gh/grey8187/Billbee-Bilder@main/2346_01.jpg;ende
xml:<bild url="${ALTE_BASIS_URL}10169_01.jpg" pos="1"/>
json:{"bild": "${ALTE_BASIS_URL}10251_01.jpg", "pos": 1}
fremd_shop;https://cdn.shopify.com/s/files/1/foto.jpg;ende
fremd_repo;https://raw.githubusercontent.com/andereruser/anderesrepo/main/10169_01.jpg;ende
unbekannt;${ALTE_BASIS_URL}gibtsgarnicht_01.jpg;ende
zeilenende;${ALTE_BASIS_URL}22781_01.jpg
EOF

cat > "$ARBEIT/erwartet.txt" <<EOF
csv_einfach;${B}10169_01.jpg;ende
csv_refs;${B}10251_01.jpg;ende
csv_commit;${B}22781_01.jpg;ende
csv_raw;${B}22781_02.jpg;ende
csv_blob;${B}2346_03.png;ende
csv_jsdelivr;${B}2346_01.jpg;ende
xml:<bild url="${B}10169_01.jpg" pos="1"/>
json:{"bild": "${B}10251_01.jpg", "pos": 1}
fremd_shop;https://cdn.shopify.com/s/files/1/foto.jpg;ende
fremd_repo;https://raw.githubusercontent.com/andereruser/anderesrepo/main/10169_01.jpg;ende
unbekannt;${B}gibtsgarnicht_01.jpg;ende
zeilenende;${B}22781_01.jpg
EOF

ueberschrift "Selbsttest"
AUSGABE="$(INDEX_DATEI="$TEST_INDEX" ZIEL_BASIS_URL="$B" \
  "$MIGRATION_DIR/03-urls-ersetzen.sh" --los "$ARBEIT/probe.txt" 2>&1)" || true

if diff -u "$ARBEIT/erwartet.txt" "$ARBEIT/probe.txt" > "$ARBEIT/abweichung.txt"; then
  erfolg "Ersetzung arbeitet korrekt:"
  info "  - alle sechs Schreibweisen einer GitHub-Adresse werden erkannt"
  info "  - Feldtrenner und Anfuehrungszeichen bleiben heil (CSV, XML, JSON)"
  info "  - fremde Bildquellen bleiben unveraendert"
  if printf '%s' "$AUSGABE" | grep -q 'gibtsgarnicht_01.jpg'; then
    info "  - Verweise auf fehlende Bilder werden gemeldet"
  else
    fehler "  - ABER: fehlendes Bild wurde nicht gemeldet"
    exit 1
  fi
  exit 0
fi

fehler "Ergebnis weicht ab (- erwartet, + tatsaechlich):"
sed 's/^/    /' "$ARBEIT/abweichung.txt"
exit 1
