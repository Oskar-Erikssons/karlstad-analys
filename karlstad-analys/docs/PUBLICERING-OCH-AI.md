# Publicering och AI-stöd

Hur datalagret blir (1) ett öppet API för andra applikationer och (2) ett ärligt
kunskapsunderlag för AI-assistenter. Båda bygger på samma princip: **filerna i
`data/curated/` + datakatalogen är kontraktet** — dashboarden är bara den första
konsumenten.

## 1. Publicering: statisk hosting räcker

Projektet innehåller inga hemligheter (all data är redan öppna data från SCB/RKA/kommunen)
och ingen serverkod — `app/index.html` + `app/data.js` är hela applikationen. Därför räcker
statisk filhosting, och mappen kan publiceras **precis som den är**.

### Alternativ A: GitHub Pages — utan att kunna git (via webbläsaren)

1. Skapa konto på github.com → **New repository** → namn `karlstad-analys`, Public → Create.
2. Klicka **uploading an existing file** och dra in hela innehållet i `karlstad-analys\`-
   mappen (undermappar följer med om du drar in dem mapp för mapp: `app`, `data`, `docs`,
   `ai`, `pipeline` + filerna i roten). Commit changes.
3. **Settings → Pages → Source: Deploy from a branch → main / (root) → Save.**
4. Efter någon minut är sidan live på
   `https://<konto>.github.io/karlstad-analys/app/` — dela länken.
5. Uppdatering senare: kör `uppdatera-data.cmd` lokalt och ladda upp nya
   `app/data.js` + `data/`-mappen igen (ersätt filerna).

### Alternativ A2: GitHub Pages — med git (repeterbart)

```powershell
cd karlstad-analys
git init
git add .
git commit -m "Karlstad-analys: beslutsstöd på öppna data"
# skapa repo på github.com, sedan:
git remote add origin https://github.com/<konto>/karlstad-analys.git
git push -u origin main
# Aktivera Pages: repo → Settings → Pages → Source: main, / (root)
# Vid datauppdatering: .\uppdatera-data.cmd ; git add -A ; git commit -m "Ny data" ; git push
```

### Alternativ B: egen hemsida / webbhotell

Fungerar på vilket webbhotell eller egen webbserver som helst (Loopia, One.com, Binero,
IIS, nginx, Apache …):

1. Kopiera upp **hela** `karlstad-analys\`-mappen via FTP/filhanterare till t.ex.
   `public_html/karlstad-analys/`. Behåll mappstrukturen — `index.html` läser `data.js`
   med relativ sökväg.
2. Klart: `https://dindomän.se/karlstad-analys/app/`. Vill du ha den på roten: lägg
   `app/index.html` + `app/data.js` direkt i `public_html/` (de två filerna räcker för
   själva dashboarden; `data/` behövs bara om andra appar ska läsa JSON-endpointsen).
3. Krav på servern: kunna servera statiska filer — inget mer. Kontrollera att `.json`
   får MIME-typ `application/json` (standard nästan överallt) och använd HTTPS.
4. **CORS**: vill du att *andra* webbappar (Lovable m.fl.) ska läsa dina JSON-filer,
   lägg till svarshuvudet `Access-Control-Allow-Origin: *` för `/data/` (Apache:
   `.htaccess` med `Header set Access-Control-Allow-Origin "*"`; på GitHub Pages ingår
   det automatiskt). För enbart dashboarden behövs inget CORS.
5. Intranät funkar lika bra: lägg mappen på en filserver/intranätswebb — dashboarden
   fungerar även via `file://` utan webbserver alls.

Att tänka på oavsett alternativ: allt som publiceras här är redan offentlig statistik,
men lägg inte till egna verksamhetsdata i `data/` före sekretess-/GDPR-prövning, och
låt källhänvisningarna (SCB CC0, Kolada/RKA, Karlstads kommun) stå kvar i sidfoten.

Efter publicering blir strukturen ett **de facto öppet API**:

