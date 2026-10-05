# Orientační výkonnostní pásma

Výsledková obrazovka ukazuje řádek „Úroveň (orientačně)“ a hranici dalšího pásma. Pásma vycházejí z tabulky od maintainera (odvozené ze stylu norem CANTAB, CogState a Z-Health), upravené na to, co a jak aplikace skutečně měří. **Nejsou to klinické normy.** Hodnoty jsou v kódu v `core/benchmarks.gd`; každá hra ukládá do výsledku standardizované metriky (`DrillResult.metrics`), nad kterými se pásmo vyhodnocuje.

Pravidla:
- „Zkušený“ vyžaduje i kontrolu chybovosti: kde je uvedena brána, rychlý výkon s chybami nad bránou spadne do pokročilého, chybovost nad horní bránou do začátečníka.
- Pásmo se zobrazí jen u varianty, pro kterou je definováno (např. Schulte 5×5 s čísly, Trail Making s 20 kolečky, vizuální hledání s 64 znaky). Jiné varianty pásmo nemají.
- Hranice: hodnota lepší než „Zkušený“ = zkušený; hodnota nejvýš rovna hranici „Pokročilý“ = pokročilý; jinak začátečník.

| Hra / varianta | Metrika | Pokročilý do | Zkušený od | Brána chybovosti (zkušený / začátečník) |
| --- | --- | --- | --- | --- |
| Schulteho tabulka 5×5, čísla | celkový čas | 45 s | 20 s | ≤ 1 chyba / > 6 chyb |
| Gorbov–Schulte 7×7 | celkový čas | 120 s | 55 s | 0 chyb / > 4 chyby |
| Trail Making A, 20 koleček, čísla vzestupně | celkový čas | 28 s | 12 s | – |
| Trail Making B, 20 koleček, čísla + písmena (obě kombinace) | celkový čas | 50 s | 20 s | – |
| Vizuální hledání, 64 znaků | medián reakce | 850 ms | 420 ms | – |
| SART | průměrná reakce | 380 ms | 290 ms | reakce na trojku ≤ 3 % / > 15 % |
| Posnerova nápověda | cena přesunu | 80 ms | 25 ms | chyby ≤ 5 % / > 20 % |
| Sledování více objektů | úspěšnost | 65 % | 100 % | – |
| Hledání reflektorem | čas na cíl | 3,2 s | 0,9 s | ≤ 1 chybný klik / > 6 |
| Reakční čas | medián | 270 ms | 180 ms | předčasné ≤ 10 % / > 50 %; medián pod 100 ms = bez pásma |
| Výběrová reakce | medián | 420 ms | 280 ms | chyby ≤ 5 % / > 20 % |
| Go/No-Go standard | průměrná reakce na zelenou | 380 ms | 260 ms | reakce na červenou ≤ 2 % / > 12 % |
| Go/No-Go adaptivní | nejkratší zvládnutý podnět | 350 ms | 170 ms | – |
| Stroop | interference | 140 ms | 30 ms | chyby ≤ 5 % / > 20 % |
| Flanker | interference | 80 ms | 15 ms | chyby ≤ 5 % / > 20 % |
| Přepínání úloh | cena přepnutí | 220 ms | 60 ms | chyby ≤ 5 % / > 20 % |
| Počítání | čas na správnou odpověď | 3,0 s | 0,9 s | chyby ≤ 5 % / > 30 % |
| Anti-sakáda | medián | 400 ms | 240 ms | chyby ≤ 4 % / > 25 % |
| Simonův efekt | interference | 75 ms | 15 ms | chyby ≤ 5 % / > 20 % |
| Mentální rotace 2D | medián | 1800 ms | 650 ms | úspěšnost 100 % / < 80 % |
| N-back | úroveň a úspěšnost | 2-back ≥ 90 % nebo 3-back ≥ 70 % | 3-back ≥ 92 % | – |
| Corsi bloky | rozsah | 6 | 8 | – |
| Rozsah číslic popředu | rozsah | 7 | 9 | – |
| Rozsah číslic pozpátku | rozsah | 5 | 7 | – |
| Paměťová matice | nejvíc políček | 8 | 12 | – |
| Simon | nejdelší sekvence | 10 | 15 | – |
| RSVP čtení | slov/min | 450 | 800 | obě otázky správně (obě úrovně) |
| Číselná pyramida | největší šíře | 55 % | 85 % | – |
| Vizuální maskování | nejkratší expozice | 85 ms | 20 ms | – |
| Dynamická ostrost | nejvyšší rychlost | 1,6 | 3,2 | – |
| Kontrastní citlivost | nejnižší kontrast | 15 % | 2 % | – |
| Periferní záblesky | zachyceno | 80 % | 95 % | odhad středu přesný / chyba > 3 |
| Periferní vzor | správné sektory | 80 % | 95 % | odhad středu přesný / chyba > 3 |
| Časové pořadí | nejmenší rozdíl | 80 ms | 20 ms | – (spodní limit 16 ms = snímek) |
| Odhad průsečíku | průměrná odchylka | 180 ms | 35 ms | – |
| Rytmické ťukání | kolísání (SD) | 35 ms | 9 ms | – |
| Plynulé sledování | čas na terči | 60 % | 94 % | – |
| Kompenzační sledování | čas v zóně 15 % od středu | 60 % | 94 % | – |
| Čas do kontaktu 3D | časová odchylka | 160 ms | 35 ms | místo ≤ 2 % / > 10 % výšky |
| Brockův provázek | reakce při skoku blízko–daleko | 1500 ms | 500 ms | úspěšnost ≥ 95 % / < 75 % |
| Mentální rotace 3D | medián | 2600 ms | 1300 ms | úspěšnost ≥ 95 % / < 75 % |
| Dvojitá úloha | zhoršení rytmu | 35 % | 7 % | správné příklady ≥ 90 % / < 60 % |
| Rozdělená pozornost | průměrná reakce na zelenou | 460 ms | 290 ms | vzdálenost tečky ≤ 8 % / > 30 % |

Reakční hry mají navíc fyziologickou spodní hranici (reakční čas 100 ms, výběrová reakce 150 ms, SART 120 ms): rychlejší medián je anticipace a kolo nedostane pásmo. Brány u Schulteho tabulky, Posnera, reflektoru a dvojité úlohy přibyly 5. 10. 2026 poté, co nástroj `playthrough` (náhodný vstup) dosáhl pásma zkušený.

Úpravy oproti předloze:
- Mentální rotace 3D: zkušený od 1300 ms místo 850 ms; u Shepard–Metzlerových figur jsou kratší časy nereálné.
- Rozdělená pozornost: „velká / malá vzdálenost“ nahrazena čísly (průměrná vzdálenost tečky 8 % a 30 % poloměru plochy).
- Kompenzační sledování: přibyla metrika „čas v zóně“ (15 % poloměru od středu), aby šlo použít stejné pásmo jako u plynulého sledování.
- Časové pořadí: hranice 20 ms zůstává, ale aplikace neumí rozlišit méně než jeden snímek (16 ms při 60 Hz).
- Bez pásma zůstávají: Blikající číslo, Optokinetické pruhy, Periferní čtení, Optický tok (předloha je neobsahuje).
