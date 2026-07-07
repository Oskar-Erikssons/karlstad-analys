# Process och lärdomar

Hur applikationen byggdes, steg för steg, med de avvägningar och misstag som hör till.
Skriven för att processen ska gå att återanvända — och för att den speglar arbetsuppgifterna
i rollen *leveransområdesansvarig data och analysstöd*.

## Processen i sju steg

### 1. Börja i besluten, inte i datan
Första frågan var inte "vilken data finns?" utan "vilka beslut fattar en kommun som data
kan förbättra?" — lokalplanering (demografi), äldreomsorgsdimensionering (80+),
bostadsförsörjning (byggtakt vs tillväxt), kompetensförsörjning (utbildning, flyttnetto).
Varje dashboard-sektion svarar mot en beslutssituation. Utan detta steg blir resultatet en
sifferkyrkogård.

### 2. Inventera källor och testa API:et tidigt
SCB:s PxWebAPI v2 utforskades med små sökanrop (`/tables?query=`) och metadataanrop innan
någon arkitektur låstes. **Lärdom:** en timmes API-utforskning avslöjade både guldkorn
(SCB:s regionala befolkningsframskrivning per ålder, TAB698 — grunden för hela den
prediktiva delen) och fällor (tabellen för medelålder per NUTS2-region ser identisk ut med
kommuntabellen i sökresultaten; bara metadatakollen av regiondimensionen avslöjade det).

### 3. Arkitektur med lager och kontrakt
Källa → landningszon (oförändrad rådata) → datalager (kurerade serier, gemensamma
dimensioner) → dataprodukt. Se ARKITEKTUR.md. **Lärdom:** mönstret kostar nästan inget
extra att följa även i ett litet projekt, och betalar sig omedelbart — transformeringen
fick göras om två gånger och rådatan behövde aldrig hämtas igen.

### 4. Definiera innan du visar
Nyckeltalen dokumenterades i NYCKELTALSKATALOG.md med täljare/nämnare/population/källa
innan de renderades. Begreppen (kommun ≠ tätort, framskrivning ≠ prognos, demografisk ≠
ekonomisk försörjningskvot, median ≠ medel) i INFORMATIONSMODELL.md. **Lärdom:** flera
definitionsval påverkade siffrorna direkt — t.ex. population 25–64 för utbildningsnivå
(annars räknas studenter som lågutbildade) och "uppgift saknas" i nämnaren.

### 5. Kontrollera mot oberoende källa
Folkmängden stäms av mellan två oberoende SCB-tabeller vid varje pipelinekörning
(98 084 = 98 084 för 2024). Komponentsumman (födelsenetto + flyttnetto = 857) jämfördes
mot folkökningen (851) — avvikelsen visade sig vara SCB:s justeringspost och blev ett
dokumenterat förbehåll i stället för ett tyst fel. **Lärdom:** avstämningen tog fem
minuter och gav både trygghet och ett ärligt förbehåll.

### 6. Prediktivt med baslinje, preskriptivt med öppna regler
- Analystrappan respekterades: beskrivande (utfall) → diagnostisk (komponenter, jämförelser)
  → prediktiv (framskrivningar) → preskriptiv (regelbaserade insikter).
- **Baslinje först:** en enkel linjär trend redovisas *bredvid* SCB:s officiella
  framskrivning. Att de ger olika år för 100 000-milstolpen (2027 resp. 2029) redovisas
  öppet — spridningen är osäkerhetsmåttet. En avancerad modell som inte slår baslinjen
  är inte värd sin förvaltningskostnad.
- **Preskriptivt = regler, inte orakel:** varje insiktskort visar sin regel och beräkning
  ("Visa regel & beräkning"). Underlag för prioritering, aldrig automatiska beslut —
  beslut som rör individer kräver mänsklig prövning (jfr EU:s AI-förordning).

### 7. Verifiera och dokumentera
Dashboarden verifierades i headless Chrome (konsollfel, DOM-innehåll, skärmbilder,
responsivitet) innan den betraktades som klar. Dokumentationen skrevs som en del av
leveransen, inte efteråt.

## Tekniska lärdomar (för återanvändning)

1. **SCB PxWebAPI v2**: obligatoriska dimensioner måste anges (`valueCodes[Dim]=*` funkar);
   dimensioner med eliminering kan utelämnas och summeras då automatiskt. `from(år)` för
   öppna tidsintervall. json-stat2-värden ligger i radordning — sista dimensionen varierar
   snabbast.
2. **PowerShell 5.1-fällor**: `Measure-Object -Property x` läser inte hashtable-nycklar
   (summera via `ForEach-Object` i stället); `.ps1`-filer med åäö kräver UTF-8 **med BOM**;
   stderr-redirect på externa program strular — kör via `cmd /c` med filredirect.