| URL | Innehåll |
|---|---|
| `https://<konto>.github.io/karlstad-analys/app/` | Dashboarden |
| `.../data/curated/forsorjningskvot.json` | Enskild datamängd (JSON-endpoint) |
| `.../data/datakatalog.json` | Maskinläsbar katalog över alla endpoints |
| `.../ai/AI-KONTEXT.md` | Färdig AI-systemkontext |

GitHub Pages skickar `Access-Control-Allow-Origin: *`, så filerna kan hämtas med `fetch()`
från vilken webbapplikation som helst (Lovable, AI Studio-byggda appar, m.fl.):

```js
const svar = await fetch("https://<konto>.github.io/karlstad-analys/data/datakatalog.json");
const katalog = await svar.json();   // upptäck datamängder programmatiskt
```

- Alternativ med samma egenskaper: Cloudflare Pages, Netlify, Azure Static Web Apps.
- **Innan publicering av nya källor**: allt här är redan publik nationalstatistik, men om
  egna verksamhetsdata läggs till i pipelinen krävs sekretess- och GDPR-prövning *före*
  publicering (se skillen governing-data-and-information — ordningen är prövning →
  kvalitetsdeklaration → publicering).

## 2. AI-stöd: datakatalogen håller modellen ärlig

Pipelinen genererar **`ai/AI-KONTEXT.md`** vid varje publicering. Filen innehåller:

1. **Regler** för assistenten (svara bara ur datalagret, ange källa+årtal, skilj utfall
   från framskrivning, säg till när svaret inte finns i datan).
2. **Snabbfakta** med senaste värden — förankrar modellen i färska tal.
3. **Datakatalogen** som tabell — assistentens "systemdokumentation": vad som finns,
   varifrån, hur färskt, och var filen ligger.
4. **Dataformatbeskrivning** så att modellen kan läsa de kurerade JSON-filerna korrekt.

### Användningsrecept

