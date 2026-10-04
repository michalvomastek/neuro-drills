# Neuro drills – plán projektu

Stav: **fáze 1, 3 a 4 hotové** (3. 10. 2026). Otázky z kapitoly 7 jsou rozhodnuté: platí výchozí předpoklady, jen téma je tmavé (otázka 6). Aplikace má 43 drillů v devíti kategoriích včetně 3D, senzorových a dvojitých úloh; další je fáze 2 (historie výsledků a přehled pokroku) a fáze 5 (export).

## 1. Vize

Aplikace se sbírkou krátkých kognitivních tréninkových her („drillů“): pozornost, periferní vidění, pracovní paměť, rychlost reakce, inhibice. Každý drill

- trvá 1–5 minut a dá se hrát opakovaně,
- má jasně měřitelný výstup (čas, chyby, skóre),
- ukládá historii výsledků, aby šel sledovat pokrok,
- je samostatný modul, který se do aplikace jen zaregistruje.

Technologie: Godot 4.7 (GDScript se statickým typováním), renderer GL Compatibility (běží i ve webovém exportu a na slabším hardwaru).

## 2. Architektura

### Struktura složek (návrh)

```
res://
├── project.godot
├── CLAUDE.md                 # konvence pro práci Claude v repozitáři
├── docs/PLAN.md              # tento dokument
├── tools/
│   ├── godot.sh              # headless Godot: import, kontrola skriptů, testy, screenshoty, API dokumentace
│   └── screenshot.gd         # renderer scény do PNG (pro kontrolu UI bez displeje)
├── autoload/                 # singletony: SceneRouter, Settings, StatsStore, DrillRegistry
├── core/                     # sdílené typy: Drill (základ), DrillResult, DrillDefinition
├── drills/
│   └── schulte_table/
│       ├── schulte_table.tscn      # scéna (UI)
│       ├── schulte_table.gd        # řídicí skript scény
│       ├── schulte_logic.gd        # čistá logika bez uzlů: generování, vyhodnocení tahu, měření
│       └── schulte_config.gd       # Resource s nastavením varianty
├── ui/                       # hlavní menu, výsledky, nastavení, theme
├── assets/                   # fonty, zvuky, ikony
└── tests/                    # headless testy logiky
```

### Principy

1. **Logika oddělená od scény.** Generování mřížky, vyhodnocení kliku a měření času žijí v třídách bez Node (`RefCounted`). Scéna je jen tenká vrstva, která překládá vstup na volání logiky a vykresluje stav. Logika se testuje headless bez UI.
2. **Drill je plug-in.** Každý drill popisuje `DrillDefinition` (id, název, popis, kategorie, cesta ke scéně, výchozí konfigurace). `DrillRegistry` z definic staví menu. Přidání hry = nová složka + jedna registrace.
3. **Společný životní cyklus.** Základní třída `Drill` dává signály `started` a `finished(result)` a metody `configure(config)`, `start()`, `abort()`. Všechny drilly produkují `DrillResult` (id drillu, použitá konfigurace, čas, chyby, skóre, časové razítko, detailní data). Zpracovává ho společná obrazovka výsledků a `StatsStore`.
4. **Data lokálně.** Historie výsledků a nastavení v `user://` (JSON). Žádný server, žádné účty. Export do CSV jako volitelná funkce později.
5. **Responzivní UI.** Pouze Control uzly a kontejnery, žádné pevné pixelové pozice. Stretch mode `canvas_items` + `expand` už je v projektu nastaven. Myš i dotyk.
6. **Lokalizace od začátku.** Texty přes `tr()` a překladové CSV, i když bude zprvu jen jeden jazyk. Dodatečné zavádění je dražší.
7. **Reprodukovatelná náhoda.** Logika dostává generátor náhodných čísel nebo seed, aby šly testy psát deterministicky a aby šla případně nabídnout „tabulka dne“.

## 3. Roadmapa

