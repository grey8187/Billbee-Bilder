# Umzug der Bilder auf den eigenen Webspace

Ziel: die 438 Bilder liegen künftig unter
`https://www.stegplattenversand.de/bilder/<dateiname>` statt auf GitHub.

## Die Reihenfolge ist entscheidend

```
  1. hochladen  →  2. kontrollieren  →  3. URLs umstellen  →  4. GitHub stilllegen
```

Solange Schritt 3 nicht gelaufen ist, zeigen alle Artikel weiter auf GitHub.
Die Schritte 1 und 2 sind deshalb völlig gefahrlos und beliebig wiederholbar.
**Erst umstellen, wenn Schritt 2 grün ist** — sonst zeigen Artikelbilder ins
Leere, und das fällt im Zweifel zuerst dem Kunden auf, nicht euch.

## Der kürzeste Weg

Ein Befehl, der Prüfung, Upload und Kontrolle nacheinander erledigt und vor
dem Hochladen einmal nachfragt:

```bash
migration/umzug.sh
```

Beim ersten Start legt er die Konfigurationsdatei an und sagt, was einzutragen
ist. Danach dasselbe Kommando nochmal — den Rest macht er allein. An Billbee
ändert er nichts.

## Ohne Kommandozeile

Geht auch, mit einem FTP-Programm:

1. **Bilder holen:** auf der Repository-Seite über *Code → Download ZIP*
   (direkt: `https://github.com/grey8187/Billbee-Bilder/archive/refs/heads/main.zip`)
   und entpacken.
2. **FileZilla** installieren (`filezilla-project.org`) und den FTP-Zugang des
   Hosters eintragen.
3. Auf dem Server im Web-Wurzelverzeichnis — meist `httpdocs/` oder `html/` —
   einen Ordner **`bilder`** anlegen.
4. Aus dem entpackten Ordner **nur die `.jpg`- und `.png`-Dateien** markieren
   (alle 438) und hineinziehen. `README.md`, `MIGRATION.md`, `.gitignore` und
   den Ordner `migration` **nicht** mitschicken.
5. Im Browser prüfen, ob ein Bild ankommt:
   `https://www.stegplattenversand.de/bilder/10169_01.jpg`

Was auf diesem Weg fehlt, ist die vollständige Kontrolle: ob wirklich alle 438
Bilder angekommen und dabei unverändert geblieben sind, prüft nur
`migration/02-verifizieren.sh` — dafür braucht es einmal die Kommandozeile
oder jemanden, der sie laufen lässt. Stichproben im Browser ersetzen das nicht
zuverlässig, weil ein abgebrochener Upload einzelne Dateien unvollständig
liegen lässt und die dann trotzdem „da" aussehen.

## Vorbereitung

```bash
cp migration/config.env.beispiel migration/config.env
```

Dann `migration/config.env` ausfüllen: Zieladresse, FTP-/SSH-Zugang und das
Zielverzeichnis auf dem Server. Die Datei ist per `.gitignore` vom Repository
ausgeschlossen und darf nicht eingecheckt werden — da stehen Zugangsdaten drin.

Wichtig ist, dass `ZIEL_VERZEICHNIS` (der Ordner auf dem Server) und
`ZIEL_BASIS_URL` (die Adresse im Browser) **auf denselben Ort zeigen**. Das ist
die mit Abstand häufigste Fehlerquelle. Prüfen lässt sich das, indem man eine
beliebige Datei per FTP dorthin legt und die passende URL im Browser aufruft.

## Schritt 0 — Bestand prüfen

```bash
migration/00-pruefen.sh
```

Prüft Dateinamen, Bildformate und Dubletten und erzeugt
`migration/bilder-index.csv` — die Liste, auf der alle weiteren Schritte
aufbauen: pro Bild Dateiname, Größe, Prüfsumme, alte und neue Adresse.

Diese CSV ist auch für sich nützlich: sie lässt sich in Excel öffnen und als
Nachschlagetabelle „welches Bild lag wo" verwenden.

## Schritt 1 — Hochladen

```bash
migration/01-hochladen.sh          # zeigt nur an, was passieren würde
migration/01-hochladen.sh --los    # lädt wirklich hoch
```

Überträgt alle 438 Dateien. Es werden bewusst **alle** hochgeladen, auch die
inhaltsgleichen Dubletten — die Namen werden von verschiedenen Stellen
verlinkt und müssen alle erreichbar bleiben. 48 MB fallen nicht ins Gewicht.

