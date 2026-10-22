# PHP2Shell-Kontrolle mit PowerShell

Ein kleines Skript für Windows. **Node.js und eine lokale PHP-Installation sind nicht erforderlich.** Alle Hinweise, Kommentare und Anleitungen in diesem Paket sind auf Deutsch.

## In drei Schritten starten

1. Alle Dateien aus diesem Ordner in einen eigenen Ordner kopieren, zum Beispiel `C:\php2shell-kontrolle`.
2. PowerShell öffnen und in diesen Ordner wechseln:

   ```powershell
   cd C:\php2shell-kontrolle
   ```

3. Eine eigene Webseite prüfen:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\php2shell-pruefen.ps1 example.com
   ```

`example.com` durch die eigene Domain ersetzen. Das Skript ergänzt `https://`, wenn nur ein Domainname angegeben wird.

Falls bereits PowerShell 7 verwendet wird, kann derselbe Befehl mit `pwsh` statt `powershell.exe` ausgefuehrt werden.

## Mehrere Webseiten prüfen

Die Datei `beispiele.txt` öffnen, die Beispieladressen durch eigene Webseiten ersetzen und speichern. Danach:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\php2shell-pruefen.ps1 -Liste .\beispiele.txt
```

Ein JSON-Bericht wird nur erstellt, wenn `-Bericht` angegeben wird:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\php2shell-pruefen.ps1 -Liste .\beispiele.txt -Bericht .\ergebnis.json
```

Ohne Adresse fragt das Skript interaktiv nach einer Webseite:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\php2shell-pruefen.ps1
```

## Ergebnis verstehen

| Ausgabe | Bedeutung |
| --- | --- |
| `MÖGLICHERWEISE BETROFFEN` | Ein gemeldeter PHP-Patchstand liegt auf oder unter dem hinterlegten Grenzwert. |
| `OK` | Ein gemeldeter stabiler PHP-Patchstand liegt über dem Grenzwert. |
| `UNBEKANNT` | Keine PHP-Version sichtbar, Version nicht gelistet, Vorabversion oder Anfrage fehlgeschlagen. |

Das Skript liest ausschließlich die HTTP-Header `Server` und `X-Powered-By`. Es sendet zuerst `HEAD` und nur bei HTTP 405 oder 501 anschließend `GET`. Weiterleitungen werden nicht verfolgt. Es sendet **keine Exploit-Anfragen**. Versteckte Header liefern `UNBEKANNT`; das ist kein Beweis für eine sichere oder unsichere Seite. Ein Versionsvergleich beweist ebenfalls keine Ausnutzbarkeit, da Anbieter Sicherheitskorrekturen auf ältere Versionsnummern zurueckportieren können.

Die Grenzwerte wurden aus [openai/php2shell-checker](https://github.com/openai/php2shell-checker) übernommen. [assetnote/php2shell-scanner](https://github.com/assetnote/php2shell-scanner) diente als Orientierung für die Zielpruefung. Dessen aktive, speicherintensive Testanfragen sind hier bewusst nicht enthalten; beide Werkzeuge liefern deshalb unterschiedliche Arten von Aussagen.

## Dateien auf GitHub hochladen

1. Auf GitHub ein neues Repository erstellen.
2. Im Repository **Add file → Upload files** öffnen.
3. `php2shell-pruefen.ps1`, `beispiele.txt` und `README.md` hochladen.
4. Auf **Commit changes** klicken.

Vor dem Hochladen `beispiele.txt` nur mit Beispieldomains belassen. Eigene interne Domainlisten und Ergebnisberichte gehören nicht ins öffentliche Repository.

## Technische Hinweise

- Windows PowerShell 5.1 oder PowerShell 7; keine Zusatzmodule.
- Standard-Zeitlimit: 10 Sekunden pro Anfrage; anpassbar mit `-Zeitlimit 20` (1 bis 60 Sekunden).
- Rückgabecodes: `0` nur OK, `1` mindestens ein möglicherweise betroffener Stand, `3` mindestens ein unbekanntes Ergebnis, `2` Eingabe- oder Berichtsfehler.
- Nur Webseiten prüfen, für die eine Berechtigung vorliegt.
