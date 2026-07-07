# AI-kontext: Karlstad-analys

> Genererad automatiskt av pipeline\hamta-scb-data.ps1 2026-07-06T23:58:14. Redigera inte för hand.
> Ge denna fil (och vid behov data/curated/*.json) som kontext till en AI-assistent.

## Instruktion till AI-assistenten

Du hjälper till att analysera öppna data om **Karlstads kommun** (kommunkod 1780).
Regler som INTE får brytas:

1. Svara enbart utifrån serierna i detta datalager (data/curated/ eller app/data.js). Hitta aldrig på värden.
2. Ange källa (tabell-/KPI-id) och årtal för varje siffra du använder.
3. Skilj utfall från framskrivning: datamängder med id prognos_* är modellvärden, inte observationer.
4. All data avser Karlstads kommun, inte tätorten Karlstad.
5. Kan frågan inte besvaras ur datamängderna nedan: säg det uttryckligen och föreslå vilken källa som saknas.
6. Nyckeltalsdefinitioner finns i docs/NYCKELTALSKATALOG.md - använd dem, uppfinn inga egna.
7. Inkomster är i löpande priser; BAS-arbetsmarknadsstatistiken är preliminär. Nämn förbehållen när de är relevanta.

## Snabbfakta (senaste värden vid genereringen)

- Folkmängd 2025: 99007 (TAB6574)
- Demografisk försörjningskvot 2025: 71.2 (TAB4642)
- Arbetslöshet 20-64 2026M04: 4.8 % (TAB5663, preliminär)
- Resultatandel av skatt 2025: 3.1 % (Kolada N03102)
- Jämförelsegrupp (Kolada G37421): Jönköping, Växjö, Kalmar, Karlskrona, Lund, Luleå, Piteå

## Datamängder (systemdokumentation)

| id | innehåll | enhet | källa | hämtad | maskinläsbar fil |
|---|---|---|---|---|---|
| befolkning_lang | Folkmängd 1968-2024. Total folkmängd 31 dec per år, Karlstad och riket. Längsta jämförbara serien. | antal personer | SCB TAB638 | 2026-07-06 | data/curated/befolkning_lang.json |
| folkmangd_alder | Folkmängd efter ålder och kön 2010-2025. Femårsklasser, underlag för ålderspyramid och åldersgruppernas utveckling. | antal personer | SCB TAB6574 | 2026-07-06 | data/curated/folkmangd_alder.json |
| befolkningsforandringar | Befolkningsförändringar 2000-2024. Födda, döda, flyttningar m.m. per helår. Förklarar VARFÖR folkmängden ändras. | antal personer | SCB TAB5169 | 2026-07-06 | data/curated/befolkningsforandringar.json |
| prognos_oversikt | SCB:s befolkningsframskrivning 2024-2070, översikt. Officiell regional framskrivning: folkmängd, folkökning och komponenter. | antal personer | SCB TAB694 | 2026-07-06 | data/curated/prognos_oversikt.json |
| prognos_alder | SCB:s befolkningsframskrivning per ålder 2024-2070. Framskriven folkmängd i ettårsklasser - underlag för framtida försörjningskvot. | antal personer | SCB TAB698 | 2026-07-06 | data/curated/prognos_alder.json |
| medelalder | Befolkningens medelålder 1998-2025. Medelålder, Karlstad jämfört med riket. | år | SCB TAB637 | 2026-07-06 | data/curated/medelalder.json |
| forsorjningskvot | Demografisk försörjningskvot 2000-2025. (Antal 0-19 + antal 65+) / antal 20-64. SCB:s officiella definition. | kvot | SCB TAB4642 | 2026-07-06 | data/curated/forsorjningskvot.json |
| bostader | Färdigställda lägenheter i nybyggda hus 1990-2025. Nyproduktion per hustyp (flerbostadshus/småhus). | antal lägenheter | SCB TAB2538 | 2026-07-06 | data/curated/bostader.json |
| inkomst | Sammanräknad förvärvsinkomst 20-64 år, 1999-2024. Median- och medelinkomst (tkr/år) för åldern 20-64, per kön, Karlstad och riket. | tkr per år (löpande priser) | SCB TAB3554 | 2026-07-06 | data/curated/inkomst.json |
| utbildning | Utbildningsnivå 25-64 år, 2008-2025. Befolkning 25-64 efter högsta utbildningsnivå. Aggregeras till för-/gymnasial/eftergymnasial. | antal personer | SCB TAB4320 | 2026-07-06 | data/curated/utbildning.json |
| arbetsmarknad | Sysselsättningsgrad och arbetslöshet (BAS), månad 2024-. Preliminär månadsstatistik från Befolkningens arbetsmarknadsstatus, 20-64 år. | procent | SCB TAB5663 | 2026-07-06 | data/curated/arbetsmarknad.json |
| skattesats | Kommunala skattesatser 2000-2026. Total kommunal skattesats samt del till kommunen, Karlstad och riket. | procent | SCB TAB2017 | 2026-07-06 | data/curated/skattesats.json |
| kolada_resultat | Årets resultat som andel av skatt & generella statsbidrag. Kommunens ekonomiska resultat. Tumregel för god ekonomisk hushållning: ca 2 procent. | procent | RKA (Kolada) N03102 | 2026-07-06 | data/curated/kolada_resultat.json |
| kolada_soliditet | Soliditet inkl. pensionsåtaganden. Långsiktig betalningsförmåga: eget kapital (inkl. hela pensionsskulden) som andel av tillgångarna. | procent | RKA (Kolada) N03002 | 2026-07-06 | data/curated/kolada_soliditet.json |
| kolada_nettokostnadsavvikelse | Nettokostnadsavvikelse totalt (exkl. LSS). Avvikelse mot statistiskt förväntad kostnad givet kommunens struktur. Positiv = dyrare än strukturen motiverar. | procent | RKA (Kolada) N00097 | 2026-07-06 | data/curated/kolada_nettokostnadsavvikelse.json |
| kolada_behorighet | Elever i åk 9 behöriga till yrkesprogram (hemkommun). Andel av kommunens folkbokförda åk 9-elever som är behöriga till gymnasiets yrkesprogram. | procent | RKA (Kolada) N15428 | 2026-07-06 | data/curated/kolada_behorighet.json |
| kolada_gymnasieexamen | Gymnasieelever med examen eller studiebevis inom 4 år (hemkommun). Genomströmning i gymnasiet för kommunens folkbokförda elever. | procent | RKA (Kolada) N17457 | 2026-07-06 | data/curated/kolada_gymnasieexamen.json |
| kolada_hemtjanst | Brukarbedömning hemtjänst - helhetssyn. Andel brukare som sammantaget är nöjda med sin hemtjänst (Socialstyrelsens brukarundersökning). | procent | RKA (Kolada) U21468 | 2026-07-06 | data/curated/kolada_hemtjanst.json |
| geo_stadsdelar | Stadsdelar (polygoner, lokal export i SWEREF 99 TM). Karlstads stadsdelsindelning från lokal GeoJSON-export (EPSG:3006) - konverteras till WGS 84 i transformsteget. | geografiska ytor | Karlstads kommun (lokal export) Stadsdelar Json.txt | 2026-07-06 | data/curated/geo_stadsdelar.json |
| geo_lekplatser | Lekplatser (punkter). Kommunala lekplatser med namn - underlag för utbudsanalys per stadsdel. | platser | Karlstads kommun (GeoServer) karlstad_lekplatser | 2026-07-06 | data/curated/geo_lekplatser.json |
| geo_parker | Parker (polygoner). Kommunala parker med namn. | ytor | Karlstads kommun (GeoServer) karlstad_parker | 2026-07-06 | data/curated/geo_parker.json |
| geo_tomter | Lediga tomter (polygoner). Kommunens lediga småhustomter med areal och länk. | tomter | Karlstads kommun (GeoServer) karlstad_lediga_tomter | 2026-07-06 | data/curated/geo_tomter.json |
| geo_planer | Pågående detaljplaner (polygoner). Detaljplaner under arbete - indikator på var utvecklingstrycket finns. | planområden | Karlstads kommun (GeoServer) karlstad_planer_pagaende | 2026-07-06 | data/curated/geo_planer.json |
| geo_elljusspar | Elljusspår (linjer). Belysta motionsspår - folkhälsoinfrastruktur, användbar året runt. | spår | Karlstads kommun (GeoServer) karlstad_elljusspar | 2026-07-06 | data/curated/geo_elljusspar.json |
| geo_motionsspar | Motionsspår (linjer). Kommunala motionsspår. | spår | Karlstads kommun (GeoServer) karlstad_motionsspar | 2026-07-06 | data/curated/geo_motionsspar.json |
| geo_deso | DeSO - demografiska statistikområden (polygoner). SCB:s DeSO-indelning för Karlstad, med koppling till RegSO. Nyckel för statistik på delområdesnivå. | geografiska ytor | SCB (öppna geodata) DeSO_2025 | 2026-07-06 | data/curated/geo_deso.json |
| geo_regso | RegSO - regionala statistikområden (polygoner). SCB:s RegSO-indelning för Karlstad med områdesnamn. | geografiska ytor | SCB (öppna geodata) RegSO_2025 | 2026-07-06 | data/curated/geo_regso.json |
| omraden_befolkning | Befolkning per DeSO och RegSO, senaste år. Folkmängd och åldersstruktur per statistikområde - grund för analys på delområdesnivå. | antal personer | SCB TAB6574 | 2026-07-06 | data/curated/omraden_befolkning.json |
| regso_socioek | Socioekonomiskt index per RegSO 2011-2024. SCB:s socioekonomiska index med områdestyp (1 = stora utmaningar ... 5 = mycket goda förutsättningar) och delindikatorer. | index/andelar | SCB TAB6586 | 2026-07-06 | data/curated/regso_socioek.json |

## Dataformat

- Varje kurerad fil: { id, titel, enhet, kalla{tabell, url, hamtad}, innehall{...} }
- Tidsserieformat: { "ar": ["2000", ...], "varde": [73.4, ...] } - index i ar och varde hör ihop.
- app/data.js innehåller allt samlat: window.KARLSTAD_DATA = { region, dataset{<id>}, katalog }.
- Vid statisk hosting är data/curated/<id>.json direkta HTTPS-endpoints (de facto öppet API).
