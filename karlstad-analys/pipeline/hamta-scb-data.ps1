<#
.SYNOPSIS
  Datapipeline for Karlstad-analys: SCB PxWebAPI v2 -> rådata -> datalager -> dataprodukt.

.DESCRIPTION
  Arkitektur i tre steg (kan köras separat eller alla på en gång):
    1. hamta        Hämtar json-stat2 från SCB och sparar OFÖRÄNDRAD i data\raw\ (landningszon).
                    Rådatan rörs aldrig i efterhand - historik och spårbarhet bevaras.
    2. transformera Läser rådata, plattar ut json-stat2 till rader, tvättar och aggregerar
                    till analysfärdiga serier i data\curated\ (datalagret). Gemensamma
                    dimensioner: region (kommunkod) och tid (år/månad).
    3. publicera    Bygger app\data.js (window.KARLSTAD_DATA) och data\datakatalog.json,
                    samt kör avstämningskontroller mellan oberoende källtabeller.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File pipeline\hamta-scb-data.ps1
  powershell -ExecutionPolicy Bypass -File pipeline\hamta-scb-data.ps1 -Steg transformera
#>
param(
  [ValidateSet("alla","hamta","transformera","publicera")]
  [string]$Steg = "alla"
)

$ErrorActionPreference = "Stop"
$BasUrl     = "https://api.scb.se/OV0104/v2beta/api/v2"
$Rot        = Split-Path -Parent $PSScriptRoot
$RawDir     = Join-Path $Rot "data\raw"
$CuratedDir = Join-Path $Rot "data\curated"
$AppDir     = Join-Path $Rot "app"
$ManifestFil = Join-Path $RawDir "_manifest.json"
$Utf8Bom    = New-Object System.Text.UTF8Encoding($true)

# Karlstads kommunkod hos SCB. "17" = Värmlands län (systemperspektiv), "00" = riket.
$KARLSTAD = "1780"
$VARMLAND = "17"
$RIKET    = "00"

# RKA:s officiella jämförelsegrupp "Liknande kommuner, övergripande, Karlstad, 2025"
# (Kolada-grupp G37421) + Karlstad självt. Jämför strukturellt lika, inte grannar.
$KoladaBas = "https://api.kolada.se/v3"
$JamforKommuner = [ordered]@{
  "1780"="Karlstad"; "0680"="Jönköping"; "0780"="Växjö"; "0880"="Kalmar"
  "1080"="Karlskrona"; "1281"="Lund"; "2580"="Luleå"; "2581"="Piteå"
}
# Verksamhetsspecifika jämförelsegrupper (RKA 2024) - skarpare än övergripande per sektor.
$GruppGrundskola  = [ordered]@{ "1780"="Karlstad"; "0183"="Sundbyberg"; "0188"="Norrtälje"; "1281"="Lund"
                                "2180"="Gävle"; "2281"="Sundsvall"; "2480"="Umeå"; "2580"="Luleå" }        # G35961
$GruppGymnasium   = [ordered]@{ "1780"="Karlstad"; "0188"="Norrtälje"; "0880"="Kalmar"; "1281"="Lund"
                                "1380"="Halmstad"; "2480"="Umeå"; "2482"="Skellefteå"; "2580"="Luleå" }    # G36253
$GruppAldreomsorg = [ordered]@{ "1780"="Karlstad"; "0484"="Eskilstuna"; "0780"="Växjö"; "1380"="Halmstad"
                                "1384"="Kungsbacka"; "1490"="Borås"; "2180"="Gävle"; "2580"="Luleå" }      # G176581

