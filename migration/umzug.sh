#!/usr/bin/env bash
# Der ganze Umzug in einem Befehl.
#
#     migration/umzug.sh
#
# Fuehrt nacheinander aus: Bestand pruefen, hochladen, kontrollieren.
# Vor dem Hochladen wird einmal nachgefragt. Danach steht in der Ausgabe,
# was noch zu tun ist.
#
# An Billbee wird nichts geaendert - das passiert erst in Schritt 3
# (migration/03-urls-ersetzen.sh) und nur, wenn ihr das ausdruecklich wollt.
#
# Option --ja ueberspringt die Rueckfrage (fuer unbeaufsichtigte Laeufe).

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

OHNE_RUECKFRAGE=nein
for arg in "$@"; do
  case "$arg" in
    --ja) OHNE_RUECKFRAGE=ja ;;
    -h|--hilfe|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) abbruch "Unbekannte Option: $arg" ;;
  esac
done

# --- Konfiguration vorhanden? ------------------------------------------------
if [ ! -f "$MIGRATION_DIR/config.env" ]; then
  cp "$MIGRATION_DIR/config.env.beispiel" "$MIGRATION_DIR/config.env"
  ueberschrift "Erster Schritt: Zugangsdaten eintragen"
  info "Ich habe die Vorlage angelegt:"
  info ""
  info "    $MIGRATION_DIR/config.env"
  info ""
  info "Bitte darin ausfuellen:"
  info "  HOST, BENUTZER, PASSWORT  - der FTP-Zugang eures Webspace"
  info "  ZIEL_VERZEICHNIS          - der Ordner auf dem Server, z.B. /httpdocs/bilder"
  info "  ZIEL_BASIS_URL            - die Adresse, unter der dieser Ordner im"
  info "                              Browser erreichbar ist"
  info ""
  info "Die Zugangsdaten stehen in der Bestaetigungsmail eures Hosters oder im"
  info "Kundenmenue unter FTP-Zugaenge. Die Datei bleibt auf eurem Rechner und"
  info "wird nicht mit hochgeladen."
  info ""
  info "Danach nochmal starten:  $0"
  exit 0
fi

config_laden

# --- Schritt 0 ---------------------------------------------------------------
"$MIGRATION_DIR/00-pruefen.sh" || abbruch "Bestandspruefung fehlgeschlagen - siehe oben."

# --- Rueckfrage --------------------------------------------------------------
echo
ueberschrift "Jetzt wird hochgeladen"
info "Ziel:   $BENUTZER@$HOST:$ZIEL_VERZEICHNIS"
info "Danach: ${ZIEL_BASIS_URL}<dateiname>"
info ""
info "An euren Artikeln in Billbee aendert sich dabei nichts. Die Bilder"
info "werden nur zusaetzlich auf euren Server gelegt - umgestellt wird"
info "spaeter und nur auf euren ausdruecklichen Befehl hin."
echo
if [ "$OHNE_RUECKFRAGE" = "nein" ]; then
  if [ ! -t 0 ]; then
    abbruch "Keine Eingabe moeglich. Fuer einen unbeaufsichtigten Lauf: $0 --ja"
  fi
  printf 'Hochladen starten? [j/N] '
  read -r antwort
  case "$antwort" in
    j|J|ja|Ja|JA|y|Y|yes) : ;;
    *) info "Abgebrochen. Es wurde nichts uebertragen."; exit 0 ;;
  esac
fi

# --- Schritt 1 ---------------------------------------------------------------
"$MIGRATION_DIR/01-hochladen.sh" --los || abbruch "Upload fehlgeschlagen - siehe oben."

# --- Schritt 2 ---------------------------------------------------------------
echo
if "$MIGRATION_DIR/02-verifizieren.sh"; then
  echo
  ueberschrift "Geschafft"
  erfolg "Alle Bilder liegen auf eurem Webspace und sind unveraendert abrufbar."
  info ""
  info "Was jetzt noch fehlt: die Bild-Adressen in Billbee umstellen. Dafuer"
  info "die Artikel aus Billbee exportieren und einmal hier durchschicken:"
  info ""
  info "    migration/03-urls-ersetzen.sh export.csv          (nur anzeigen)"
  info "    migration/03-urls-ersetzen.sh --los export.csv    (wirklich aendern)"
  info ""
  info "Bis dahin zeigen die Artikel weiter auf GitHub und alles laeuft wie"
  info "bisher. Es eilt also nicht."
  exit 0
fi

echo
fehler "Der Upload ist durch, aber die Kontrolle hat Probleme gefunden (siehe oben)."
info ""
info "Am haeufigsten passt ZIEL_BASIS_URL nicht zu ZIEL_VERZEICHNIS - der"
info "Ordner auf dem Server und die Adresse im Browser muessen derselbe Ort"
info "sein. Zum Pruefen im Browser aufrufen:"
info ""
info "    ${ZIEL_BASIS_URL}$(dateiliste | head -1)"
info ""
info "Kommt dort ein Bild? Dann stimmt die Adresse. Kommt ein Fehler, muss"
info "ZIEL_BASIS_URL in migration/config.env angepasst werden."
info ""
info "In Billbee wurde nichts geaendert - es ist nichts kaputt."
exit 1
