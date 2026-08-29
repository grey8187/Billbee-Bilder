# Billbee-Bilder

Bilderablage für die Artikel in Billbee. Das Repository enthält **keinen Code
und kein Projekt** — es dient ausschließlich dazu, Produktbilder unter einer
festen, öffentlich erreichbaren Adresse auszuliefern.

## Bestand

| | |
|---|---|
| Dateien | 438 (412 × `.jpg`, 26 × `.png`) |
| Verschiedene Bilder | 275 — 268 Dateien liegen unter mehreren Namen |
| Gesamtgröße | 48 MB |
| Aufbau | flach, alle Dateien im Wurzelverzeichnis |

## Namensschema

Es gibt zwei Sorten von Dateinamen, und beide werden gebraucht:

- `<Artikelnummer>_<lfd>.jpg` — z. B. `426799_01.jpg`. So verlinkt **Billbee**.
- `<Produktbeschreibung>.jpg` — z. B. `Ablaufstutzen-PVC-grau-DN-75-mit-Dichtring.jpg`.
  Das sind Namen aus der **WordPress-Mediathek** des Shops (erkennbar an
  Endungen wie `-566x566-1` oder `-e1769903747146`).

Die beiden Sorten sind großenteils **byte-identische Kopien desselben Bildes**
— `426799_01.jpg` und `Ablaufstutzen-PVC-grau-DN-75-mit-Dichtring.jpg` haben
dieselbe Prüfsumme. Das ist gewollt: jede Seite verlinkt ihren eigenen Namen.
**Nicht zusammenlegen**, sonst brechen die Links der jeweils anderen Seite.

## Aktuelle Adresse eines Bildes

```
https://raw.githubusercontent.com/grey8187/Billbee-Bilder/main/<dateiname>
```

## Wichtig zu wissen

- **GitHub ist als Bilderhoster nicht vorgesehen.** Die Acceptable Use Policies
  sehen Repositories für projektbezogene Dateien vor, nicht als Dateiablage
  oder CDN. `raw.githubusercontent.com` hat Ratenbegrenzungen, keine
  Verfügbarkeitszusage und nur fünf Minuten Cache (`max-age=300`).
- **Gelöschte Bilder sind nicht weg.** Git behält jede Fassung dauerhaft. Wer
  eine Datei aus dem Verzeichnis entfernt, macht sie über die alten Commits
  weiter abrufbar und gibt auch keinen Speicher frei.
- **Das Repository ist öffentlich.** Der komplette Bilderbestand ist für jeden
  einsehbar und kopierbar.

## Umzug auf den eigenen Webspace

Aus diesen Gründen sollen die Bilder auf `stegplattenversand.de` umziehen. Das
Vorgehen samt Werkzeugen liegt in [`MIGRATION.md`](MIGRATION.md) und im Ordner
[`migration/`](migration/).