# ---------------------------------------------------------------------------
# DATAMÄNGDSKATALOG - en post per källtabell. Detta är pipelinens sanning:
# vad som hämtas, varifrån, och hur det ska beskrivas i datakatalogen.
# ---------------------------------------------------------------------------
$Datamangder = @(
  [pscustomobject]@{ Id="befolkning_lang"; Tabell="TAB638"
    Titel="Folkmängd 1968-2024"
    Beskrivning="Total folkmängd 31 dec per år, Karlstad och riket. Längsta jämförbara serien."
    Enhet="antal personer"; Uppdateras="årligen (feb)"
    Query=[ordered]@{ Region="$KARLSTAD,$VARMLAND,$RIKET"; ContentsCode="BE0101N1"; Tid="from(1968)" } }

  [pscustomobject]@{ Id="folkmangd_alder"; Tabell="TAB6574"
    Titel="Folkmängd efter ålder och kön 2010-2025"
    Beskrivning="Femårsklasser, underlag för ålderspyramid och åldersgruppernas utveckling."
    Enhet="antal personer"; Uppdateras="årligen (feb)"
    Query=[ordered]@{ Region=$KARLSTAD; Alder="*"; Kon="1,2,1+2"; ContentsCode="000007Y7"; Tid="from(2010)" } }

  [pscustomobject]@{ Id="befolkningsforandringar"; Tabell="TAB5169"
    Titel="Befolkningsförändringar 2000-2024"
    Beskrivning="Födda, döda, flyttningar m.m. per helår. Förklarar VARFÖR folkmängden ändras."
    Enhet="antal personer"; Uppdateras="kvartalsvis"
    Query=[ordered]@{ Region=$KARLSTAD; Forandringar="110,115,130,135,140,150,175,220,230,260"
                      Period="hel"; Kon="1+2"; ContentsCode="000002Z9"; Tid="from(2000)" } }

  [pscustomobject]@{ Id="prognos_oversikt"; Tabell="TAB694"
    Titel="SCB:s befolkningsframskrivning 2024-2070, översikt"
    Beskrivning="Officiell regional framskrivning: folkmängd, folkökning och komponenter."
    Enhet="antal personer"; Uppdateras="vartannat år"
    Query=[ordered]@{ Region=$KARLSTAD; ContentsCode="*"; Tid="from(2024)" } }

  [pscustomobject]@{ Id="prognos_alder"; Tabell="TAB698"
    Titel="SCB:s befolkningsframskrivning per ålder 2024-2070"
    Beskrivning="Framskriven folkmängd i ettårsklasser - underlag för framtida försörjningskvot."
    Enhet="antal personer"; Uppdateras="vartannat år"
    Query=[ordered]@{ Region=$KARLSTAD; Kon="1,2"; Alder="*"; ContentsCode="000004LG"; Tid="from(2024)" } }

  [pscustomobject]@{ Id="medelalder"; Tabell="TAB637"
    Titel="Befolkningens medelålder 1998-2025"
    Beskrivning="Medelålder, Karlstad jämfört med riket."
    Enhet="år"; Uppdateras="årligen (feb)"
    Query=[ordered]@{ Region="$KARLSTAD,$VARMLAND,$RIKET"; Kon="1+2"; ContentsCode="BE0101G9"; Tid="from(1998)" } }

  [pscustomobject]@{ Id="forsorjningskvot"; Tabell="TAB4642"
    Titel="Demografisk försörjningskvot 2000-2025"
    Beskrivning="(Antal 0-19 + antal 65+) / antal 20-64. SCB:s officiella definition."
    Enhet="kvot"; Uppdateras="årligen"
    Query=[ordered]@{ Region="$KARLSTAD,$RIKET"; ContentsCode="*"; Tid="from(2000)" } }   # OBS: tabellen saknar länsnivå

  [pscustomobject]@{ Id="bostader"; Tabell="TAB2538"
    Titel="Färdigställda lägenheter i nybyggda hus 1990-2025"
    Beskrivning="Nyproduktion per hustyp (flerbostadshus/småhus)."
    Enhet="antal lägenheter"; Uppdateras="årligen (maj)"
    Query=[ordered]@{ Region=$KARLSTAD; Hustyp="FLERBO,SMÅHUS"; ContentsCode="BO0101A5"; Tid="from(1990)" } }

  [pscustomobject]@{ Id="inkomst"; Tabell="TAB3554"
    Titel="Sammanräknad förvärvsinkomst 20-64 år, 1999-2024"
    Beskrivning="Median- och medelinkomst (tkr/år) för åldern 20-64, per kön, Karlstad och riket."
    Enhet="tkr per år (löpande priser)"; Uppdateras="årligen (jan)"
    Query=[ordered]@{ Region="$KARLSTAD,$VARMLAND,$RIKET"; Kon="1,2,1+2"; Alder="20-64"; Inkomstklass="TOT"
                      ContentsCode="HE0110J8,HE0110J7"; Tid="from(1999)" } }

  [pscustomobject]@{ Id="utbildning"; Tabell="TAB4320"
    Titel="Utbildningsnivå 25-64 år, 2008-2025"
    Beskrivning="Befolkning 25-64 efter högsta utbildningsnivå. Aggregeras till för-/gymnasial/eftergymnasial."
    Enhet="antal personer"; Uppdateras="årligen (apr)"
    Query=[ordered]@{ Region="$KARLSTAD,$VARMLAND,$RIKET"; UtbildningsNiva="1,2,3,4,5,6,7,US"
                      Alder=((25..64) -join ","); Kon="1,2"; ContentsCode="000000I2"; Tid="from(2008)" } }

  [pscustomobject]@{ Id="arbetsmarknad"; Tabell="TAB5663"
    Titel="Sysselsättningsgrad och arbetslöshet (BAS), månad 2024-"
    Beskrivning="Preliminär månadsstatistik från Befolkningens arbetsmarknadsstatus, 20-64 år."
    Enhet="procent"; Uppdateras="månadsvis"
    Query=[ordered]@{ Region="$KARLSTAD,$VARMLAND,$RIKET"; NyckeltalSCB="BAS02,BAS03"
                      ContentsCode="000007AN"; Tid="*" } }

  [pscustomobject]@{ Id="skattesats"; Tabell="TAB2017"
    Titel="Kommunala skattesatser 2000-2026"
    Beskrivning="Total kommunal skattesats samt del till kommunen, Karlstad och riket."
    Enhet="procent"; Uppdateras="årligen (dec)"
    Query=[ordered]@{ Region="$KARLSTAD,$RIKET"; ContentsCode="OE0101D1,OE0101D2"; Tid="from(2000)" } }

  # --- Kolada (RKA): nyckeltal för jämförelse med liknande kommuner. Tabell = KPI-id. ---
  [pscustomobject]@{ Id="kolada_resultat"; Kalla="Kolada"; Tabell="N03102"
    Titel="Årets resultat som andel av skatt & generella statsbidrag"
    Beskrivning="Kommunens ekonomiska resultat. Tumregel för god ekonomisk hushållning: ca 2 procent."
    Enhet="procent"; Uppdateras="årligen" }

  [pscustomobject]@{ Id="kolada_soliditet"; Kalla="Kolada"; Tabell="N03002"
    Titel="Soliditet inkl. pensionsåtaganden"
    Beskrivning="Långsiktig betalningsförmåga: eget kapital (inkl. hela pensionsskulden) som andel av tillgångarna."
    Enhet="procent"; Uppdateras="årligen" }

  [pscustomobject]@{ Id="kolada_nettokostnadsavvikelse"; Kalla="Kolada"; Tabell="N00097"
    Titel="Nettokostnadsavvikelse totalt (exkl. LSS)"
    Beskrivning="Avvikelse mot statistiskt förväntad kostnad givet kommunens struktur. Positiv = dyrare än strukturen motiverar."
    Enhet="procent"; Uppdateras="årligen" }

  [pscustomobject]@{ Id="kolada_behorighet"; Kalla="Kolada"; Tabell="N15428"
    Grupp=$GruppGrundskola; GruppNamn="Liknande kommuner grundskola, Karlstad 2024 (RKA G35961)"
    Titel="Elever i åk 9 behöriga till yrkesprogram (hemkommun)"
    Beskrivning="Andel av kommunens folkbokförda åk 9-elever som är behöriga till gymnasiets yrkesprogram."
    Enhet="procent"; Uppdateras="årligen" }

  [pscustomobject]@{ Id="kolada_gymnasieexamen"; Kalla="Kolada"; Tabell="N17457"
    Grupp=$GruppGymnasium; GruppNamn="Liknande kommuner gymnasieskola, Karlstad 2024 (RKA G36253)"
    Titel="Gymnasieelever med examen eller studiebevis inom 4 år (hemkommun)"
    Beskrivning="Genomströmning i gymnasiet för kommunens folkbokförda elever."
    Enhet="procent"; Uppdateras="årligen" }

  [pscustomobject]@{ Id="kolada_hemtjanst"; Kalla="Kolada"; Tabell="U21468"
    Grupp=$GruppAldreomsorg; GruppNamn="Liknande kommuner äldreomsorg, Karlstad 2024 (RKA G176581)"
    Titel="Brukarbedömning hemtjänst - helhetssyn"
    Beskrivning="Andel brukare som sammantaget är nöjda med sin hemtjänst (Socialstyrelsens brukarundersökning)."
    Enhet="procent"; Uppdateras="årligen" }

  # --- Karlstads kommun GeoServer (WFS): geodata. Tabell = lagernamn. ---
  [pscustomobject]@{ Id="geo_stadsdelar"; Kalla="Fil"; Tabell="Stadsdelar Json.txt"
    Sokvag="C:\Users\Oskar\Desktop\Claude\Projekt\16-Open-data\Stadsdelar Json.txt"
    Titel="Stadsdelar (polygoner, lokal export i SWEREF 99 TM)"
    Beskrivning="Karlstads stadsdelsindelning från lokal GeoJSON-export (EPSG:3006) - konverteras till WGS 84 i transformsteget."
    Enhet="geografiska ytor"; Uppdateras="vid ändring" }

  [pscustomobject]@{ Id="geo_lekplatser"; Kalla="GeoServer"; Tabell="karlstad_lekplatser"
    Titel="Lekplatser (punkter)"
    Beskrivning="Kommunala lekplatser med namn - underlag för utbudsanalys per stadsdel."
    Enhet="platser"; Uppdateras="vid ändring" }

  [pscustomobject]@{ Id="geo_parker"; Kalla="GeoServer"; Tabell="karlstad_parker"
    Titel="Parker (polygoner)"
    Beskrivning="Kommunala parker med namn."
    Enhet="ytor"; Uppdateras="vid ändring" }

  [pscustomobject]@{ Id="geo_tomter"; Kalla="GeoServer"; Tabell="karlstad_lediga_tomter"
    Titel="Lediga tomter (polygoner)"
    Beskrivning="Kommunens lediga småhustomter med areal och länk."
    Enhet="tomter"; Uppdateras="löpande" }

  [pscustomobject]@{ Id="geo_planer"; Kalla="GeoServer"; Tabell="karlstad_planer_pagaende"
    Titel="Pågående detaljplaner (polygoner)"
    Beskrivning="Detaljplaner under arbete - indikator på var utvecklingstrycket finns."
    Enhet="planområden"; Uppdateras="löpande" }

  [pscustomobject]@{ Id="geo_elljusspar"; Kalla="GeoServer"; Tabell="karlstad_elljusspar"
    Titel="Elljusspår (linjer)"
    Beskrivning="Belysta motionsspår - folkhälsoinfrastruktur, användbar året runt."
    Enhet="spår"; Uppdateras="vid ändring" }

  [pscustomobject]@{ Id="geo_motionsspar"; Kalla="GeoServer"; Tabell="karlstad_motionsspar"
    Titel="Motionsspår (linjer)"
    Beskrivning="Kommunala motionsspår."
    Enhet="spår"; Uppdateras="vid ändring" }

  # --- SCB:s öppna geodata (geodata.scb.se, workspace stat): statistikområden. ---
  [pscustomobject]@{ Id="geo_deso"; Kalla="GeoSCB"; Tabell="DeSO_2025"
    Titel="DeSO - demografiska statistikområden (polygoner)"
    Beskrivning="SCB:s DeSO-indelning för Karlstad, med koppling till RegSO. Nyckel för statistik på delområdesnivå."
    Enhet="geografiska ytor"; Uppdateras="årligen" }

  [pscustomobject]@{ Id="geo_regso"; Kalla="GeoSCB"; Tabell="RegSO_2025"
    Titel="RegSO - regionala statistikområden (polygoner)"
    Beskrivning="SCB:s RegSO-indelning för Karlstad med områdesnamn."
    Enhet="geografiska ytor"; Uppdateras="årligen" }

  [pscustomobject]@{ Id="omraden_befolkning"; Tabell="TAB6574"
    Titel="Befolkning per DeSO och RegSO, senaste år"
    Beskrivning="Folkmängd och åldersstruktur per statistikområde - grund för analys på delområdesnivå."
    Enhet="antal personer"; Uppdateras="årligen (feb)"
    Query=[ordered]@{ Region="1780*"; Alder="*"; Kon="1+2"; ContentsCode="000007Y7"; Tid="top(1)" } }

  [pscustomobject]@{ Id="regso_socioek"; Tabell="TAB6586"
    Titel="Socioekonomiskt index per RegSO 2011-2024"
    Beskrivning="SCB:s socioekonomiska index med områdestyp (1 = stora utmaningar ... 5 = mycket goda förutsättningar) och delindikatorer."
    Enhet="index/andelar"; Uppdateras="årligen"
    Query=[ordered]@{ Region="1780*"; ContentsCode="*"; Tid="*" } }
)