| Fáze | Obsah | Výstup |
|---|---|---|
| 0 | Plán, konvence, nástroje pro headless Godot, rozhodnutí z otázek | hotovo |
| 1 | Jádro (`Drill`, `DrillResult`, `DrillRegistry`, router) + minimální shell (menu, hra, výsledek) + **Schulte table v1** + lokalizace CZ/EN + testy logiky + CI | hotovo |
| 2 | Shell aplikace: hlavní menu, nastavení, ukládání historie, přehled pokroku (graf) | použitelná aplikace |
| 3 | Varianty Schulte: velikost 3×3 až 7×7, přemíchání po kliknutí, ztlumení nalezených, obrácené pořadí, písmena, červeno-černá Gorbov–Schulte, pětitabulkový Schulteho test s indexy ER/WU/PS | hotovo |
| 4a | Reakční rodina na společném základu `TrialDrill`: reakční čas, výběrová reakce, Go/No-Go, Stroop, Flanker | hotovo |
| 4b | Paměťová rodina: N-back, Corsi bloky, rozsah číslic, paměťová matice, Simon (sdílený `SpanTracker` pro adaptivní délku) | hotovo |
| 4c | Pozornost a čtení: Trail Making, vizuální hledání, SART, přepínání úloh, RSVP čtení, číselná pyramida, blikající číslo, počítání | hotovo |
| 4d | Z dokumentu „Neuro training drills“: anti-sakáda, Simonův efekt, Posnerova nápověda, periferní záblesky, vizuální maskování, časové pořadí, adaptivní Go/No-Go | hotovo |
| 4e | Pohybové: sledování více objektů, odhad průsečíku, kompenzační sledování, plynulé sledování, dynamická ostrost, rytmické ťukání, pohyblivý Trail Making | hotovo |
| 4f | Mentální rotace, hledání reflektorem (shader mlhy), kontrastní citlivost (Gaborův shader), optokinetické pruhy (shader) | hotovo |
| 4g | 3D a senzorové: čas do kontaktu (3D), Brockův provázek (3D), mentální rotace 3D, optický tok s úhybem (náklon zařízení, nebo šipky a myš) | hotovo |
| 4h | Kombinované: dvojitá úloha (rytmus + počítání), rozdělená pozornost (sledování + Go/No-Go), periferní vzor, periferní čtení | hotovo |
| 5 | Export: Windows/Linux/macOS, web (GitHub Pages), Android; CI s automatickým buildem | distribuce |

Fáze 1 a 2 lze podle odpovědi na otázku 3 částečně prohodit.

## 4. Schulte table – koncept

Klasická Schulteho tabulka je mřížka 5×5 s náhodně rozmístěnými čísly 1–25. Úkol: najít čísla postupně od 1 do 25 co nejrychleji, přičemž pohled zůstává fixovaný na středu tabulky a čísla se hledají periferním viděním, tedy bez čtení řádek po řádku a bez těkání očima. Trénuje se:

- šíře zorného pole a periferní vnímání (základ rychločtení),
- rychlost vizuálního hledání,
- koncentrace a odolnost proti rozptýlení.

Jako **Schulteho test** (psychodiagnostika pozornosti) se řeší pět tabulek za sebou a z časů T1–T5 se počítá:

- efektivita práce ER = (T1 + T2 + T3 + T4 + T5) / 5,
- stupeň zapracování WU = T1 / ER (pod 1,0 znamená dobrý rozjezd),
- psychická stabilita PS = T4 / ER (do 1,0 znamená dobrou výdrž).

Známé varianty:

- **velikost mřížky** od 3×3 (děti, začátek) po 8×8 i 10×10 (pokročilí), případně obdélníková,
- **písmena** místo čísel (abeceda), nebo smíšené,
- **Gorbov–Schulte červeno-černá**: 25 černých čísel (1–25) a 24 červených (1–24); hledá se střídavě černé vzestupně a červené sestupně (1 černá, 24 červená, 2 černá, 23 červená …), trénink přepínání pozornosti,
- **dynamická**: po každém správném kliku se čísla znovu zamíchají,
- **skrývání nebo ztlumení nalezených** čísel (ulehčuje) proti tabulce beze změny (klasika, těžší),
- **obrácené pořadí** (od nejvyššího čísla),
- barevné pozadí buněk nebo různé fonty jako vizuální šum.

## 5. Schulte table – návrh první verze

**Průběh**

1. Obrazovka před startem: zvolená velikost (výchozí 5×5), krátká instrukce („Dívej se do středu a hledej čísla od 1 periferním viděním“), tlačítko Start (funguje i mezerník a Enter).
2. Volitelný odpočet 3-2-1, poté se objeví mřížka a začne běžet čas.
3. Hráč kliká nebo ťuká na čísla v pořadí. Správný klik: žádná nebo velmi nenápadná reakce (nastavitelné). Špatný klik: krátký záblesk okraje buňky, započítá se chyba, čas běží dál.
4. Po posledním čísle se měření zastaví a zobrazí se výsledek.

**Mřížka**

