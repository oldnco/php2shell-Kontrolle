param(
    [Parameter(Position = 0)]
    [string[]]$Webseiten,
    [string]$Liste,
    [string]$Bericht,
    [ValidateRange(1, 60)]
    [int]$Zeitlimit = 10
)

# PHP2Shell-Kontrolle für Windows PowerShell 5.1 und PowerShell 7.
# Schritt 1: Webseiten aus der Befehlszeile oder aus einer Textdatei einlesen.
# Schritt 2: HTTP-Antwortheader abrufen; bei HEAD 405/501 einmal GET versuchen.
# Schritt 3: Sichtbare PHP-Version mit den untenstehenden Grenzwerten vergleichen.
# Diese Datei sendet keine Exploit-Anfragen und beweist keine Ausnutzbarkeit.

$Grenzwerte = @{
    '5.4' = 45; '5.5' = 38; '5.6' = 40
    '7.0' = 33; '7.1' = 33; '7.2' = 34; '7.3' = 33; '7.4' = 33
    '8.0' = 30; '8.1' = 34; '8.2' = 34; '8.3' = 35; '8.4' = 26; '8.5' = 11
}

function Prüfe-Version([string]$Version) {
    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)([-+~].*)?$') { return 'UNBEKANNT' }
    $Zweig = "$([int]$Matches[1]).$([int]$Matches[2])"
    $Patch = [int]$Matches[3]
    $Zusatz = $Matches[4]
    if (-not $Grenzwerte.ContainsKey($Zweig)) { return 'UNBEKANNT' }
    if ($Zusatz -match '(?i)(^|[-+~.])(dev|alpha|beta|rc)') { return 'UNBEKANNT' }
    if ($Patch -le $Grenzwerte[$Zweig]) { return 'MÖGLICHERWEISE BETROFFEN' }
    return 'OK'
}

function Prüfe-Webseite([string]$Eingabe) {
    $Antwort = $null
    try {
        if ($Eingabe -match '[\x00-\x20\x7f]') { throw 'Adresse enthält Leer- oder Steuerzeichen.' }
        $Adresse = if ($Eingabe -match '^[a-z][a-z0-9+.-]*://') { $Eingabe } else { "https://$Eingabe" }
        $Uri = [uri]$Adresse
        if ($Uri.Scheme -notin @('http', 'https') -or -not $Uri.Host -or $Uri.UserInfo -or $Uri.Fragment) {
            throw 'Nur HTTP(S)-Adressen ohne Zugangsdaten oder Fragment sind erlaubt.'
        }

        $Header = ''
        $Statuscode = $null
        foreach ($Methode in @('HEAD', 'GET')) {
            $Anfrage = [System.Net.HttpWebRequest]::Create($Uri)
            $Anfrage.Method = $Methode
            $Anfrage.AllowAutoRedirect = $false
            $Anfrage.Timeout = $Zeitlimit * 1000
            $Anfrage.ReadWriteTimeout = $Zeitlimit * 1000
            $Anfrage.UserAgent = 'php2shell-powershell-kontrolle/1.0'
            try {
                $Antwort = [System.Net.HttpWebResponse]$Anfrage.GetResponse()
            } catch [System.Net.WebException] {
                if ($_.Exception.Response) { $Antwort = [System.Net.HttpWebResponse]$_.Exception.Response }
                else { throw }
            }
            try {
                $Statuscode = [int]$Antwort.StatusCode
                $Header += "`n" + $Antwort.Headers['Server'] + "`n" + $Antwort.Headers['X-Powered-By']
            } finally {
                if ($Antwort) { $Antwort.Close(); $Antwort = $null }
            }
            if ($Statuscode -notin @(405, 501)) { break }
        }

        $Version = $null
        $Bewertung = 'UNBEKANNT'
        foreach ($Treffer in [regex]::Matches($Header, '(?i)\bPHP[ /]([^\s,;)]+)')) {
            $Kandidat = $Treffer.Groups[1].Value
            $KandidatenBewertung = Prüfe-Version $Kandidat
            if ($null -eq $Version -or $KandidatenBewertung -eq 'MÖGLICHERWEISE BETROFFEN') {
                $Version = $Kandidat
                $Bewertung = $KandidatenBewertung
            }
            if ($Bewertung -eq 'MÖGLICHERWEISE BETROFFEN') { break }
        }
        $Hinweis = if ($Version) { "PHP $Version in HTTP-Headern gefunden (HTTP $Statuscode)." }
                   else { "Keine PHP-Version in Server/X-Powered-By gefunden (HTTP $Statuscode)." }
        if ($Statuscode -ge 300 -and $Statuscode -lt 400) { $Hinweis += ' Weiterleitung wurde nicht verfolgt.' }
        return [pscustomobject]@{ Webseite = $Eingabe; Status = $Bewertung; PhpVersion = $Version; Hinweis = $Hinweis }
    } catch {
        return [pscustomobject]@{ Webseite = $Eingabe; Status = 'UNBEKANNT'; PhpVersion = $null; Hinweis = $_.Exception.Message }
    } finally {
        if ($Antwort) { $Antwort.Close() }
    }
}

if ($Liste) {
    try {
        $Webseiten += @(Get-Content -LiteralPath $Liste -ErrorAction Stop | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
    } catch { Write-Error "Liste konnte nicht gelesen werden: $($_.Exception.Message)"; exit 2 }
}
if (-not $Webseiten -or $Webseiten.Count -eq 0) {
    $Eingabe = Read-Host 'Welche Webseite prüfen? Beispiel: example.com'
    if ($Eingabe) { $Webseiten = @($Eingabe.Trim()) }
}
if (-not $Webseiten -or $Webseiten.Count -eq 0) { Write-Error 'Keine Webseite angegeben.'; exit 2 }

$Ergebnisse = @()
foreach ($Webseite in $Webseiten) {
    $Ergebnis = Prüfe-Webseite $Webseite
    $Ergebnisse += $Ergebnis
    Write-Host "$($Ergebnis.Status) | $($Ergebnis.Webseite) | $($Ergebnis.Hinweis)"
}
if ($Bericht) {
    try {
        $Json = ConvertTo-Json -InputObject @($Ergebnisse) -Depth 3
        [System.IO.File]::WriteAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Bericht), $Json, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Bericht erstellt: $Bericht"
    } catch { Write-Error "Bericht konnte nicht geschrieben werden: $($_.Exception.Message)"; exit 2 }
}
if (@($Ergebnisse | Where-Object Status -eq 'MÖGLICHERWEISE BETROFFEN').Count -gt 0) { exit 1 }
if (@($Ergebnisse | Where-Object Status -eq 'UNBEKANNT').Count -gt 0) { exit 3 }
exit 0
