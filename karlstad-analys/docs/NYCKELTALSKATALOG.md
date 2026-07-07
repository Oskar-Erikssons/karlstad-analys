# Nyckeltalskatalog

En definition per nyckeltal, dokumenterad **innan** den visas i någon rapport. Det
vanligaste haveriet i kommunal uppföljning är tre förvaltningar med tre olika svar på samma
fråga — katalogen är motmedlet. Varje post anger täljare/nämnare, population, källa,
uppdatering och tolkningsnoter.

Typmärkning: **U** = utfallsmått (vad hände) · **I** = indikator (tidig signal) ·
**P** = prognosmått (modellvärde).

---

### Folkmängd — U
- **Definition**: antal folkbokförda i Karlstads kommun 31 december.
- **Källa**: SCB TAB638 (1968–2024) + TAB6574 (senaste år). Uppdateras: februari.
- **Tolkning**: kommunens viktigaste planeringstal; styr skatteunderlag, utjämning, lokalbehov.

### Befolkningstillväxt 10 år — U
- **Definition**: (folkmängd år T ÷ folkmängd år T−10 − 1) × 100.
- **Not**: kompletteras med årstakt (linjär trend 2010–) för att inte vila på två enskilda årsvärden.

### Folkökningens komponenter — U
- **Definition**: födelsenetto (födda − döda), flyttnetto (in- − utflyttade) per kalenderår.
- **Källa**: SCB TAB5169. Uppdateras: kvartalsvis.
- **Tolkning**: *varför* växer kommunen. Karlstads tillväxt är flyttdriven — känsligare för konjunktur och studentkullar än födelsedriven tillväxt.

### Demografisk försörjningskvot — U/P
- **Definition**: (antal 0–19 + antal 65+) ÷ (antal 20–64) × 100.
- **Källa**: utfall SCB TAB4642; framtid egen beräkning ur SCB:s åldersframskrivning TAB698 med samma formel.
- **Tolkning**: lägre = fler i arbetsför ålder per försörjd. Jämför alltid mot riket. Demografisk ≠ ekonomisk försörjningskvot (den senare räknar faktiskt arbetande).

### Medelålder — U
- **Definition**: befolkningens medelålder 31 december. **Källa**: SCB TAB637.

### Arbetslöshet / sysselsättningsgrad (BAS) — I
- **Definition**: andel arbetslösa resp. sysselsatta av befolkningen 20–64, per månad.
- **Källa**: SCB TAB5663 (BAS). Uppdateras: månadsvis. **Preliminär statistik.**
- **Tolkning**: tidig konjunktursignal. Kort serie (2024–) — tolka nivå snarare än trend. Ej jämförbar med AKU eller Arbetsförmedlingens inskrivna.

### Medianinkomst 20–64 — U
- **Definition**: median av sammanräknad förvärvsinkomst, boende 20–64 år, tkr/år, löpande priser.
- **Källa**: SCB TAB3554. Uppdateras: januari (avser inkomstår ~18 mån bakåt).
- **Tolkning**: median tål skeva fördelningar (använd inte medel ensamt). Löpande priser → jämför mot riket samma år, inte rakt över tid. Studentbefolkning drar ner nivån strukturellt.

### Andel eftergymnasialt utbildade 25–64 — U
- **Definition**: antal 25–64 med eftergymnasial utbildning (SUN 5–7) ÷ samtliga 25–64 (inkl. "uppgift saknas") × 100.
- **Källa**: SCB TAB4320. Uppdateras: april.
- **Tolkning**: kompetensbas för rekrytering. Population 25–64 (inte 16–) för att inte räkna pågående studenter som lågutbildade.

### Färdigställda lägenheter — U
- **Definition**: lägenheter i nybyggda hus färdigställda under året, per hustyp.
- **Källa**: SCB TAB2538. Uppdateras: maj.
- **Härlett mått**: *lägenheter per 100 nya invånare* = femårssnitt byggda ÷ femårssnitt folkökning × 100. Riktvärde ≈ 45–50 (hushållsstorlek ~2,15). Femårssnitt eftersom byggandet är kraftigt volatilt.

### Kommunal skattesats — U
- **Definition**: total kommunal skattesats (kommun + region), procent.
- **Källa**: SCB TAB2017. Uppdateras: december.
- **Tolkning**: redovisas utan värdering — nivån speglar även skatteväxlingar mellan kommun och region samt servicenivå.

### Resultatandel av skatt & statsbidrag (Kolada N03102) — U
- **Definition**: årets resultat ÷ (skatteintäkter + generella statsbidrag) × 100.
- **Källa**: Kolada/RKA. Uppdateras: årligen (bokslut).
- **Tolkning**: tumregel för god ekonomisk hushållning ≈ 2 %. Enstaka år kan lyftas av engångsposter — se flera år.

### Soliditet inkl. pensionsåtaganden (Kolada N03002) — U
- **Definition**: eget kapital (inkl. hela pensionsskulden) ÷ totala tillgångar × 100.
- **Tolkning**: långsiktig betalningsförmåga; det "tuffare" soliditetsmåttet. Jämför inom jämförelsegruppen — nivån påverkas av historiska investerings- och pensionsbeslut.

### Nettokostnadsavvikelse totalt exkl. LSS (Kolada N00097) — U
- **Definition**: faktisk nettokostnad jämfört med statistiskt förväntad kostnad ("referenskostnad") givet kommunens struktur, i procent.
- **Tolkning**: positiv = dyrare än strukturen motiverar; nära 0 = kostnadseffektiv drift. Säger inget om *kvalitet* — läs ihop med kvalitetsmått (t.ex. brukarbedömning).

### Behöriga till yrkesprogram åk 9, hemkommun (Kolada N15428) — U
- **Definition**: andel av kommunens folkbokförda åk 9-elever som är behöriga till gymnasiets yrkesprogram, oavsett skolhuvudman.
- **Tolkning**: hemkommunsperspektivet (inte lägeskommun) är rätt för kommunens ansvar. Små årskullar ger studsiga värden i mindre kommuner.

### Gymnasieexamen/studiebevis inom 4 år, hemkommun (Kolada N17457) — U
- **Definition**: andel av kommunens folkbokförda gymnasieelever som tar examen eller studiebevis inom 4 år.

### Brukarbedömning hemtjänst, helhetssyn (Kolada U21468) — I
- **Definition**: andel hemtjänstbrukare som sammantaget är nöjda (Socialstyrelsens brukarundersökning).
- **Tolkning**: U-mått = enkätbaserat (urval, svarsfrekvens) till skillnad från registerbaserade N-mått — tolka nivåskillnader på någon procentenhet försiktigt.

### Milstolpe 100 000 invånare — P
- **Definition**: första år då folkmängden ≥ 100 000 enligt (a) SCB:s regionala framskrivning TAB694, (b) linjär trend anpassad till utfall 2010–2025.
- **Tolkning**: två modeller redovisas medvetet — spridningen *är* osäkerhetsmåttet. Följs upp mot utfall årligen.

---

## Regler för katalogen

1. Nytt nyckeltal → ny post här **innan** det visas i dashboarden.
2. Ändrad definition → ändra här först, dokumentera brytpunkt i tidsserien.
3. Varje nyckeltal ska ha typ (U/I/P), källa med tabell-id och tolkningsnot med känd fallgrop.
4. Jämförelser görs i andelar/per capita, aldrig absoluta tal mellan olika stora regioner.