- `GridContainer` N×N, čtvercové buňky stejné velikosti, celá mřížka čtvercová a vystředěná, přizpůsobí se velikosti okna.
- Čísla velkým fontem s tabulkovými číslicemi, vysoký kontrast (klasicky černá na bílé). Žádné hover efekty, prozrazovaly by polohu kurzoru vůči buňkám.
- Volitelný fixační bod uprostřed mřížky.
- Časomíra během hry skrytá (rozptyluje), lze zapnout.

**Měření (v milisekundách)**

- celkový čas od zobrazení mřížky po poslední správný klik,
- čas k jednotlivým číslům (split times), z toho nejpomalejší číslo a průměr na číslo,
- počet chybných kliků a u kterých čísel k nim došlo,
- čas do prvního správného kliku.

**Výsledek**: čas, chyby, průměr na číslo, nejpomalejší číslo; později porovnání s osobním rekordem a graf. Tlačítka: Znovu (stejná konfigurace), Nastavení, Menu.

**Nastavení v1**: velikost mřížky (3–7), odpočet (zapnuto/vypnuto), fixační bod (zapnuto/vypnuto), zobrazovat další hledané číslo (pomoc pro začátečníky). Ostatní varianty ve fázi 3.

**Logika (testovatelná headless)**

- `SchulteLogic.new(config, rng)` vygeneruje permutaci 1..N²; se seedem je reprodukovatelná.
- `register_click(cell_index, time_ms)` vrátí výsledek tahu (správně / chyba / dokončeno) a ukládá split times a chyby.
- `get_result()` vrátí `DrillResult`.

## 5b. Drilly z pokusů (`TrialDrill`)

Všechny drilly kromě Schulte stojí na společné třídě `core/trial_drill.gd`: panel nastavení (počet pokusů, odpočet, případné další volby), herní rám s tlačítkem Zpět a průběhem „3 / 20“, odpočet, zrušitelné čekání `_wait()` a pomocné plochy (`_make_pad`, `_make_side_pads`, `_make_stimulus_label`). Každý drill má logiku v samostatné třídě (`*_logic.gd`, testovaná headless) a jen tenký skript scény. Reakční časy shrnuje `ReactionStats` (průměr, medián, nejlepší, směrodatná odchylka). Výsledková obrazovka zobrazuje jen řádky, které drill sám dodá v `summary_rows`. Drilly s adaptivní délkou (Corsi, rozsah číslic, Simon, blikající číslo) sdílejí `SpanTracker`; drilly s číselným vstupem sdílejí klávesnici `_make_keypad()` a mapování kláves `_keypad_label_from_event()`.

## 5c. Co z dokumentu „Neuro training drills“ není implementováno a proč

- **3D drilly** jsou hotové ve zjednodušené podobě (`core/scene_3d.gd`: SubViewport s vlastním světem). Renderer GL Compatibility nemá hloubku ostrosti, proto Brockův provázek „rozmazání“ nahrazuje ztlumením písmen mimo zvýrazněný korálek. Skutečnou konvergenci očí plochá obrazovka vyvolat nedokáže; jde o trénink přeostřování pozornosti mezi hloubkami.
- **Optický tok s úhybem** používá gravitační senzor (`Input.get_gravity()`) na mobilu; na desktopu šipky nebo myš. Na mobilu zatím neotestováno.
- **Zvukové varianty** (dual N-back se zvukem, zvukový metronom): v projektu nejsou zvuky (rozhodnutí z otázky 6); rytmické drilly používají vizuální metronom.
- **Expanding Optical Tunnel**: subjektivní bez měřitelného výstupu; vynecháno.
- **Flash Memory / Grid Pattern Shift** je totéž co paměťová matice; **Visual Search / Cancellation** pokrývá vizuální hledání a hledání reflektorem.

## 6. Nástroje, testování, kvalita

Co už je připravené v této větvi:

- `CLAUDE.md`: konvence pro práci v repozitáři (jazyk, styl kódu, postup před commitem).
- `tools/godot.sh`: headless Godot bez instalace. Příkazy `version`, `import`, `check`, `test`, `docs`, `screenshot`, `exec`. Kontrola `check` načítá skripty uvnitř běžícího projektu (`tools/check_scripts.gd`), takže zná i autoloady. Binárku hledá v proměnné `GODOT_BIN`, pak v `../godot/` (tvoje rozložení na Windows), jinak si stáhne Godot 4.7-stable pro Linux (cloud).
- `tools/screenshot.gd`: vyrenderuje scénu softwarovým OpenGL (Mesa llvmpipe pod Xvfb) a uloží PNG. Ověřeno v cloudu: 1280×720 za zhruba 2 s. Díky tomu můžu UI vidět i tam, kde není displej.
- `project.godot`: vybraná GDScript varování povýšena na chyby (netypované deklarace, nebezpečný přístup k metodám a vlastnostem, nebezpečné argumenty volání, nepoužité proměnné). `tools/godot.sh check` tak odhalí překlepy a typové chyby bez spuštění hry. Ověřeno: volání neexistující metody na typované proměnné kontrola bez tohoto nastavení nechytí, s ním ano.
- Offline reference API: `tools/godot.sh docs` vygeneruje XML dokumentaci všech tříd přímo z binárky (v cloudu je docs.godotengine.org blokovaná).