3. **Verifieringsverktyg har egna buggar**: headless Chrome på Windows har en minsta
   fönsterbredd (~480 px) — "mobilvyn ser trasig ut" var en beskuren skärmbild, inte ett
   CSS-fel. Kontrollerades genom att mäta en tom sida: skilj verktygsartefakt från verklig
   defekt innan du "lagar" något.
4. **Fristående HTML som leveransformat**: data inbäddad i en genererad `data.js` +
   egenritad SVG ger noll beroenden, offline-funktion och full granskbarhet — rätt format
   när mottagarmiljön är okänd.

## Iteration 2: Kolada, datastatus, publicering och AI-stöd

Efter första leveransen byggdes fyra saker till — i prioritetsordning efter bedömd nytta:

1. **Kolada som andra källa** (jämförelser med liknande kommuner). Viktigaste valet:
   RKA:s *officiella* jämförelsegrupp (Kolada G37421) i stället för självvalda kommuner —
   det tar bort misstanken om körsbärsplockade jämförelser. Sex KPI:er över ekonomi,
   skola och äldreomsorg gav direkt ny insikt: Karlstad driver verksamheten nästan exakt
   till strukturkostnad (nettokostnadsavvikelse +0,6 %, 2:a av 8) men ligger 6:e av 8 på
   brukarnöjdhet i hemtjänsten — kostnadseffektivitet och kvalitet måste läsas ihop.
2. **Datastatus-vy + enklicksuppdatering**: dashboarden jämför varje datamängds
   hämtningsdatum mot källans uppdateringsfrekvens och flaggar "dags att uppdatera";
   `uppdatera-data.cmd` kör hela pipelinen med ett dubbelklick. Uppdateringsfrekvens ska
   matcha beslutsfrekvens — realtid ingen tittar på är ren kostnad.
3. **Publicering som öppet API** (`docs/PUBLICERING-OCH-AI.md`): statisk hosting gör
   `data/curated/*.json` till HTTPS-endpoints för Lovable/AI Studio m.fl.
4. **AI-kontext**: pipelinen genererar `ai/AI-KONTEXT.md` — ärlighetsregler + snabbfakta +
   datakatalog — så att en LLM kan kommentera datan utan att hitta på siffror.

Nya lärdomar:

- **API:er avvecklas**: Kolada v2 var nedlagt (deprecation-svar) — v3 hade annan bas-URL
  men samma mönster. Därför ska källspecifik kod vara en tunn gren, inte invävd överallt;
  bytet kostade minuter i stället för dagar.
- **Teckenkodning är en evig följetong**: Kolada skickar ingen charset-header →
  PowerShell 5.1 gissar Latin-1 och förstör åäö. Lösning: avkoda alltid råbytes explicit
  som UTF-8. (Tredje kodningslärdomen i projektet — BOM i .ps1, escapad JSON, nu HTTP.)
- **Kunskapsförvaltning på riktigt**: alla API-recept och fällor sparades som en
  återanvändbar skill (`fetching-swedish-open-data`) — motsvarigheten till att dokumentera
  i en gemensam kunskapsbas i stället för i huvudet på en konsult. Kravställ alltid att
  kompetensen stannar.

## Iteration 3: geodata, kartvy och simuleringsverktyg

1. **Geodata från kommunens egen GeoServer** (källa nr 3 — mönstret höll igen: fem
   katalogposter, en URL-gren, en formatgren). Fem lager: stadsdelar, lekplatser, parker,
   lediga tomter, pågående detaljplaner. Transformeringen gallrar attribut och avrundar
   koordinater till 5 decimaler (~1 m) — 372 kB rå geodata blev hanterbar inbäddad mängd.
2. **Kartvy utan kartbibliotek**: stadsdelspolygonerna renderas som ren SVG (ekvirektangulär
   projektion med breddgradskompensation — fullt tillräcklig i stadsskala), vilket bevarar
   noll beroenden och offline-funktion. Choropleth med *en* sekventiell färgskala
   (opacitetssteg på temafärgen), punkt-i-polygon-räkning i klienten kopplar objekt till
   stadsdel, och en topplista + "X stadsdelar saknar objekt" ger analysen i text bredvid
   kartan. **Visualiseringsprincip:** absoluta antal redovisas som just antal — per
   capita-mått kräver befolkning per delområde (SCB DeSO, identifierat nästa steg), och
   det förbehållet står i kartvyn, inte bara i dokumentationen.
3. **Simuleringsverktyg** ("testa scenarier själv"): fyra reglage (flyttnetto, födelsenetto,
   byggtakt, hushållsstorlek) + fyra förval (trend, SCB:s antaganden, hög tillväxt,
   nolltillväxt) driver en öppet redovisad modell — folkmängd framåt, år för
   100 000-passage, bostadsbehov och ackumulerad bostadsbalans, alltid med SCB:s
   framskrivning som referenslinje i diagrammet. Modellens begränsningar (ingen
   åldersstruktur-återkoppling) deklareras i verktyget självt. Detta är preskriptiv analys
   i sin ärligaste form: *beslutsfattaren* vrider på antagandena och ser konsekvenserna,
   i stället för att få ett facit serverat.

