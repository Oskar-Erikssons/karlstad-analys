# Karlstad i siffror — beslutsstöd på öppna data

En fristående dashboard om Karlstads kommun byggd på öppna data från SCB, med beskrivande,
prediktiv och preskriptiv analys. Byggd som ett komplett men litet exempel på hur man går
från öppna data till beslutsstöd med spårbarhet i varje led.

## Snabbstart

Öppna **`app/index.html`** i valfri webbläsare. Klart — inga installationer, ingen server,
inga externa beroenden. Fungerar offline och i mörkt läge.

Uppdatera data (kräver internet): **dubbelklicka på `uppdatera-data.cmd`**, eller kör

```powershell
powershell -ExecutionPolicy Bypass -File pipeline\hamta-scb-data.ps1
```

Ladda sedan om sidan. Statuskolumnen under *Om data & metod* i dashboarden visar när
respektive datamängd är dags att uppdatera.

## Struktur

```
karlstad-analys/
├── app/
│   ├── index.html          Dashboarden (all logik, granskningsbar)
│   └── data.js             Genererad datafil — redigera inte för hand
├── pipeline/
│   └── hamta-scb-data.ps1  Datapipeline: hämta → transformera → publicera
├── uppdatera-data.cmd      Enklicksuppdatering (kör pipelinen)
├── data/
│   ├── raw/                Landningszon: oförändrade källsvar + _manifest.json
│   ├── curated/            Datalager: tvättade, analysfärdiga serier (JSON)
│   └── datakatalog.json    Metadata om alla datamängder
├── ai/
│   └── AI-KONTEXT.md       Genererad AI-systemkontext (håller en LLM ärlig)
└── docs/
    ├── ARKITEKTUR.md            Lagerarkitektur och designval
    ├── INFORMATIONSMODELL.md    Begrepps- och informationsmodell
    ├── NYCKELTALSKATALOG.md     Definition av varje nyckeltal
    ├── PUBLICERING-OCH-AI.md    Statisk hosting som öppet API + AI-användning
    └── PROCESS-OCH-LARDOMAR.md  Hur applikationen byggdes + lärdomar
```

## Innehåll i dashboarden

| Sektion | Frågan den besvarar |
|---|---|
| Översikt | Hur ligger Karlstad till — nivå, trend, jämfört med riket? |
| Befolkning | Hur och varför växer kommunen? |
| Demografisk framtid | Vad händer med försörjningskvot och äldre till 2050? (prediktiv) |
| Simulering | Vad händer om flyttnetto/byggtakt ändras? (interaktivt scenarioverktyg) |
| Arbete & inkomst | Hur mår arbetsmarknaden och inkomsterna? |
| Utbildning | Hur står sig kompetensbasen? |
| Bostäder | Matchar byggtakten tillväxten? |
| Karta | Tre geografier: stadsdelar (utbud), DeSO (demografi), RegSO (socioekonomiskt index). SVG offline + interaktiv Leaflet-karta (OSM/Karlstads baskarta). Koordinater i SWEREF 99 TM och WGS 84 |
| Jämförelser | Hur står sig Karlstad mot RKA:s "liknande kommuner"? (Kolada) + Värmland i länsjämförbara diagram |
| Insikter | Vad bör prioriteras? (regelbaserat, öppet redovisade regler) |
| Min data | Lägg till egna tidsserier och platser (CSV, SWEREF/WGS84) — lagras lokalt |
| Rapport | Bygg egna rapportmallar (dra-och-släpp block + textkommentarer) och skriv ut |
| Om data & metod | Varifrån kommer varje siffra? (datakatalog + datastatus + förbehåll) |

Dessutom: **inställningar** (ljust/mörkt läge, grafiska profiler inkl. egna färger),
**export** av varje diagram (SVG/PNG) och tabell (CSV), och utskrift av hela lägesbilden.

## Vidareutveckling

Strukturen är byggd för att växa — Kolada lades till som andra källa med en post per
KPI i pipelinens datamängdskatalog plus en URL-gren, vilket bevisar mönstret:

- **Fler datakällor**: nästa kandidater är Karlstads GeoServer (kartlager, WFS/GeoJSON)
  och Arbetsförmedlingen/JobTech. Recepten finns i skillen `fetching-swedish-open-data`
  och i `docs/PUBLICERING-OCH-AI.md`.
- **Publicering som öppet API**: statisk hosting (GitHub Pages o.likn.) räcker —
  `data/curated/*.json` blir HTTPS-endpoints för andra applikationer (Lovable, AI Studio
  m.fl.). Steg-för-steg i `docs/PUBLICERING-OCH-AI.md`.
- **AI-stöd**: `ai/AI-KONTEXT.md` genereras vid varje pipelinekörning och gör att en
  LLM kan kommentera och svara på frågor om datan utan att hitta på siffror —
  datakatalogen fungerar som systemdokumentation med ärlighetsregler.

## Licens och källor

Statistik: © SCB (öppna data, **CC0**) via PxWebAPI v2, © RKA (**Kolada**, öppna data)
via Kolada API v3, samt geodata © **Karlstads kommun** (öppna data) via GeoServer WFS.
Se `data/datakatalog.json` för exakta tabeller/KPI:er/lager, frågor och hämtningsdatum.
