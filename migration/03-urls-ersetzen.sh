#!/usr/bin/env bash
# Schritt 3: In einer Export-Datei alle GitHub-Bildadressen durch die neuen
# Adressen auf dem eigenen Webspace ersetzen.
#
#   migration/03-urls-ersetzen.sh artikel-export.csv          (nur anzeigen)
#   migration/03-urls-ersetzen.sh --los artikel-export.csv    (wirklich aendern)
#
# Funktioniert mit jedem Textformat - CSV, XML, JSON, SQL-Dump. Beim echten
# Lauf wird vorher eine Sicherungskopie <datei>.bak angelegt.
#
# Erkannt werden alle gaengigen Schreibweisen derselben Datei, also
# raw.githubusercontent.com, github.com/.../raw/..., .../blob/...?raw=true
# und cdn.jsdelivr.net - jeweils mit Branch-Namen oder Commit-Kennung.

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ECHT=nein
DATEIEN=()
while [ $# -gt 0 ]; do
  case "$1" in
    --los) ECHT=ja; shift ;;
    -h|--hilfe|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) abbruch "Unbekannte Option: $1" ;;
    *) DATEIEN+=("$1"); shift ;;
  esac
done

[ "${#DATEIEN[@]}" -gt 0 ] || abbruch "Keine Datei angegeben. Aufruf: $0 [--los] <datei> [...]"
config_laden
[ -f "$INDEX_DATEI" ] || abbruch "$INDEX_DATEI fehlt. Bitte zuerst migration/00-pruefen.sh ausfuehren."

for d in "${DATEIEN[@]}"; do
  [ -f "$d" ] || abbruch "Keine Datei: $d"
done

ueberschrift "URLs ersetzen"
info "Neue Basis: $ZIEL_BASIS_URL"
[ "$ECHT" = "nein" ] && warnung "TROCKENLAUF - es wird nichts geschrieben. Zum echten Lauf: --los"
echo

ZIEL_BASIS_URL="$ZIEL_BASIS_URL" \
INDEX_DATEI="$INDEX_DATEI" \
ECHT="$ECHT" \
GITHUB_BENUTZER="$GITHUB_BENUTZER" \
GITHUB_REPO="$GITHUB_REPO" \
perl -e '
use strict; use warnings;

my $basis  = $ENV{ZIEL_BASIS_URL};
my $echt   = $ENV{ECHT} eq "ja";
my $nutzer = $ENV{GITHUB_BENUTZER};
my $repo   = $ENV{GITHUB_REPO};

# Bekannte Dateinamen aus dem Index einlesen, um Verweise auf Bilder zu
# erkennen, die es gar nicht gibt.
my %bekannt;
open(my $idx, "<", $ENV{INDEX_DATEI}) or die "Index nicht lesbar: $!\n";
my $kopf = <$idx>;
while (my $z = <$idx>) { chomp $z; my ($n) = split /;/, $z; $bekannt{$n} = 1 if defined $n && length $n; }
close $idx;

my $trenner = qq{[^/\\s"'"'"'<>()\\[\\];,|]+};
my $muster = qr{
    https?://
    (?:
        raw\.githubusercontent\.com/\Q$nutzer\E/\Q$repo\E/(?:refs/heads/)?$trenner
      | media\.githubusercontent\.com/media/\Q$nutzer\E/\Q$repo\E/(?:refs/heads/)?$trenner
      | github\.com/\Q$nutzer\E/\Q$repo\E/(?:raw|blob)/(?:refs/heads/)?$trenner
      | cdn\.jsdelivr\.net/gh/\Q$nutzer\E/\Q$repo\E\@$trenner
    )
    /
    ([A-Za-z0-9._-]+\.(?:jpe?g|png))
    (?:\?[^\s"'"'"'<>()\[\];,|]*)?
}xi;

my ($summe, $summe_unbekannt) = (0, 0);
for my $datei (@ARGV) {
    open(my $ein, "<", $datei) or die "Nicht lesbar: $datei ($!)\n";
    binmode $ein;
    my $inhalt = do { local $/; <$ein> };
    close $ein;

    my $anzahl = 0;
    my %unbekannt;
    (my $neu = $inhalt) =~ s{$muster}{
        my $name = $1;
        $anzahl++;
        $unbekannt{$name} = 1 unless $bekannt{$name};
        $basis . $name;
    }ge;

    printf("  %-40s %4d Adresse(n)%s\n", $datei, $anzahl,
           $anzahl ? "" : "  - nichts gefunden");
    if (keys %unbekannt) {
        printf("      Achtung: verweist auf %d Bild(er), die nicht im Bestand sind:\n",
               scalar keys %unbekannt);
        printf("        %s\n", $_) for sort keys %unbekannt;
        $summe_unbekannt += scalar keys %unbekannt;
    }
    $summe += $anzahl;

    if ($echt && $anzahl) {
        open(my $sich, ">", "$datei.bak") or die "Sicherung fehlgeschlagen: $!\n";
        binmode $sich; print $sich $inhalt; close $sich;
        open(my $aus, ">", $datei) or die "Nicht schreibbar: $datei ($!)\n";
        binmode $aus; print $aus $neu; close $aus;
        print "      geaendert, Sicherung: $datei.bak\n";
    }
}
print "\n";
printf("Gefunden: %d Adresse(n) in %d Datei(en).\n", $summe, scalar @ARGV);
if ($summe_unbekannt) {
    print "$summe_unbekannt Verweis(e) zeigen auf Bilder, die im Repo fehlen - die\n";
    print "waren schon vorher tot und bleiben es. Bitte im Shop nachpflegen.\n";
}
exit($summe ? 0 : 3);
' -- "${DATEIEN[@]}"
ERGEBNIS=$?

echo
if [ "$ERGEBNIS" -eq 3 ]; then
  warnung "Keine GitHub-Adressen gefunden. Stimmt die Export-Datei?"
elif [ "$ECHT" = "ja" ]; then
  erfolg "Fertig. Die Datei kann jetzt in Billbee zurueckgespielt werden."
  info   "Danach im Shop und in Billbee stichprobenartig ein paar Artikelbilder ansehen."
else
  info "Sieht das richtig aus? Dann derselbe Aufruf mit --los"
fi