Nya lärdomar:

- **Punkter utanför indelningen är information, inte fel**: 57 av 229 lekplatser ligger
  utanför stadsdelsindelningen (ytterorter). Att räkna och redovisa dem separat är
  skillnaden mellan en ärlig och en missvisande karta.
- **Geodata behöver inte kartbibliotek**: för choropleth i stadsskala räcker SVG +
  enkel projektion. Leaflet/OSM behövs först när bakgrundskarta eller zoom krävs.
- **Simulatorer säljer analysen**: samma data som i statiska diagram blir mer engagerande
  och pedagogisk när användaren själv får ändra antaganden — och tvingar samtidigt fram
  explicita modellantaganden, vilket skärper metodhygienen.

## Iteration 4: DeSO/RegSO, riktig karta, egen data, tema, export och rapportbyggare

1. **DeSO/RegSO med SCB:s öppna geodata**: SCB:s GeoServer (`geodata.scb.se/geoserver/stat/`)
   visade sig servera DeSO_2025/RegSO_2025-gränser som WFS — filtrerbara med
   `cql_filter=kommunkod='1780'`. Kombinerat med befolkning per område (TAB6574 med
   wildcard `1780*`) och **socioekonomiskt index per RegSO (TAB6586)** ger det riktig
   delområdesanalys: Kronoparken centrala och Gruvlyckan är områdestyp 1 (stora
   utmaningar), Skåreberget-Älvåker typ 5. Kartan har nu tre geografier med dokumenterade
   datakopplingar per nivå. DeSO-summan (98 988) avviker 19 personer från kommuntotalen —
   sekretessavrundning, dokumenterat i stället för dolt.
2. **SWEREF 99 TM**: egen implementering av Gauss-Krügers projektionsformler
   (Lantmäteriets formelsamling) i båda riktningar — koordinatavläsning i kartan och
   import av egen platsdata i SWEREF eller WGS 84.
3. **Interaktiv karta**: Leaflet läses in *först vid behov* (progressive enhancement —
   analyskartan i SVG fungerar offline), med OpenStreetMap eller Karlstads egen
   baskarta (WMS-lagret BGkarta) som bakgrund.
4. **Värmland som systemnivå** i arbetslöshets- och utbildningsdiagrammen (kommun ⊂ län ⊂
   rike). Lärdom: alla SCB-tabeller har inte länsnivå (TAB4642 saknar) — kontrollera
   Region-dimensionen per tabell.
5. **Egen data, tema, export, rapportbyggare**: allt lagras i webbläsarens localStorage
   (inget lämnar datorn), teman via CSS-tokens (två rader per färg att byta),
   diagrammen exporteras som SVG/PNG med inbakade stilar, tabeller som CSV med BOM
   (Excel-vänligt), och rapportbyggaren klonar färdigrenderade block till en ren
   utskriftsvy — återanvändning i stället för dubbelrendering.
6. **Designlyft med berättelse**: "Solstaden" — varmt papper/nattblått med solgul accent
   och solstrålemotiv, Bricolage Grotesque för rubriker och Atkinson Hyperlegible
   (Braille Institutes läsbarhetstypsnitt) för brödtext — ett typografival som *är* ett
   tillgänglighetsargument i offentlig sektor.

## Iteration 5: verksamhetsgrupper, geodataimport och personalisering

1. **Verksamhetsspecifika jämförelsegrupper** (RKA): skol-KPI:erna jämförs nu mot
   "Liknande kommuner grundskola/gymnasieskola" och hemtjänsten mot "Liknande kommuner
   äldreomsorg" — ekonomin behåller den övergripande gruppen. Rätt referensgrupp per
   verksamhet är skillnaden mellan en artig och en användbar jämförelse. Gruppen anges
   nu på varje jämförelsekort (spårbarhet).
2. **Min data klarar geodataformat**: GeoJSON (klistra in/fil), WFS-URL (hämtas direkt,
   kräver CORS hos tjänsten), WMS (URL;lagernamn — visas i interaktiva kartan) och
   grundläggande **Shapefile** (.shp punkt/linje/polygon + .dbf för namn, egen binärläsare).
   SWEREF 99 TM autodetekteras och konverteras. För stora datamängder som inte ryms i
   localStorage behålls under sessionen med tydlig varning.
3. **Personalisering med rimlig gräns**: namngivna färgprofiler med live-förhandsvisning,
   fyra typsnittsval, dataetiketter/rutnät på/av (CSS-styrt — ingen omrendering), egen
   rubrik/välkomsttext. Allt i localStorage: användarens anpassningar rör aldrig
   datalagret eller definitionerna — personalisering av *presentation*, aldrig av *fakta*.