# ---------------------------------------------------------------------------
# HJÄLPFUNKTIONER
# ---------------------------------------------------------------------------

function Get-ScbUrl($tabell, $query) {
  $delar = foreach ($p in $query.GetEnumerator()) {
    "valueCodes[{0}]={1}" -f $p.Key, [uri]::EscapeDataString($p.Value).Replace("%2C", ",").Replace("%2A", "*")
  }
  "{0}/tables/{1}/data?{2}&outputFormat=json-stat2" -f $BasUrl, $tabell, ($delar -join "&")
}

# Plattar ut json-stat2 till rader: en rad = en observation med dimensionskoder + värde.
# json-stat2 lagrar värden i en endimensionell array i radordning (sista dimensionen
# varierar snabbast) - index räknas om till koordinater via dimensionernas storlekar.
function ConvertFrom-JsonStat2($stat) {
  $dims  = @($stat.id)
  $sizes = @($stat.size)
  $n     = $dims.Count

  $koder  = @{}
  $labels = @{}
  foreach ($d in $dims) {
    $cat = $stat.dimension.$d.category
    if ($null -ne $cat.index -and $cat.index -isnot [array]) {
      $koder[$d] = @($cat.index.PSObject.Properties | Sort-Object { [int]$_.Value } | ForEach-Object Name)
    } elseif ($cat.index -is [array]) {
      $koder[$d] = @($cat.index)
    } else {
      $koder[$d] = @($cat.label.PSObject.Properties.Name)
    }
    $lbl = @{}
    if ($null -ne $cat.label) { foreach ($p in $cat.label.PSObject.Properties) { $lbl[$p.Name] = $p.Value } }
    $labels[$d] = $lbl
  }

  $strides = New-Object int[] $n
  $acc = 1
  for ($k = $n - 1; $k -ge 0; $k--) { $strides[$k] = $acc; $acc *= $sizes[$k] }

  $rader = New-Object System.Collections.Generic.List[object]
  $varden = $stat.value
  for ($i = 0; $i -lt $varden.Count; $i++) {
    $rad = @{}
    for ($k = 0; $k -lt $n; $k++) {
      $pos = [math]::Floor($i / $strides[$k]) % $sizes[$k]
      $rad[$dims[$k]] = $koder[$dims[$k]][$pos]
    }
    $rad["varde"] = $varden[$i]
    $rader.Add($rad)
  }
  @{ Rader = $rader; Labels = $labels; Dims = $dims }
}

function Select-Rader($rader, $filter) {
  $rader | Where-Object { $rad = $_; -not ($filter.GetEnumerator() | Where-Object { $rad[$_.Key] -ne $_.Value }) }
}