- **Fråga–svar**: ge AI-KONTEXT.md + relevanta `data/curated/*.json` som kontext och
  ställ frågan ("Hur har flyttnettot utvecklats sedan 2015, och vad betyder det för
  bostadsplaneringen?").
- **Kommenterande analys**: "Skriv en tjänstemannakommentar (max 300 ord) om
  försörjningskvotens utveckling, med källhänvisningar enligt reglerna i kontexten."
- **Bygga vidare i Lovable/AI Studio**: klistra in AI-KONTEXT.md i projektets
  systemprompt och låt appen hämta data via de publicerade JSON-endpointsen — då delar
  människa, app och AI samma definitioner.

### Varför detta fungerar (och var det brister)

En LLM utan förankring gissar gärna trovärdiga siffror. Kontextfilen motverkar det på tre
sätt: den ger färska fakta (modellens träningsdata är inaktuell), den kräver källhänvisning
per siffra (gör påhitt synliga och granskningsbara), och den definierar vad som *inte*
finns (regel 5 tvingar fram "det vet jag inte" i stället för en gissning).

Kvarstående risker att hantera: modellen kan räkna fel på serierna (be om beräkningssteg),
och den kan missa förbehåll (därför ligger de i katalogtexterna). **Stickprova alltid
AI-genererade siffror mot dashboarden eller de kurerade filerna innan de används i ett
beslutsunderlag** — samma regel som för mänskliga sammanställningar.

## 3. Nya källor — förberedd väg in

En ny källa = en post i `$Datamangder` i pipelinescriptet (+ en URL-/formatgren om källan
har nytt API-format — så gjordes för både Kolada och GeoServer).

**Genomfört:** Karlstads GeoServer (WFS) med fem lager: stadsdelar, lekplatser, parker,
lediga tomter, pågående detaljplaner.

**Identifierade datamängder, prioriterade efter bedömd nytta:**

| Datamängd | Källa | Värde | Insats |
|---|---|---|---|
| Befolkning per DeSO (delområde) | SCB TAB6574 (Region-dimensionen innehåller DeSO-koder som `1780A0010_DeSO2025`) + DeSO-gränser | Per capita-mått i kartvyn — dagens största analytiska lucka | Medel (kräver DeSO-polygoner) |
| Gällande detaljplaner, cykelleder, elljusspår, motionsspår | Karlstads GeoServer (samma WFS, verifierade lager) | Fler kartlager; friluftsliv/folkhälsa-vinkel | Låg (mönstret finns) |
| Lediga jobb & annonshistorik | Arbetsförmedlingen/JobTech (`jobtechdev.se`) | Efterfrågesidan av arbetsmarknaden (BAS visar utbudssidan) | Medel (otestat API) |
| Verksamhetsspecifika jämförelsegrupper | Kolada `municipality_groups` (grundskola, äldreomsorg, socioekonomi ...) | Skarpare jämförelser per sektor än "övergripande" | Låg |
| Väder/klimatdata | SMHI öppna data (metobs-API) | Koppling energi/klimatanpassning | Medel |
| Fler kommunkatalogiserade datamängder | dataportal.se (DIGG, DCAT-AP-SE) — sök "Karlstad" | Upptäcktskanal snarare än källa | Låg |

Recepten i detalj finns i skillen `fetching-swedish-open-data` (~/.claude/skills) så att
de överlever detta projekt.

## 4. Guide: ta projektet vidare till Lovable eller Google AI Studio

Grundprincipen: **datalagret är kontraktet, inte dashboarden.** En ny app byggd i något av
verktygen ska konsumera samma kurerade JSON — då delar alla vyer definitioner och
uppdateringsflöde.

### Steg 0 (gemensamt): publicera datat

Följ §1 (GitHub Pages). Efter det finns allt som HTTPS-endpoints med CORS öppet:
`.../data/datakatalog.json` (upptäckt), `.../data/curated/<id>.json` (innehåll),
`.../ai/AI-KONTEXT.md` (regler + definitioner).

### Alternativ A: Lovable (bygga ny app-yta)

1. Skapa ett projekt och klistra in innehållet i `ai/AI-KONTEXT.md` som första prompt,
   följt av: *"Bygg en [vy] som hämtar data från https://<konto>.github.io/karlstad-analys/data/curated/
   enligt katalogen. Serieformatet är { ar: [...], varde: [...] }."*
2. Be den börja med EN vy mot EN datamängd (t.ex. `forsorjningskvot.json`) och verifiera
   siffrorna mot dashboarden innan fler läggs till — samma baseline-princip som i analys.
3. Låt aldrig Lovable-appen transformera rådata själv — behöver den nya aggregat är rätt
   väg en ny post i pipelinens datamängdskatalog, så att alla konsumenter får samma siffror.

### Alternativ B: Google AI Studio (analys-/promptarbete eller appbygge)

1. **Som kunskapskälla:** ladda upp `ai/AI-KONTEXT.md` + relevanta `data/curated/*.json`
   som filer i prompten (eller System Instructions = AI-KONTEXT:ens regelavsnitt). Ställ
   analysfrågor; kräv källhänvisning per siffra (regel 2).
2. **Som appbygge (Build-läget):** samma mönster som Lovable — peka appen mot de
   publicerade JSON-endpointsen och ge AI-KONTEXT.md som systemkontext.
3. Detta projekt ligger f.ö. i en AI Studio-exportmapp — `karlstad-analys/` är fristående
   och kan zippas/flyttas som helhet.

### Checklista före delning

- [ ] Publicerade endpoints svarar (öppna datakatalog.json i webbläsaren)
- [ ] AI-KONTEXT.md är nygenererad (kör pipelinen först)
- [ ] Stickprov: 2–3 siffror i den nya appen mot dashboarden
- [ ] Källhänvisning + licenstext (SCB CC0, Kolada/RKA, Karlstads kommun) syns i nya appen