Der Upload läuft über `lftp` (FTPS, FTP, SFTP) oder `rsync` (SSH). Fehlt das
Programm, sagt das Skript, welches Paket nachzuinstallieren ist.

> **Hinweis:** Ein Teil der Bilder liegt vermutlich ohnehin schon auf dem
> Server — die Dateinamen im Stil `…-566x566-1.jpg` stammen aus der
> WordPress-Mediathek des Shops. Trotzdem alle in den neuen Ordner laden: nur
> so gilt für jedes Bild dieselbe, vorhersagbare Adresse, und die
> Artikelnummern-Namen brauchen ohnehin einen Platz.

## Schritt 2 — Kontrollieren

```bash
migration/02-verifizieren.sh --stichprobe 20   # schneller Vorabtest
migration/02-verifizieren.sh                   # alle 438 Bilder
```

Ruft jede neue Adresse ab und vergleicht die SHA-256-Prüfsumme mit der
lokalen Datei. Damit ist belegt, dass jedes Bild erreichbar **und
unverändert** ist — ein bloßer „HTTP 200"-Test würde auch eine
Fehlerseite als Erfolg werten.

Das Skript endet mit Fehlercode, solange auch nur ein Bild nicht stimmt.
**Erst weitermachen, wenn hier alles grün ist.**

## Schritt 3 — URLs in Billbee umstellen

Zuerst einmalig prüfen, ob das Werkzeug sauber arbeitet:

```bash
migration/99-selbsttest.sh
```

Dann die Artikeldaten aus Billbee exportieren und umstellen:

```bash
migration/03-urls-ersetzen.sh artikel-export.csv          # nur anzeigen
migration/03-urls-ersetzen.sh --los artikel-export.csv    # wirklich ändern
```

Erkannt werden alle Schreibweisen, in denen eine GitHub-Bildadresse auftreten
kann — `raw.githubusercontent.com`, `github.com/.../raw/...`,
`.../blob/...?raw=true`, `cdn.jsdelivr.net`, jeweils mit Branch-Namen oder
Commit-Kennung. Bilder anderer Herkunft (Shop-CDN, andere Repositories)
bleiben unangetastet. Beim echten Lauf wird vorher `<datei>.bak` angelegt.

Das Skript arbeitet auf jedem Textformat — CSV, XML, JSON, SQL-Dump. Es ist
also unabhängig davon, auf welchem Weg die Daten aus Billbee kommen.

**Was in Billbee selbst zu klären ist:** ob der Artikel-Export die Spalte mit
den Bild-URLs enthält und ob der Import sie zurückschreibt. Falls nicht, führt
der Weg über die Billbee-API (`https://api.billbee.io/api/v1`, Zugang über
API-Schlüssel plus separates API-Passwort im Billbee-Konto). Beides ließ sich
aus der Arbeitsumgebung heraus nicht nachsehen — `api.billbee.io` ist von dort
nicht erreichbar —, deshalb hier ausdrücklich als offener Punkt vermerkt und
nicht ins Blaue hinein beschrieben.

Nach dem Rückspielen: im Shop und in Billbee ein paar Artikel stichprobenartig
ansehen, darunter bewusst einen mit mehreren Bildern.

## Schritt 4 — GitHub stilllegen

Erst wenn Schritt 3 durch ist und alles läuft. Sinnvolle Wartezeit: ein paar
Wochen, damit Marktplätze und Caches die neuen Adressen übernommen haben.

Danach das Repository **archivieren statt löschen** (Repository Settings →
Archive this repository). Es bleibt als Sicherung lesbar, nimmt aber keine
Änderungen mehr an.

Zu wissen: Selbst nach dem Löschen aller Dateien im Verzeichnis blieben die
Bilder über die alten Commits abrufbar. Wirklich verschwinden sie nur, wenn
das gesamte Repository gelöscht wird.

## Wenn etwas schiefgeht

| Problem | Lösung |
|---|---|
| Schritt 3 hat zu viel ersetzt | `mv datei.bak datei` — die Sicherung zurückspielen |
| Bilder im Shop sind weg | Alte Adressen wieder eintragen; GitHub liefert unverändert weiter, solange das Repository existiert |
| Schritt 2 meldet HTTP 404 | `ZIEL_VERZEICHNIS` und `ZIEL_BASIS_URL` zeigen auf verschiedene Orte |
| Schritt 2 meldet „anderer Inhalt" | Upload war unvollständig — Schritt 1 wiederholen |