# Gör en tidsserie {ar:[], varde:[]} av rader, sorterad på tid.
function New-Serie($rader) {
  $s = @($rader | Sort-Object { $_["Tid"] })
  [ordered]@{ ar = @($s | ForEach-Object { $_["Tid"] }); varde = @($s | ForEach-Object { $_["varde"] }) }
}

# Summerar rader per Tid (för aggregering över t.ex. kön eller åldersklasser).
function New-SummeradSerie($rader) {
  $grupper = $rader | Group-Object { $_["Tid"] } | Sort-Object Name
  [ordered]@{
    ar    = @($grupper | ForEach-Object { $_.Name })
    varde = @($grupper | ForEach-Object {
      ($_.Group | ForEach-Object { $_["varde"] } | Where-Object { $null -ne $_ } | Measure-Object -Sum).Sum
    })
  }
}

# Åldersklass (t.ex. "-4", "25-29", "85+", "100+") -> analysgrupp.
function Get-AldersGrupp($kod) {
  if ($kod -eq "-4") { $lb = 0 }
  elseif ($kod -match "^(\d+)") { $lb = [int]$Matches[1] }
  else { return $null }
  if     ($lb -lt 20) { "0-19" }
  elseif ($lb -lt 65) { "20-64" }
  elseif ($lb -lt 80) { "65-79" }
  else                { "80+" }
}

function Write-Fil($sokvag, $innehall) {
  [System.IO.File]::WriteAllText($sokvag, $innehall, $Utf8Bom)
}

# SWEREF 99 TM (EPSG:3006) -> WGS 84, Gauss-Krügers inversformler (Lantmäteriet, GRS80).
function ConvertFrom-Sweref([double]$nord, [double]$ost) {
  $f = 1/298.257222101; $e2 = $f*(2-$f); $k0 = 0.9996; $lon0 = 15*[math]::PI/180
  $n = $f/(2-$f); $aRoof = 6378137/(1+$n)*(1+$n*$n/4+[math]::Pow($n,4)/64)
  $xi = $nord/($k0*$aRoof); $eta = ($ost-500000)/($k0*$aRoof)
  $d1 = $n/2 - 2*$n*$n/3 + 37*[math]::Pow($n,3)/96; $d2 = $n*$n/48 + [math]::Pow($n,3)/15; $d3 = 17*[math]::Pow($n,3)/480
  $xiP = $xi - $d1*[math]::Sin(2*$xi)*[math]::Cosh(2*$eta) - $d2*[math]::Sin(4*$xi)*[math]::Cosh(4*$eta) - $d3*[math]::Sin(6*$xi)*[math]::Cosh(6*$eta)
  $etaP = $eta - $d1*[math]::Cos(2*$xi)*[math]::Sinh(2*$eta) - $d2*[math]::Cos(4*$xi)*[math]::Sinh(4*$eta) - $d3*[math]::Cos(6*$xi)*[math]::Sinh(6*$eta)
  $phiS = [math]::Asin([math]::Sin($xiP)/[math]::Cosh($etaP))
  $dLam = [math]::Atan([math]::Sinh($etaP)/[math]::Cos($xiP))
  $sf = [math]::Sin($phiS)
  $AS = $e2 + $e2*$e2 + [math]::Pow($e2,3) + [math]::Pow($e2,4)
  $BS = -(7*$e2*$e2 + 17*[math]::Pow($e2,3) + 30*[math]::Pow($e2,4))/6
  $CS = (224*[math]::Pow($e2,3) + 889*[math]::Pow($e2,4))/120
  $DS = -(4279*[math]::Pow($e2,4))/1260
  $phi = $phiS + $sf*[math]::Cos($phiS)*($AS + $BS*$sf*$sf + $CS*[math]::Pow($sf,4) + $DS*[math]::Pow($sf,6))
  ,@([math]::Round(($lon0+$dLam)*180/[math]::PI, 5), [math]::Round($phi*180/[math]::PI, 5))
}

# Avrundar GeoJSON-koordinater rekursivt till 5 decimaler (~1 m) - krymper filstorleken
# rejält utan synbar effekt på kart- eller analysprecision.
function Round-Koord($k) {
  if ($k -is [System.Collections.IEnumerable] -and $k -isnot [string]) {
    $arr = @($k)
    if ($arr.Count -gt 0 -and ($arr[0] -is [double] -or $arr[0] -is [decimal] -or $arr[0] -is [int] -or $arr[0] -is [int64])) {
      if ([double]$arr[0] -gt 10000) { return ConvertFrom-Sweref ([double]$arr[1]) ([double]$arr[0]) }
      return ,@($arr | ForEach-Object { [math]::Round([double]$_, 5) })
    }
    return ,@($arr | ForEach-Object { Round-Koord $_ })
  }
  $k
}

