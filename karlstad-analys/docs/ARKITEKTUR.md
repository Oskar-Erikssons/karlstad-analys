# Arkitektur

## Princip: lager med tydliga kontrakt

Arkitekturen följer samma mönster som ett datalager i full skala (jfr medaljongarkitektur
brons/silver/guld), medvetet nedskalat till filer i mappar. Poängen är att **mönstret** är
detsamma oavsett om tekniken är PowerShell + JSON eller en molnplattform — det gör
projektet användbart som pedagogiskt exempel.

```
┌─────────────┐   ┌──────────────────┐   ┌───────────────────┐   ┌──────────────────┐
│  KÄLLSYSTEM │   │  LANDNINGSZON    │   │  DATALAGER        │   │  DATAPRODUKT     │
│  SCB        │ → │  data/raw/       │ → │  data/curated/    │ → │  app/index.html  │
│  PxWebAPI   │   │  oförändrad      │   │  tvättade serier, │   │  + data.js       │
│  (json-stat2)│  │  rådata+manifest │   │  gem. dimensioner │   │  (visualisering, │
└─────────────┘   └──────────────────┘   └───────────────────┘   │  analys, regler) │
                                                                  └──────────────────┘
```

### 1. Källor — SCB PxWebAPI v2 + Kolada v3

**SCB** (`https://api.scb.se/OV0104/v2beta/api/v2/`):
- Tabellsökning: `/tables?query=...` · Metadata: `/tables/{id}/metadata` · Data: `/tables/{id}/data?valueCodes[Dim]=...`
- Format: **json-stat2** — självbeskrivande (dimensioner, koder, klartextetiketter följer med).
- Karlstads kommunkod: **1780**; riket: **00**. Obligatoriska dimensioner måste anges
  explicit (wildcard `*` eller kodlista); dimensioner med eliminering kan utelämnas och
  summeras då av API:et.

**Kolada/RKA** (`https://api.kolada.se/v3/` — v2 är nedlagt):
- Data: `/data/kpi/{kpi-id}/municipality/{kommaseparerade koder}` — eget JSON-format
  (inte json-stat2), kön `"T"` = totalt.
- Jämförelsegruppen är RKA:s officiella *"Liknande kommuner, övergripande, Karlstad, 2025"*
  (grupp G37421) — strukturellt lika kommuner, inte grannar.
- Kolada skickar ingen charset-header → råbytes avkodas alltid explicit som UTF-8.

**Karlstads kommun GeoServer** (`https://gi.karlstad.se/geoserver/oppnadata/wfs`):
- WFS GetFeature med `outputFormat=application/json&srsName=EPSG:4326` ger GeoJSON i
  WGS84 (originaldata är SWEREF99 TM — begär alltid omprojicering).
- Fem lager i drift: stadsdelar, lekplatser, parker, lediga tomter, pågående detaljplaner.
  Transformeringen gallrar attribut och avrundar koordinater till 5 decimaler (~1 m).

Att lägga till Kolada kostade: sex poster i datamängdskatalogen, en URL-gren i
hämtsteget och en formatgren i transformeringen. GeoServer kostade detsamma (fem poster,
en URL-gren, en formatgren). Landningszon, manifest, katalog och publicering återanvändes
oförändrade båda gångerna — det är lagerarkitekturens poäng.

### 2. Landningszon (`data/raw/`)

- Varje API-svar sparas **oförändrat**. Regeln är absolut: rådata skrivs aldrig om i
  efterhand. Det ger reproducerbarhet (transformeringen kan göras om och förbättras utan
  nya API-anrop) och spårbarhet (varje siffra i dashboarden kan följas hit).
- `_manifest.json` loggar URL, tidsstämpel och antal värden per hämtning — landningszonens
  motsvarighet till lastlogg.

### 3. Datalager (`data/curated/`)

