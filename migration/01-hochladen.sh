#!/usr/bin/env bash
# Schritt 1: Bilder auf den eigenen Webspace hochladen.
#
# Standardmaessig ein Trockenlauf - es wird nur angezeigt, was passieren
# wuerde. Erst "migration/01-hochladen.sh --los" laedt wirklich hoch.
#
# Der Upload aendert nichts an Billbee und nichts am GitHub-Repo. Solange
# Schritt 3 nicht gelaufen ist, zeigen alle Artikel weiter auf GitHub - der
# Upload ist also gefahrlos wiederholbar.

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ECHT=nein
for arg in "$@"; do
  case "$arg" in
    --los) ECHT=ja ;;
    -h|--hilfe|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) abbruch "Unbekannte Option: $arg (erlaubt ist nur --los)" ;;
  esac
done

config_laden
[ -n "${HOST:-}" ]             || abbruch "HOST fehlt in migration/config.env"
[ -n "${BENUTZER:-}" ]         || abbruch "BENUTZER fehlt in migration/config.env"
[ -n "${ZIEL_VERZEICHNIS:-}" ] || abbruch "ZIEL_VERZEICHNIS fehlt in migration/config.env"
case "${PROTOKOLL:-}" in
  ftps|ftp|sftp|ssh) : ;;
  *) abbruch "PROTOKOLL muss ftps, ftp, sftp oder ssh sein (ist: ${PROTOKOLL:-<leer>})" ;;
esac

cd "$REPO_DIR"

# Nur die Bilder hochladen - nicht .git, nicht migration/, nicht die Doku.
# Dafuer ein Staging-Verzeichnis aus harten Links: kostet keinen zusaetzlichen
# Plattenplatz, aber das Hochladewerkzeug sieht ausschliesslich Bilder.
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ANZAHL=0
while IFS= read -r f; do
  ln -f -- "$f" "$STAGING/$f" 2>/dev/null || cp -- "$f" "$STAGING/$f"
  ANZAHL=$((ANZAHL + 1))
done < <(dateiliste)
[ "$ANZAHL" -gt 0 ] || abbruch "Keine Bilddateien gefunden."
BYTES=$(du -sb "$STAGING" | cut -f1)

ueberschrift "Upload"
info "Dateien:   $ANZAHL ($(numfmt --to=iec --suffix=B "$BYTES" 2>/dev/null || echo "$BYTES Bytes"))"
info "Protokoll: $PROTOKOLL"
info "Ziel:      $BENUTZER@$HOST:$ZIEL_VERZEICHNIS"
info "Danach:    $ZIEL_BASIS_URL<dateiname>"
if [ "$ECHT" = "nein" ]; then
  warnung "TROCKENLAUF - es wird nichts uebertragen. Zum echten Upload: $0 --los"
fi
echo

if [ "$PROTOKOLL" = "ssh" ]; then
  werkzeug_pruefen rsync "Unter Debian/Ubuntu: apt install rsync"
  SSH_BEFEHL="ssh -p ${SSH_PORT:-22}"
  [ -n "${SSH_SCHLUESSEL:-}" ] && SSH_BEFEHL="$SSH_BEFEHL -i $SSH_SCHLUESSEL"
  RSYNC_ARGS=(-rlt --human-readable --progress --chmod=F644)
  [ "$ECHT" = "nein" ] && RSYNC_ARGS+=(--dry-run)
  rsync "${RSYNC_ARGS[@]}" -e "$SSH_BEFEHL" \
    "$STAGING/" "$BENUTZER@$HOST:$ZIEL_VERZEICHNIS/"
else
  werkzeug_pruefen lftp "Unter Debian/Ubuntu: apt install lftp"
  case "$PROTOKOLL" in
    ftps) SCHEMA="ftp";  TLS_ZEILEN=$'set ftp:ssl-force true\nset ftp:ssl-protect-data true\nset ssl:verify-certificate true' ;;
    ftp)  SCHEMA="ftp";  TLS_ZEILEN='set ftp:ssl-force false' ;;
    sftp) SCHEMA="sftp"; TLS_ZEILEN='' ;;
  esac

  TROCKEN=""
  [ "$ECHT" = "nein" ] && TROCKEN="--dry-run"

  # Zugangsdaten in eine nur fuer den eigenen Benutzer lesbare Datei schreiben,
  # statt sie als Kommandozeilenargument zu uebergeben - Argumente stehen sonst
  # fuer jeden sichtbar in der Prozessliste.
  BEFEHLE="$(mktemp)"
  chmod 600 "$BEFEHLE"
  trap 'rm -rf "$STAGING"; rm -f "$BEFEHLE"' EXIT
  {
    printf '%s\n' "$TLS_ZEILEN"
    printf 'set net:max-retries 3\n'
    printf 'set net:reconnect-interval-base 5\n'
    printf 'open -u %q,%q %s://%s\n' "$BENUTZER" "${PASSWORT:-}" "$SCHEMA" "$HOST"
    printf 'set cmd:fail-exit no\n'
    printf 'mkdir -p %q\n' "$ZIEL_VERZEICHNIS"
    printf 'set cmd:fail-exit yes\n'
    printf 'mirror -R --verbose --parallel=3 --no-perms %s %q %q\n' \
      "$TROCKEN" "$STAGING" "$ZIEL_VERZEICHNIS"
    printf 'bye\n'
  } > "$BEFEHLE"

  lftp -f "$BEFEHLE"
fi

echo
if [ "$ECHT" = "ja" ]; then
  erfolg "Upload durch. Jetzt pruefen, ob wirklich alles angekommen ist:"
  info   "    migration/02-verifizieren.sh"
else
  info "Trockenlauf beendet. Echter Upload: $0 --los"
fi