# ---------------------------------------------------------------------------
# STEG 1: HÄMTA (källa -> landningszon)
# ---------------------------------------------------------------------------
if ($Steg -in @("alla","hamta")) {
  Write-Host "=== STEG 1: Hämtar rådata från SCB ===" -ForegroundColor Cyan
  $manifest = [ordered]@{}
  foreach ($dm in $Datamangder) {
    $kalla = if ($null -ne $dm.PSObject.Properties["Kalla"]) { $dm.Kalla } else { "SCB" }
    $arKolada = ($kalla -eq "Kolada")
    $arGeo    = ($kalla -in @("GeoServer","GeoSCB"))
    if ($arKolada) {
      $koladaGrupp = if ($null -ne $dm.PSObject.Properties["Grupp"]) { $dm.Grupp } else { $JamforKommuner }
      $url = "$KoladaBas/data/kpi/$($dm.Tabell)/municipality/$(@($koladaGrupp.Keys) -join ',')"
    } elseif ($kalla -eq "GeoServer") {
      $url = "https://gi.karlstad.se/geoserver/oppnadata/wfs?service=WFS&version=2.0.0&request=GetFeature" +
             "&typeNames=oppnadata:$($dm.Tabell)&outputFormat=application/json&srsName=EPSG:4326"
    } elseif ($kalla -eq "GeoSCB") {
      # SCB:s öppna geodata: filtrera till Karlstads kommun redan i frågan (annars hela riket)
      $url = "https://geodata.scb.se/geoserver/stat/ows?service=WFS&version=2.0.0&request=GetFeature" +
             "&typeNames=stat:$($dm.Tabell)&outputFormat=application/json&srsName=EPSG:4326" +
             "&cql_filter=" + [uri]::EscapeDataString("kommunkod='$KARLSTAD'")
    } elseif ($kalla -eq "Fil") {
      $url = ""   # sätts i läsgrenen nedan
    } else {
      $url = Get-ScbUrl $dm.Tabell $dm.Query
    }
    Write-Host ("  {0,-26} {1} ... " -f $dm.Id, $dm.Tabell) -NoNewline
    if ($kalla -eq "Fil") {
      # Lokal fil som källa - läses i stället för HTTP, samma flöde i övrigt
      $text = [System.IO.File]::ReadAllText($dm.Sokvag, (New-Object System.Text.UTF8Encoding($false)))
      $url = "file:///" + ($dm.Sokvag.Replace("\", "/"))
    } else {
      $resp = Invoke-WebRequest -Uri $url -TimeoutSec 120 -UseBasicParsing
      # Avkoda alltid råbytes som UTF-8: Kolada skickar ingen charset-header,
      # och PowerShell 5.1 gissar då fel (Latin-1) så att åäö förstörs.
      $text = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())
    }
    Write-Fil (Join-Path $RawDir ($dm.Id + ".json")) $text
    $json = ConvertFrom-Json $text
    $antal = if ($arKolada) { @($json.values).Count }
             elseif ($arGeo -or $kalla -eq "Fil") { @($json.features).Count }
             else { @($json.value).Count }
    $manifest[$dm.Id] = [ordered]@{
      tabell = $dm.Tabell; url = $url
      hamtad = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss"); antalVarden = $antal
    }
    Write-Host "$antal värden" -ForegroundColor Green
    Start-Sleep -Seconds 1   # respektera SCB:s rategräns
  }
  Write-Fil $ManifestFil (($manifest | ConvertTo-Json -Depth 5))
  Write-Host "  Manifest sparat: $ManifestFil"
}

# ---------------------------------------------------------------------------
# STEG 2: TRANSFORMERA (landningszon -> datalager)
# ---------------------------------------------------------------------------
if ($Steg -in @("alla","transformera")) {
  Write-Host "=== STEG 2: Transformerar till datalager ===" -ForegroundColor Cyan
  $manifest = ConvertFrom-Json ([System.IO.File]::ReadAllText($ManifestFil, $Utf8Bom))

  foreach ($dm in $Datamangder) {
    Write-Host ("  {0,-26} " -f $dm.Id) -NoNewline
    $stat = ConvertFrom-Json ([System.IO.File]::ReadAllText((Join-Path $RawDir ($dm.Id + ".json")), $Utf8Bom))
    $meta = $manifest.($dm.Id)
    $innehall = $null

    if ($dm.Id -like "kolada_*") {
      # Kolada: eget JSON-format (values[] med kpi/period/municipality) - en serie per kommun, kön "T" = totalt
      $koladaGrupp = if ($null -ne $dm.PSObject.Properties["Grupp"]) { $dm.Grupp } else { $JamforKommuner }
      $gruppNamn = if ($null -ne $dm.PSObject.Properties["GruppNamn"]) { $dm.GruppNamn } else { "Liknande kommuner, övergripande, Karlstad 2025 (RKA G37421)" }
      $serier = [ordered]@{}
      foreach ($kod in @($koladaGrupp.Keys)) {
        $obs = @($stat.values | Where-Object { $_.municipality -eq $kod } | Sort-Object period)
        $ar = @(); $vv = @()
        foreach ($o in $obs) {
          $t = $o.values | Where-Object { $_.gender -eq "T" } | Select-Object -First 1
          if ($null -ne $t -and $null -ne $t.value) { $ar += [string]$o.period; $vv += $t.value }
        }
        $serier[$kod] = [ordered]@{ ar = $ar; varde = $vv }
      }
      $innehall = [ordered]@{ kpi = $dm.Tabell; kommuner = $koladaGrupp; gruppNamn = $gruppNamn; serier = $serier }
      $rader = @($stat.values)
    }
    elseif ($dm.Id -like "geo_*") {
      # GeoJSON: behåll bara analysrelevanta attribut och avrunda koordinater.
      $behall = @{ geo_stadsdelar = @("namn"); geo_lekplatser = @("name"); geo_parker = @("name")
                   geo_tomter = @("type","area","url"); geo_planer = @("namn","url")
                   geo_elljusspar = @("name"); geo_motionsspar = @("name")
                   geo_deso = @("desokod","regsokod"); geo_regso = @("regsokod","regsonamn") }[$dm.Id]
      $features = foreach ($f in $stat.features) {
        $props = [ordered]@{}
        foreach ($p in $behall) { if ($null -ne $f.properties.$p) { $props[$p] = $f.properties.$p } }
        [ordered]@{ type = "Feature"; properties = $props
                    geometry = [ordered]@{ type = $f.geometry.type; coordinates = (Round-Koord $f.geometry.coordinates) } }
      }
      $innehall = [ordered]@{ antal = @($features).Count
                              geojson = [ordered]@{ type = "FeatureCollection"; features = @($features) } }
      $rader = @($stat.features)
    }
    else {
    $platt = ConvertFrom-JsonStat2 $stat
    $rader = $platt.Rader
    switch ($dm.Id) {

      "befolkning_lang" {
        $innehall = [ordered]@{ serier = [ordered]@{} }
        foreach ($reg in @($KARLSTAD, $VARMLAND, $RIKET)) {
          $innehall.serier[$reg] = New-Serie (Select-Rader $rader @{ Region = $reg })
        }
      }

      "folkmangd_alder" {
        $senasteAr = ($rader | ForEach-Object { $_["Tid"] } | Sort-Object -Unique | Select-Object -Last 1)
        $klasser = @($rader | ForEach-Object { $_["Alder"] } | Sort-Object -Unique | Where-Object { $_ -ne "totalt" })
        # sortera femårsklasser på undre gräns
        $klasser = @($klasser | Sort-Object { if ($_ -eq "-4") { 0 } elseif ($_ -match "^(\d+)") { [int]$Matches[1] } else { 999 } })
        $pyramid = [ordered]@{ ar = $senasteAr; klasser = $klasser; man = @(); kvinnor = @() }
        foreach ($k in $klasser) {
          $pyramid.man     += @((Select-Rader $rader @{ Alder=$k; Kon="1"; Tid=$senasteAr }) | ForEach-Object { $_["varde"] })
          $pyramid.kvinnor += @((Select-Rader $rader @{ Alder=$k; Kon="2"; Tid=$senasteAr }) | ForEach-Object { $_["varde"] })
        }
        $grupper = [ordered]@{}
        foreach ($g in @("0-19","20-64","65-79","80+")) {
          $klassIGrupp = @($klasser | Where-Object { (Get-AldersGrupp $_) -eq $g })
          $grupper[$g] = New-SummeradSerie ($rader | Where-Object { $_["Kon"] -eq "1+2" -and $klassIGrupp -contains $_["Alder"] })
        }
        $innehall = [ordered]@{
          pyramid = $pyramid; grupper = $grupper
          totalt  = New-Serie (Select-Rader $rader @{ Alder="totalt"; Kon="1+2" })
        }
      }

      "befolkningsforandringar" {
        $namn = @{ "110"="folkokning"; "115"="fodda"; "130"="doda"; "135"="fodelsenetto"
                   "140"="inflyttningar"; "150"="utflyttningar"; "175"="invandringar"
                   "220"="utvandringar"; "230"="flyttnetto"; "260"="invandringsnetto" }
        $innehall = [ordered]@{ serier = [ordered]@{} }
        foreach ($kod in ($namn.Keys | Sort-Object)) {
          $innehall.serier[$namn[$kod]] = New-Serie (Select-Rader $rader @{ Forandringar = $kod })
        }
      }

      "prognos_oversikt" {
        $innehall = [ordered]@{ serier = [ordered]@{}; horisont = 2050 }
        $urval = $rader | Where-Object { [int]$_["Tid"] -le 2050 }
        foreach ($cc in $platt.Labels["ContentsCode"].Keys) {
          $nyckel = ($platt.Labels["ContentsCode"][$cc] -replace "\s+", "_").ToLower()
          $innehall.serier[$nyckel] = New-Serie (Select-Rader $urval @{ ContentsCode = $cc })
        }
      }

      "prognos_alder" {
        $urval = $rader | Where-Object { [int]$_["Tid"] -le 2050 }
        $grupper = [ordered]@{}
        foreach ($g in @("0-19","20-64","65-79","80+")) {
          $grupper[$g] = New-SummeradSerie ($urval | Where-Object { (Get-AldersGrupp $_["Alder"]) -eq $g })
        }
        $innehall = [ordered]@{ grupper = $grupper }
      }

      "medelalder" {
        $innehall = [ordered]@{ serier = [ordered]@{} }
        foreach ($reg in @($KARLSTAD, $VARMLAND, $RIKET)) {
          $innehall.serier[$reg] = New-Serie (Select-Rader $rader @{ Region = $reg })
        }
      }

      "forsorjningskvot" {
        $delNamn = @{}
        foreach ($cc in $platt.Labels["ContentsCode"].Keys) {
          $l = $platt.Labels["ContentsCode"][$cc]
          if ($l -match "totalt") { $delNamn[$cc] = "totalt" }
          elseif ($l -match "äldre") { $delNamn[$cc] = "aldre" }
          elseif ($l -match "yngre") { $delNamn[$cc] = "yngre" }
        }
        $innehall = [ordered]@{ serier = [ordered]@{} }
        foreach ($reg in @($KARLSTAD, $VARMLAND, $RIKET)) {
          $innehall.serier[$reg] = [ordered]@{}
          foreach ($cc in $delNamn.Keys) {
            $innehall.serier[$reg][$delNamn[$cc]] = New-Serie (Select-Rader $rader @{ Region=$reg; ContentsCode=$cc })
          }
        }
      }

      "bostader" {
        $innehall = [ordered]@{
          flerbostadshus = New-Serie (Select-Rader $rader @{ Hustyp = "FLERBO" })
          smahus         = New-Serie (Select-Rader $rader @{ Hustyp = "SMÅHUS" })
          totalt         = New-SummeradSerie $rader
        }
      }

      "inkomst" {
        $innehall = [ordered]@{ median = [ordered]@{}; medel = [ordered]@{} }
        foreach ($reg in @($KARLSTAD, $VARMLAND, $RIKET)) {
          $innehall.median[$reg] = [ordered]@{}
          foreach ($kon in @("1","2","1+2")) {
            $innehall.median[$reg][$kon] = New-Serie (Select-Rader $rader @{ Region=$reg; Kon=$kon; ContentsCode="HE0110J8" })
          }
          $innehall.medel[$reg] = New-Serie (Select-Rader $rader @{ Region=$reg; Kon="1+2"; ContentsCode="HE0110J7" })
        }
      }

      "utbildning" {
        # 1-2 = förgymnasial, 3-4 = gymnasial, 5-7 = eftergymnasial, US = uppgift saknas
        $nivaGrupp = @{ "1"="forgymnasial"; "2"="forgymnasial"; "3"="gymnasial"; "4"="gymnasial"
                        "5"="eftergymnasial"; "6"="eftergymnasial"; "7"="eftergymnasial"; "US"="uppgift_saknas" }
        $innehall = [ordered]@{ grupper = [ordered]@{}; totalt = [ordered]@{}; population = "25-64 år" }
        foreach ($reg in @($KARLSTAD, $VARMLAND, $RIKET)) {
          $regRader = @(Select-Rader $rader @{ Region = $reg })
          $innehall.totalt[$reg] = New-SummeradSerie $regRader
          $innehall.grupper[$reg] = [ordered]@{}
          foreach ($g in @("forgymnasial","gymnasial","eftergymnasial","uppgift_saknas")) {
            $nivaer = @($nivaGrupp.Keys | Where-Object { $nivaGrupp[$_] -eq $g })
            $innehall.grupper[$reg][$g] = New-SummeradSerie ($regRader | Where-Object { $nivaer -contains $_["UtbildningsNiva"] })
          }
        }
      }

      "arbetsmarknad" {
        $innehall = [ordered]@{ sysselsattningsgrad = [ordered]@{}; arbetsloshet = [ordered]@{}
                                population = "20-64 år (BAS, preliminär)" }
        foreach ($reg in @($KARLSTAD, $VARMLAND, $RIKET)) {
          $innehall.sysselsattningsgrad[$reg] = New-Serie (Select-Rader $rader @{ Region=$reg; NyckeltalSCB="BAS02" })
          $innehall.arbetsloshet[$reg]        = New-Serie (Select-Rader $rader @{ Region=$reg; NyckeltalSCB="BAS03" })
        }
      }

      "skattesats" {
        $innehall = [ordered]@{ total = [ordered]@{}; till_kommun = [ordered]@{} }
        foreach ($reg in @($KARLSTAD, $RIKET)) {
          $innehall.total[$reg]       = New-Serie (Select-Rader $rader @{ Region=$reg; ContentsCode="OE0101D1" })
          $innehall.till_kommun[$reg] = New-Serie (Select-Rader $rader @{ Region=$reg; ContentsCode="OE0101D2" })
        }
      }

      "omraden_befolkning" {
        # Wildcard 1780* ger kommun + DeSO + RegSO; behåll aktuella indelningar (suffix 2025)
        $arSen = @($rader | ForEach-Object { $_["Tid"] } | Sort-Object -Unique)[-1]
        $deso = [ordered]@{}; $regso = [ordered]@{}
        foreach ($g in ($rader | Where-Object { $_["Tid"] -eq $arSen } | Group-Object { $_["Region"] })) {
          $kod = $g.Name; $mal = $null; $ren = $kod
          if ($kod -like "*_DeSO2025") { $mal = $deso; $ren = $kod -replace "_DeSO2025", "" }
          elseif ($kod -like "*_RegSO2025") { $mal = $regso; $ren = $kod -replace "_RegSO2025", "" }
          if ($null -eq $mal) { continue }
          $tot = @($g.Group | Where-Object { $_["Alder"] -eq "totalt" } | ForEach-Object { $_["varde"] })[0]
          $unga = 0; $aldre = 0
          foreach ($rad in $g.Group) {
            $gr = Get-AldersGrupp $rad["Alder"]
            if ($gr -eq "0-19") { $unga += $rad["varde"] }
            elseif ($gr -in @("65-79", "80+")) { $aldre += $rad["varde"] }
          }
          if ($null -eq $tot -or $tot -eq 0) { continue }
          $mal[$ren] = [ordered]@{ totalt = $tot
                                   andel019 = [math]::Round(100 * $unga / $tot, 1)
                                   andel65  = [math]::Round(100 * $aldre / $tot, 1) }
        }
        $innehall = [ordered]@{ ar = $arSen; deso = $deso; regso = $regso }
      }

      "regso_socioek" {
        $namn = @{}
        foreach ($cc in $platt.Labels["ContentsCode"].Keys) {
          $l = $platt.Labels["ContentsCode"][$cc]
          if     ($l -match "(?i)områdestyp")            { $namn[$cc] = "omradestyp" }
          elseif ($l -match "(?i)^socioekonomiskt index"){ $namn[$cc] = "index" }
          elseif ($l -match "(?i)förgymnasial")          { $namn[$cc] = "andel_forgymnasial" }
          elseif ($l -match "(?i)ekonomisk standard")    { $namn[$cc] = "andel_lag_ek_standard" }
          elseif ($l -match "(?i)bistånd|arbetslös")     { $namn[$cc] = "andel_bistand_arbetsloshet" }
        }
        $serier = [ordered]@{}
        foreach ($g in ($rader | Where-Object { $_["Region"] -like "*_RegSO2025" } | Group-Object { $_["Region"] })) {
          $kod = $g.Name -replace "_RegSO2025", ""
          $serier[$kod] = [ordered]@{}
          foreach ($cc in $namn.Keys) {
            $serier[$kod][$namn[$cc]] = New-Serie ($g.Group | Where-Object { $_["ContentsCode"] -eq $cc })
          }
        }
        $innehall = [ordered]@{ serier = $serier
                                tolkning = "Områdestyp: 1 = stora socioekonomiska utmaningar ... 5 = mycket goda förutsättningar. Högre index = större utmaningar." }
      }
    }
    }

    $myndighet = if ($dm.Id -like "kolada_*") { "RKA (Kolada)" }
                 elseif ($null -ne $dm.PSObject.Properties["Kalla"] -and $dm.Kalla -eq "GeoSCB") { "SCB (öppna geodata)" }
                 elseif ($null -ne $dm.PSObject.Properties["Kalla"] -and $dm.Kalla -eq "Fil") { "Karlstads kommun (lokal export)" }
                 elseif ($dm.Id -like "geo_*") { "Karlstads kommun (GeoServer)" }
                 else { "SCB" }
    $licens = if ($dm.Id -like "geo_*" -or $dm.Id -like "kolada_*") { "Öppna data" } else { "CC0" }
    $curated = [ordered]@{
      id = $dm.Id; titel = $dm.Titel; beskrivning = $dm.Beskrivning; enhet = $dm.Enhet
      kalla = [ordered]@{ myndighet = $myndighet; tabell = $dm.Tabell; licens = $licens
                          hamtad = $meta.hamtad; url = $meta.url }
      innehall = $innehall
    }
    Write-Fil (Join-Path $CuratedDir ($dm.Id + ".json")) (($curated | ConvertTo-Json -Depth 12))
    Write-Host "OK ($($rader.Count) rader in)" -ForegroundColor Green
  }
}

# ---------------------------------------------------------------------------
# STEG 3: PUBLICERA (datalager -> dataprodukt) + KONTROLLER
# ---------------------------------------------------------------------------
if ($Steg -in @("alla","publicera")) {
  Write-Host "=== STEG 3: Publicerar data.js + datakatalog ===" -ForegroundColor Cyan
  $manifest = ConvertFrom-Json ([System.IO.File]::ReadAllText($ManifestFil, $Utf8Bom))

  $paket = [ordered]@{
    genererad  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    region     = [ordered]@{ kod = $KARLSTAD; namn = "Karlstad"; jamforelse = $RIKET; jamforelseNamn = "Riket" }
    dataset    = [ordered]@{}
  }
  $katalog = @()
  foreach ($dm in $Datamangder) {
    $curated = ConvertFrom-Json ([System.IO.File]::ReadAllText((Join-Path $CuratedDir ($dm.Id + ".json")), $Utf8Bom))
    $paket.dataset[$dm.Id] = $curated
    $meta = $manifest.($dm.Id)
    $myndighet = if ($dm.Id -like "kolada_*") { "RKA (Kolada)" }
                 elseif ($null -ne $dm.PSObject.Properties["Kalla"] -and $dm.Kalla -eq "GeoSCB") { "SCB (öppna geodata)" }
                 elseif ($null -ne $dm.PSObject.Properties["Kalla"] -and $dm.Kalla -eq "Fil") { "Karlstads kommun (lokal export)" }
                 elseif ($dm.Id -like "geo_*") { "Karlstads kommun (GeoServer)" }
                 else { "SCB" }
    $katalog += [ordered]@{
      id = $dm.Id; titel = $dm.Titel; beskrivning = $dm.Beskrivning; enhet = $dm.Enhet
      kallmyndighet = $myndighet
      tabell = $dm.Tabell
      licens = $(if ($dm.Id -like "kolada_*" -or $dm.Id -like "geo_*") { "Öppna data" } else { "CC0 (öppna data)" })
      uppdateras = $dm.Uppdateras; hamtad = $meta.hamtad; url = $meta.url
      rafil = "data/raw/$($dm.Id).json"; kureradFil = "data/curated/$($dm.Id).json"
    }
  }
  $paket["katalog"] = $katalog

  Write-Fil (Join-Path $Rot "data\datakatalog.json") (($katalog | ConvertTo-Json -Depth 6))
  $js = "// Genererad av pipeline\hamta-scb-data.ps1 - redigera INTE för hand.`n" +
        "window.KARLSTAD_DATA = " + ($paket | ConvertTo-Json -Depth 14 -Compress) + ";`n"
  Write-Fil (Join-Path $AppDir "data.js") $js
  Write-Host ("  app\data.js: {0:N0} kB" -f ((Get-Item (Join-Path $AppDir "data.js")).Length / 1kb))

  # --- Avstämningskontroller: samma storhet från OBEROENDE tabeller ska stämma överens ---
  Write-Host "=== KONTROLLER ===" -ForegroundColor Cyan
  $bef  = $paket.dataset["befolkning_lang"].innehall.serier.$KARLSTAD
  $ald  = $paket.dataset["folkmangd_alder"].innehall.totalt
  $i638 = [array]::IndexOf($bef.ar, "2024"); $i6574 = [array]::IndexOf($ald.ar, "2024")
  $v1 = $bef.varde[$i638]; $v2 = $ald.varde[$i6574]
  Write-Host ("  Folkmängd 2024: TAB638={0}  TAB6574={1}  ->  {2}" -f $v1, $v2, $(if ($v1 -eq $v2) { "OK" } else { "AVVIKELSE!" }))

  $fkv = $paket.dataset["forsorjningskvot"].innehall.serier.$KARLSTAD.totalt
  $sen = $fkv.varde[$fkv.varde.Count - 1]
  Write-Host ("  Försörjningskvot {0}: {1} (rimligt intervall 0,6-1,0)" -f $fkv.ar[$fkv.ar.Count - 1], $sen)

  $prog = $paket.dataset["prognos_oversikt"].innehall.serier
  if ($prog.folkmangd) {
    $p0 = $prog.folkmangd.varde[0]
    Write-Host ("  Prognos folkmängd {0}: {1} (jfr utfall 2024: {2})" -f $prog.folkmangd.ar[0], $p0, $v1)
  }

  $kres = $paket.dataset["kolada_resultat"].innehall.serier.$KARLSTAD
  if ($kres.ar.Count -gt 0) {
    Write-Host ("  Kolada N03102 Karlstad {0}: {1} % ({2} år i serien)" -f $kres.ar[$kres.ar.Count-1], $kres.varde[$kres.varde.Count-1], $kres.ar.Count)
  } else {
    Write-Host "  VARNING: Kolada-serien för Karlstad är tom!" -ForegroundColor Yellow
  }

  # --- AI-kontext: datakatalogen som "systemdokumentation" för LLM-användning ---
  # Gör datalagret användbart som underlag för en AI-assistent (Lovable, AI Studio,
  # Claude m.fl.) utan att modellen hittar på siffror. Se docs\PUBLICERING-OCH-AI.md.
  $aiDir = Join-Path $Rot "ai"
  if (-not (Test-Path $aiDir)) { New-Item -ItemType Directory -Path $aiDir | Out-Null }
  $arb = $paket.dataset["arbetsmarknad"].innehall.arbetsloshet.$KARLSTAD
  $L = New-Object System.Collections.Generic.List[string]
  $L.Add("# AI-kontext: Karlstad-analys")
  $L.Add("")
  $L.Add("> Genererad automatiskt av pipeline\hamta-scb-data.ps1 $($paket.genererad). Redigera inte för hand.")
  $L.Add("> Ge denna fil (och vid behov data/curated/*.json) som kontext till en AI-assistent.")
  $L.Add("")
  $L.Add("## Instruktion till AI-assistenten")
  $L.Add("")
  $L.Add("Du hjälper till att analysera öppna data om **Karlstads kommun** (kommunkod 1780).")
  $L.Add("Regler som INTE får brytas:")
  $L.Add("")
  $L.Add("1. Svara enbart utifrån serierna i detta datalager (data/curated/ eller app/data.js). Hitta aldrig på värden.")
  $L.Add("2. Ange källa (tabell-/KPI-id) och årtal för varje siffra du använder.")
  $L.Add("3. Skilj utfall från framskrivning: datamängder med id prognos_* är modellvärden, inte observationer.")
  $L.Add("4. All data avser Karlstads kommun, inte tätorten Karlstad.")
  $L.Add("5. Kan frågan inte besvaras ur datamängderna nedan: säg det uttryckligen och föreslå vilken källa som saknas.")
  $L.Add("6. Nyckeltalsdefinitioner finns i docs/NYCKELTALSKATALOG.md - använd dem, uppfinn inga egna.")
  $L.Add("7. Inkomster är i löpande priser; BAS-arbetsmarknadsstatistiken är preliminär. Nämn förbehållen när de är relevanta.")
  $L.Add("")
  $L.Add("## Snabbfakta (senaste värden vid genereringen)")
  $L.Add("")
  $L.Add("- Folkmängd $($ald.ar[$ald.ar.Count-1]): $($ald.varde[$ald.varde.Count-1]) (TAB6574)")
  $L.Add("- Demografisk försörjningskvot $($fkv.ar[$fkv.ar.Count-1]): $sen (TAB4642)")
  $L.Add("- Arbetslöshet 20-64 $($arb.ar[$arb.ar.Count-1]): $($arb.varde[$arb.varde.Count-1]) % (TAB5663, preliminär)")
  $L.Add("- Resultatandel av skatt $($kres.ar[$kres.ar.Count-1]): $([math]::Round($kres.varde[$kres.varde.Count-1],1)) % (Kolada N03102)")
  $L.Add("- Jämförelsegrupp (Kolada G37421): $(@($JamforKommuner.Values | Where-Object { $_ -ne 'Karlstad' }) -join ', ')")
  $L.Add("")
  $L.Add("## Datamängder (systemdokumentation)")
  $L.Add("")
  $L.Add("| id | innehåll | enhet | källa | hämtad | maskinläsbar fil |")
  $L.Add("|---|---|---|---|---|---|")
  foreach ($k in $katalog) {
    $L.Add("| $($k.id) | $($k.titel). $($k.beskrivning) | $($k.enhet) | $($k.kallmyndighet) $($k.tabell) | $($k.hamtad.Substring(0,10)) | $($k.kureradFil) |")
  }
  $L.Add("")
  $L.Add("## Dataformat")
  $L.Add("")
  $L.Add('- Varje kurerad fil: { id, titel, enhet, kalla{tabell, url, hamtad}, innehall{...} }')
  $L.Add('- Tidsserieformat: { "ar": ["2000", ...], "varde": [73.4, ...] } - index i ar och varde hör ihop.')
  $L.Add('- app/data.js innehåller allt samlat: window.KARLSTAD_DATA = { region, dataset{<id>}, katalog }.')
  $L.Add("- Vid statisk hosting är data/curated/<id>.json direkta HTTPS-endpoints (de facto öppet API).")
  Write-Fil (Join-Path $aiDir "AI-KONTEXT.md") (($L -join "`n") + "`n")
  Write-Host ("  ai\AI-KONTEXT.md genererad ({0} datamängder)" -f $katalog.Count)
  Write-Host "KLART." -ForegroundColor Green
}