- json-stat2 plattas ut till rader och aggregeras till **analysfärdiga tidsserier** med
  gemensamma dimensioner: region (kommunkod) och tid (år/månad). Gemensamma dimensioner är
  det som gör att datamängder från olika ämnesområden kan kombineras.
- Kornighet väljs per beslutsbehov, inte per källa: t.ex. aggregeras utbildningsdatan
  (23 040 råvärden: region × nivå × 1-årsålder × kön × år) till 144 kurerade värden
  (region × nivågrupp × år) — dashboarden behöver inte mer, och rådatan finns kvar om
  behovet ändras.
- Varje kurerad fil bär sin egen metadata: källa, tabell, licens, hämtningstidpunkt, enhet.

### 4. Dataprodukt (`app/`)

- `data.js` = hela datalagret + datakatalogen som ett JS-objekt (`window.KARLSTAD_DATA`).
  Genererad fil — ändras aldrig för hand.
- `index.html` är helt fristående: egen SVG-diagrammotor (inga CDN-beroenden → fungerar
  offline, inga versionsrisker), designtokens, mörkt läge, svensk talformatering.
- **Beräkningarna görs i webbläsaren** (trendlinjer, kvoter, insiktsregler) och kan
  granskas i källkoden. Designval: transparens före prestanda — hela poängen med
  beslutsstöd är att varje siffra kan härledas.

## Kontroller

Pipelinen kör avstämningar vid publicering, bl.a. att folkmängden 2024 är identisk i två
oberoende SCB-tabeller (TAB638 och TAB6574: 98 084 = 98 084) och att försörjningskvoten
ligger i rimligt intervall. Principen: **stäm alltid av minst en huvudsiffra mot en
oberoende källa** innan något publiceras.

## Designval och avvägningar

| Val | Motiv | Pris |
|---|---|---|
| PowerShell-pipeline | Enda garanterade runtime på måldatorn; reproducerbar | Mindre ekosystem än Python |
| Filbaserat "datalager" | Noll infrastruktur, versionerbart, begripligt | Skalar inte till stora datamängder |
| Data inbäddad i data.js | Fungerar via file:// utan server (CORS-fritt) | Data fryses vid publicering; ~40 kB |
| Egen SVG-diagrammotor | Inga beroenden, full kontroll, offline | Mer kod än Chart.js |
| Beräkningar i klienten | Granskningsbarhet, förklarbarhet | Duplicering om fler frontends byggs |

## Vägar framåt

1. ~~Kolada (jämförkommuner)~~ och ~~Karlstads GeoServer (geodata)~~ — **genomförda**.
   Identifierade nästa datamängder (se även docs/PUBLICERING-OCH-AI.md §3):
   **SCB DeSO-statistik** (befolkning per delområde via TAB6574 — ger per capita-mått i
   kartvyn), återstående GeoServer-lager (cykelleder, elljusspår, motionsspår, gällande
   detaljplaner), **Arbetsförmedlingen/JobTech** (`jobtechdev.se`) samt Koladas
   verksamhetsspecifika jämförelsegrupper. En ny källa = en post i pipelinens
   datamängdskatalog + ev. en URL-/formatgren. Recepten: skillen
   `fetching-swedish-open-data`.
2. **Schemaläggning**: pipelinen kan köras via Schemalagda aktiviteter i Windows
   (kör `uppdatera-data.cmd`); uppdateringsfrekvensen per källa står i datakatalogen och
   dashboardens datastatus-vy visar när det är dags.
3. ~~Publicering~~ — **förberett**: se `docs/PUBLICERING-OCH-AI.md`; statisk hosting gör
   `data/curated/*.json` till öppna HTTPS-endpoints (Lovable, AI Studio, m.fl.).
4. ~~AI-stöd~~ — **genomfört**: `ai/AI-KONTEXT.md` genereras vid varje publicering
   (ärlighetsregler + snabbfakta + katalog + dataformat). Se `docs/PUBLICERING-OCH-AI.md`.
