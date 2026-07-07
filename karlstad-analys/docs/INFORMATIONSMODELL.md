# Begrepps- och informationsmodell

Tre modellnivåer hålls isär: **begreppsmodellen** (verksamhetens språk, teknikfri),
**informationsmodellen** (attribut, identiteter, relationer) och **datamodellen** (hur det
faktiskt lagras — här: JSON-filernas struktur). Det vanligaste felet i datainitiativ är att
hoppa direkt till datamodellen; därför börjar detta dokument i begreppen.

## Begreppsmodell

Centrala begrepp och deras definitioner. Definitionerna följer SCB:s där sådana finns —
att återanvända nationella definitioner i stället för att uppfinna egna är en huvudprincip.

| Begrepp | Definition | Kommentar/fallgrop |
|---|---|---|
| **Region** | Administrativt område med SCB-kod. Här: Karlstads *kommun* (1780) och riket (00) | Kommun ≠ tätort! Tätorten Karlstad är mindre än kommunen. Blandas de ihop blir alla jämförelser fel |
| **Folkmängd** | Antal folkbokförda den 31 december respektive år | Mättidpunkten ingår i definitionen — "folkmängd 2024" = 31 dec 2024 |
| **Folkökning** | Årets förändring av folkmängden | Summan av komponenterna nedan ± SCB:s justeringspost |
| **Födelsenetto** | Födda minus döda under året | Kallas även födelseöverskott |
| **Flyttnetto** | Inflyttade minus utflyttade (inrikes + utrikes) | Kan delas i inrikes netto och invandringsnetto |
| **Demografisk försörjningskvot** | (Antal 0–19 + antal 65+) ÷ (antal 20–64) × 100 | Lägre = gynnsammare. Säger inget om vilka som faktiskt arbetar — det gör *ekonomisk* försörjningskvot |
| **Sysselsättningsgrad / arbetslöshet (BAS)** | Andel av befolkningen 20–64 enligt Befolkningens arbetsmarknadsstatus | Preliminär månadsstatistik; skiljer sig metodmässigt från AKU — blanda inte serierna |
| **Sammanräknad förvärvsinkomst** | Inkomst av tjänst + näringsverksamhet, före skatt | Innehåller inte kapitalinkomster. Median ≠ medel — median används som huvudmått |
| **Utbildningsnivå** | Högsta avslutade utbildning (SUN), här grupperad till för-/gymnasial/eftergymnasial | "Uppgift saknas" ingår i nämnaren när andelar beräknas |
| **Färdigställd lägenhet** | Lägenhet i nybyggt hus, färdigställd under året | Nybyggnad exkl. ombyggnad — total tillskott är något större |
| **Framskrivning** | Modellberäknad framtida befolkning givet antaganden | Medvetet *inte* kallad "prognos" av SCB — antagandena dominerar på kommunnivå |
| **Jämförelsegrupp** | RKA:s officiella grupp av strukturellt liknande kommuner (Kolada) | Finns per verksamhetsområde; "övergripande" används här. Jämför aldrig godtyckliga grannkommuner |
| **Stadsdel** | Kommunens egen indelning av tätorten (66 ytor i öppna geodatalagret) | Täcker inte hela kommunen — ytterområden (Vålberg, Molkom m.fl.) ligger utanför. Ej samma sak som SCB:s DeSO |
| **DeSO** | SCB:s demografiska statistikområden — rikstäckande delområden med befolkningsstatistik | Nyckeln till per capita-mått på delområdesnivå; identifierat nästa steg för kartvyn |
| **Nettokostnadsavvikelse** | Faktisk kostnad mot statistiskt förväntad givet kommunens struktur | Mäter kostnadsläge, inte kvalitet — läs ihop med kvalitetsmått |
| **Nyckeltal** | Definierat mått med källa, population och tidsfönster (se NYCKELTALSKATALOG.md) | Ett nyckeltal utan dokumenterad definition är en åsikt |

Relationer i ord: en **Region** har en **Folkmängd** per år; Folkmängden förändras genom
**Födelsenetto** och **Flyttnetto**; ur folkmängdens åldersfördelning beräknas
**Försörjningskvot** och **Medelålder**; en **Framskrivning** är samma storheter för
framtida år, beräknade av en modell i stället för observerade.

## Informationsmodell

Strukturen som bär informationen, oberoende av lagringsteknik:

```
DATAMÄNGD (id, titel, beskrivning, enhet, uppdateringsfrekvens)
  ── härrör från ──▶ KÄLLA (myndighet, tabell-id, url, licens, hämtningstidpunkt)
  ── innehåller ──▶ SERIE (region, ev. undergrupp: kön/åldersgrupp/hustyp/nivå)
                       └── OBSERVATION (tidsperiod, värde, ev. status)
```

- **Identiteter**: datamängd identifieras av `id` (t.ex. `forsorjningskvot`); serie av
  (datamängd, region, undergrupp); observation av (serie, tidsperiod).
- **Gemensamma dimensioner**: `region` (SCB:s kommunkoder) och `tidsperiod` (ISO-år eller
  `ÅÅÅÅMmm` för månad) är nycklarna som gör datamängder kombinerbara.
- **Livscykel**: rådata är oföränderlig; kurerade serier skrivs om vid varje
  pipelinekörning; dataprodukten (data.js) är en publicerad ögonblicksbild med tidsstämpel.

## Datamodell (fysisk)

Kurerad fil (`data/curated/*.json`):

```json
{
  "id": "forsorjningskvot",
  "titel": "...", "beskrivning": "...", "enhet": "kvot",
  "kalla": { "myndighet": "SCB", "tabell": "TAB4642", "licens": "CC0",
             "hamtad": "2026-07-05T...", "url": "..." },
  "innehall": { "serier": { "1780": { "totalt": { "ar": ["2000", ...],
                                                   "varde": [73.4, ...] } } } }
}
```

## Koppling till DCAT-AP-SE

`data/datakatalog.json` bär fälten som krävs för att beskriva datamängderna enligt
metadatastandarden **DCAT-AP-SE** (som används på dataportal.se): titel, beskrivning,
utgivare (SCB), licens (CC0), uppdateringsfrekvens, distributionsformat (JSON) och
åtkomst-URL. Skulle materialet publiceras som öppna data är katalogposterna redan
förberedda — öppna data är en biprodukt av god intern informationshantering.

## Datakvalitet — bedömning per dimension

| Dimension | Bedömning för denna lösning |
|---|---|
| Fullständighet | God — heltäckande register (SCB). BAS-serien är kort (från 2024) |
| Korrekthet | God — nationalstatistik; framskrivningar är modellvärden |
| Aktualitet | Blandad — befolkning per feb, inkomst släpar ~1 år; anges per datamängd i katalogen |
| Konsistens | Kontrollerad — folkmängd stäms av mellan två oberoende tabeller vid varje körning |
| Unikhet | Garanterad av identiteterna ovan (en observation per serie × period) |
| Spårbarhet | Full kedja: diagram → kurerad fil → råfil → API-URL med tidsstämpel |