4. **Förvaltarvyn**: sökbar datakatalog och systeminfo-ruta (antal datamängder,
   paketstorlek, lokal lagring, beroenden) — det en systemförvaltare frågar efter först.
5. Publiceringsguiden byggdes ut: GitHub Pages helt utan git-kunskap, eget webbhotell
   (FTP), intranät och CORS-noten för den som vill exponera JSON-endpoints.

## Iteration 6: full färgkontroll, spårlager och rapportexport

1. **Samtliga profilfärger justerbara**: nio färgfält (diagram 1–5, primär, accent,
   bakgrund, kortyta, text) genereras ur en enda definitionslista (`FARGFALT`) — samma
   lista driver även tillämpning, återställning och namngivna profiler. En sanning,
   fyra konsumenter.
2. **Axelrubriker av/på**: y-axelrubrik per diagram (roterad text), styrd via samma
   CSS-attributmönster som dataetiketter/rutnät — ingen omrendering.
3. **Elljusspår + motionsspår** (GeoServer, LineString): kartmotorn fick linjestöd —
   linjer ritas som spår i accentfärg, räknas per stadsdel via sin mittpunkt.
4. **Kartnedladdning med bakgrund**: PNG-export med OpenStreetMap eller Karlstads
   baskarta. Teknisk poäng: Karlstads WMS begärs i EPSG:4326 (linjärt i lat/lon = exakt
   samma projektion som analyskartan), medan OSM är Web Mercator — därför ritas
   geometrin om i Mercator för OSM-varianten i stället för att återanvända SVG:n.
   Attribution bakas in i bilden. Kräver internet; offlinevägen (PNG utan bakgrund)
   finns kvar.
5. **Rapportexport i tre format**: PDF (via utskrift), **Word** (.doc som MHTML med
   diagrammen inbäddade som PNG — öppnas direkt i Word) och **Excel** (.xls med ett
   kalkylblad per block med underliggande data). Inga externa bibliotek.

### Buggen som bara drabbade återkommande användare (iteration 6)

När färgpanelen byggdes om lämnades två rader kvar som refererade de borttagna
formulärfälten — men bara i kodvägen som körs **om användaren har sparade färger**.
Alla tester mot färsk webbläsare var gröna; för användare med inställningar sedan
tidigare kraschade hela sidan ("inga datamängder visas"). Felsökningen: reproducera
genom att så in gammalt localStorage-innehåll i testmiljön → exakt kraschrad hittad
→ två rader bort → omtest mot samma tillstånd. **Lärdomar:** (1) testa alltid både
nytt och *befintligt* användartillstånd efter UI-ombyggnad — trogna användare har
tillstånd som färska tester aldrig ser; (2) en enda JavaScript-krasch i uppstarten
släcker hela sidan — init-kod bör tåla att element saknas.

## Koppling till rollen (leveransområdesansvarig data och analysstöd)

| Ansvar i rollen | Motsvarighet i projektet |
|---|---|
| Strukturer för datalager | Lagerarkitekturen: landningszon → kurerat lager → produkt, gemensamma dimensioner, manifest/spårbarhet |
| Informations- och begreppsmodeller | INFORMATIONSMODELL.md: tre modellnivåer, definitioner med fallgropar, DCAT-AP-SE-förberedd katalog |
| Analysstöd | Nyckeltalskatalog med U/I/P-typning, dashboard per beslutssituation, förbehåll i produkten |
| Prediktiv/preskriptiv analys med AI | Framskrivningar med baslinjejämförelse, regelbaserade insikter med redovisad logik, mänsklig prövning som princip |
| Öppna data | Byggd helt på CC0-data; datakatalogen gör lösningen själv publicerbar; visar öppna datas värdekedja i praktiken |
| Målbilder/beslutsunderlag | Insiktskorten är miniformatet: nuläge → underlag → regel → möjligt nästa steg |
| Samverkan Geodata/IoT | Arkitekturen har en definierad väg in för GeoServer-lager (WFS/GeoJSON) och andra källor |
| Kompetenshöjande arbete | Hela projektet är skrivet som utbildningsmaterial: granskningsbar kod, dokumenterad process, misstagen redovisade |

## Vad hade gjorts annorlunda i skarp drift?

- ~~Kolada som andra källa dag ett~~ — åtgärdat i iteration 2.
- Fasta priser för inkomstserien (KPI-deflatering) i stället för förbehållstext.
- Automatiserad schemaläggning av pipelinen + enkel diff-rapport ("vad ändrades sedan förra
  hämtningen?").
- Användningsmätning av dashboarden — en rapport utan läsare ska avvecklas.