Hotovo ve fázi 1:

- **Jednotkové testy logiky** v `tests/` (`tools/godot.sh test`): vlastní runner `tests/run_tests.gd`, základ `TestCase`, testy `test_schulte_logic.gd` (permutace, reprodukovatelnost seedu, průběh kliků, chyby, časy, výsledek, konfigurace).
- **CI (GitHub Actions)** `.github/workflows/ci.yml`: při každém pushi stáhne Godot 4.7 (s cache), spustí `import`, `check`, `test` a nahraje screenshoty menu a nastavení Schulte jako artefakt.

Další: export web buildu na GitHub Pages (fáze 5).
- **Postup před každým commitem**: `import`, `check`, `test`, screenshot změněných scén.

## 7. Otázky k rozhodnutí (rozhodnuto 3. 10. 2026)

Všechny předpoklady níže platí, s jedinou změnou: u otázky 6 je téma **tmavé**.

1. **Cílové platformy a orientace.** Jen Windows desktop, nebo i web v prohlížeči a mobil (Android/iOS)? Na šířku, na výšku, nebo obojí?
   Předpoklad: Windows + web, UI na šířku s responzivním layoutem, aby šel mobil přidat později. Výchozí rozlišení 1280×720.
2. **Jazyk UI.** Čeština, angličtina, nebo obojí přes lokalizaci od začátku?
   Předpoklad: obojí, primárně čeština, texty přes překladové CSV.
3. **Rozsah první verze.** Jít rovnou do Schulte table (aplikace se spustí přímo do hry) a shell dodělat potom, nebo nejdřív minimální menu → hra → výsledek?
   Předpoklad: minimální shell hned, protože je levný a vynutí správnou strukturu; historie a nastavení až ve fázi 2.
4. **Schulte v1 detaily.** (a) Start časomíry tlačítkem Start s odpočtem, nebo při prvním kliku? (b) Chybný klik jen započítat a jemně zablikat, nebo i časová penalizace či zvuk? (c) Nalezená čísla nechat beze změny (klasika), nebo jemně ztlumit? (d) Fixační bod ve středu?
   Předpoklad: Start s volitelným odpočtem; chyby jen počítat a zablikat; nalezená čísla beze změny s volbou ztlumení; fixační bod volitelný, výchozí vypnutý.
5. **Komu je to určeno a data.** Pro tebe osobně, nebo i pro klienty (název složky „Agile Fitness Coach App“ naznačuje koučink)? Potřebuješ více profilů uživatelů a export výsledků (CSV)?
   Předpoklad: jeden uživatel, lokální historie v `user://`, export CSV později.
6. **Vizuální styl a zvuk.** Světlé (klasická černá čísla na bílé) nebo tmavé téma? Preference fontu a barev? Zvuky (klik, chyba, konec)?
   Předpoklad: minimalismus, Schulte světlá s vysokým kontrastem, přepínač tématu později; výchozí font Godotu; bez zvuků v první verzi.
7. **Testy a CI.** Chceš GitHub Actions (headless kontrola a testy při každém pushi; u privátního repozitáře čerpá bezplatné minuty)? Testovací framework: vlastní minimální runner, GUT, nebo gdUnit4?
   Předpoklad: CI ano, vlastní minimální runner.
8. **Verze Godotu.** Máš přesně 4.7-stable (Nápověda → O aplikaci)? V cloudu používám `4.7.stable.official.5b4e0cb0f`. Zůstáváme u GDScriptu, ne C#?
   Předpoklad: 4.7-stable, GDScript.
9. **Pracovní postup.** Mám pro každou funkci otevírat pull request k review, nebo pushovat do své větve a ty si ji mergeuješ sám? Kód a commity anglicky, komunikace česky?
   Předpoklad: větev `claude/…`, pull request jen na vyžádání; kód a commity anglicky, komunikace česky.

