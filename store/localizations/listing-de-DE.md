# App Store listing — Deutsch (de-DE)

App Store Connect → Notepad Classic → de-DE. Uploaded via the App Store Connect API for v1.2.9.
Limits: app name 30, subtitle 30, promotional text 170, keywords 100, description 4000.

## Subtitle (24/30)
Keine KI. Tabs. Sitzung.

## Promotional Text (125/170)
Klartext-Notizblock für den Mac: keine KI, kein Konto, keine Cloud. Tabs und Sitzung bewahren Notizen. UTF-8, EUC-KR, UTF-16.

## Keywords (72/100)
notizblock,texteditor,klartext,codierung,tabs,notizen,editor,txt,unicode

## Description (1735/4000)
Ein schneller, privater Klartext-Editor für macOS. Für alle, die vom Windows-Notizblock kommen, und für alle, die Tabs und Wiederherstellung wollen, die TextEdit nicht bietet.

Keine KI. Kein Konto. Keine Cloud-Pflicht. Nur Text.

Sitzung automatisch wiederherstellen
Beenden Sie die App mit offenen Tabs, auch mit nicht gespeicherten Notizen: beim nächsten Start, auch nach einem Neustart, ist alles unverändert da. In den Einstellungen wählen Sie, ob jeder Start die vorherige Sitzung fortsetzt oder neu beginnt.

Mehrere Tabs
Mehrere Dokumente in einem Fenster. Per Ziehen umsortieren, mit Ctrl-Tab wechseln; nicht gespeicherte Tabs tragen ein *.

Textcodierungen
Öffnet und speichert in UTF-8, UTF-8 mit BOM, EUC-KR und UTF-16 (LE/BE). Über die Statusleiste lässt sich mit einer anderen Codierung erneut öffnen oder der Inhalt umwandeln, und nicht darstellbare Zeichen werden deutlich gemeldet.

Rechtschreibung und Autokorrektur
Nutzt die Systemwörterbücher von macOS, ohne Netzwerk. Die Autokorrektur ist optional, und für Code- oder Log-Endungen lässt sich die Prüfung abschalten.

Optionale Vorschau
Vorschau für .md und .html nebeneinander oder im Vollbild. Skripte werden nicht ausgeführt. Entfernte Bilder und CSS werden erst geladen, wenn Sie es in diesem Tab erlauben.

Außerdem
• Suchen und Ersetzen inline, mit Trefferzahl und Groß-/Kleinschreibung
• Syntaxhervorhebung für Markdown, JSON, XML, HTML und Logs
• Drucken, Gehe zu Zeile, Uhrzeit/Datum einfügen, Zeilenumbruch, Zoom
• Mehrere Fenster, hell und dunkel, Oberfläche in 16 Sprachen

Datenschutz
Läuft vollständig in der Sandbox, ohne Werbung, und erhebt keine Daten. Das Netzwerk wird nur in Tabs genutzt, in denen Sie entfernte Bilder in der Vorschau erlauben.

## What's New — v1.2.9 (1131/4000)
Korrekturen beim Öffnen und Schließen von Dateien.

• Ein aus dem Finder geöffnetes Dokument erhält kein macOS-Quarantäne-Attribut mehr. Bisher genügte das Lesen, um es zu setzen, obwohl nichts geschrieben wurde; danach fragte der Finder bei jedem Öffnen nach einer Prüfung — mit dieser App wie mit jeder anderen. Öffnen liest nur; geschrieben wird die Datei erst beim Speichern.

• Eine Datei, die sich nicht öffnen ließ, öffnet sich wieder. Konnte ein Tab beim Start nicht wiederhergestellt werden, wechselte erneutes Öffnen nur zum leeren Tab, ohne die Datei zu lesen.

• Dieselbe Datei über einen anderen Pfad — andere Groß-/Kleinschreibung oder ein symbolischer Link — öffnet nicht mehr als zwei Tabs, die sich gegenseitig überschreiben.

• Tippen in einem Tab, dessen Datei nicht gelesen werden konnte, übergeht nicht mehr die Warnung vor dem Ersetzen des Originals.

• Das Schließen des letzten Tabs schließt das Fenster. Vorher schien nichts zu geschehen.

• Beim Öffnen einer Datei bleibt kein leerer Tab „Ohne Titel“ daneben.

• Fehler beim Speichern nennen die tatsächliche Ursache, statt immer nach einem Ort zu fragen.
