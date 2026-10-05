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

## 5d. Metriky, pásma a pokrok (fáze 2, hotovo)

Každý výsledek nese standardizované metriky (`DrillResult.metrics`), nad nimiž `core/benchmarks.gd` určuje orientační úroveň začátečník / pokročilý / zkušený (tabulka v `docs/BENCHMARKS.md`).

Historie a pokrok:
- `MetricCatalog` (`core/metric_catalog.gd`): hlavní metrika a směr („méně je lépe“) pro každou hru, klíč varianty z konfigurace (kosmetické volby jako odpočet, zobrazení času nebo chyb se nepočítají, vypnuté přepínače také ne), SD a index únavy (průměr poslední třetiny pokusů / první třetiny) z časů jednotlivých pokusů v `details`.
- `StatsHistory` (`core/stats_history.gd`): čistá logika nad záznamy; `summary()` porovná kolo s průměrem posledních 10 kol stejné varianty a s osobním rekordem, `overview()` dává čísla pro obrazovku pokroku (poslední, nejlepší, průměr posledních 10, změna oproti předchozím 10, posledních 20 hodnot pro graf).
- `StatsStore` (autoload): `user://results.jsonl` (jeden JSON řádek na kolo: čas, hra, varianta, konfigurace, hlavní hodnota, chyby, SD, únava, úroveň, RPE, metriky, surová data) a `user://settings.cfg` (zda se ptát na RPE).
- Výsledková obrazovka: řádky „Oproti průměru posledních kol“, „Osobní rekord“, „Kolísání reakcí (SD)“, „Index únavy“ a volitelný řádek RPE 1–10 (uloží se hned po kliknutí).
- Obrazovka Pokrok (`ui/progress/`): seznam variant podle poslední hry (popisky z `MetricCatalog.OPTION_LABELS` / `VALUE_LABELS`, klíče `VARIANT_*`), detail s čísly a sparkline posledních 20 kol (lepší je vždy nahoře, nejlepší kolo zeleně), přepínač RPE, export CSV (`user://neuro-drills-results.csv`, na webu stažení v prohlížeči) a smazání historie s potvrzením.

Otevřené nápady: „nejlepší 3 z posledních 5 dní“ u prahů, index únavy u her, které neukládají časy pokusů (N-back, MOT).

## 5h. Tréninkový režim (hotovo)

`TrainingPlan` (`core/training_plan.gd`, čistá logika): odhad délky každé hry (`DURATION_S` + režie kroku), návrh sestavy pro zvolenou délku 1–30 min kolečkem přes kategorie (nejslabší podle posledních úrovní první, nehrané kategorie úplně první), uložené sestavy jako JSON (`user://plans.json` přes `StatsStore`). `TrainingSession` drží kroky, index a záznamy dokončených kol; `SceneRouter.start_training()` spouští kroky po sobě, výsledková obrazovka v tréninku nabízí „Další hra (n / m)“ a nakonec „Souhrn tréninku“ (`ui/training/training_summary`). Obrazovka Trénink (`ui/training/training_screen`): posuvník délky, návrh, přidání hry, přesun a odebrání kroků, uložení/načtení/smazání sestavy, odhad celkového času. Zpět ve hře během tréninku trénink ukončí a vrátí na nastavení tréninku.

## 5g. Rozložení pro telefon (hotovo)

`core/layout.gd`: okno se škáluje tak, aby kratší strana měla 720 jednotek na šířku a 480 jednotek na výšku (telefon 412×915 CSS px tak dostane plochu 480×1066 jednotek, písmo zůstane čitelné). Obrazovky pod 700 jednotek šířky přepnou na úzkou variantu: menu v jednom sloupci se záložkami s posuvem, výsledky přes celou šířku s RPE ve dvou řadách a tlačítky 2×2, Pokrok se seznamem nad detailem, panely nastavení her na celou šířku, volby Schulte a Trail Making v jednom sloupci. Hry samotné používají kontejnery a čtvercové desky, takže na výšku fungují bez úprav; audit všech 43 her v 430×660 (nástroj v historii chatu, kontaktní archy) odhalil jen přetékající podněty Stroopu a Flankeru, které si teď zmenšují písmo podle šířky (`TrialDrill._fit_stimulus_label`). 3D scény drží v portrétu zorné pole přes šířku (`Scene3D`). Ztráta fokusu okna během kola (hovor, přepnutí záložky) vrací do nastavení; na webu je při běžícím kole aktivní dotaz prohlížeče před zavřením stránky (`Drill.set_leave_guard`); optický tok si na iOS vyžádá povolení pohybových senzorů (`Drill.request_motion_permission`). Výsledky a panely nastavení jsou v posuvném kontejneru, protože prohlížeč s lištami ukáže na iPhonu jen asi 430×660 CSS px. Webový export má zapnutou virtuální klávesnici (bez ní se na telefonu u textového pole neobjeví). CI vykresluje menu i v rozměru 412×915.

## 5f. Zpětná vazba v aplikaci (hotovo)

Tlačítko „Poznámka“ na výsledkové obrazovce otevře dialog; k textu se automaticky přiloží hra, varianta, řádky výsledku, úroveň, konfigurace, platforma, rozlišení, jazyk a dostupnost dotyku. Obrazovka „Zpětná vazba“ (z menu) umožňuje psát obecné poznámky, číst a mazat uložené a jedním tlačítkem je zkopírovat do schránky nebo stáhnout jako text (`user://neuro-drills-feedback.txt`, na webu stažení). Poznámky zůstávají v zařízení (`user://feedback.jsonl`). „Poslat na GitHub“ (v dialogu i u každé uložené poznámky) otevře předvyplněný formulář nového issue v repozitáři se štítkem `feedback`; po potvrzení v prohlížeči je poznámka centrálně v Issues, odkud ji Claude čte. V aplikaci není žádný token ani server; na zařízení je potřeba přihlášení na GitHub.

## 5e. Export a nasazení (hotovo)

- `export_presets.cfg`: preset **Web** (GL Compatibility, bez vláken, takže běží i na GitHub Pages, které neumí nastavit COOP/COEP hlavičky; bez PWA) a **Windows Desktop** (x86_64, pck vložený do exe, bez podpisu a bez změny ikony, aby export nepotřeboval rcedit). Složky `tools/`, `tests/`, `docs/` se do balíčku nedávají.
- `tools/godot.sh export <preset>` stáhne šablony a vyexportuje do `build/` (v `.gitignore`).
- `.github/workflows/release.yml`: při pushi do `main` sestaví web i Windows, web nasadí na GitHub Pages (`https://<uživatel>.github.io/neuro-drills/`), oba buildy nechá jako artefakt; při tagu `v*` je navíc připojí k GitHub release. Ručně jde spustit přes „Run workflow“.
- Jednorázově nutné: v nastavení repozitáře Settings → Pages → Source: GitHub Actions.
- PWA: webový preset má zapnutou progresivní webovou aplikaci (manifest, service worker, offline stránka `assets/icon/offline.html`, ikony 144/180/512 z `assets/icon/`, barva motivu `#1b1e26`, režim standalone, libovolná orientace). Na telefonu jde aplikaci „Přidat na plochu“ a spouští se bez adresního řádku; service worker drží poslední načtenou verzi, nová verze se stáhne při dalším otevření. Vlastní ikona je `icon.svg` (mřížka s modrou buňkou), PNG velikosti generuje `tools/godot.sh icons`; stejná ikona slouží jako boot splash na tmavém pozadí. Složka `build/` má `.gdignore`, aby exportované soubory neimportoval editor.
- Webový build byl ověřen v headless Chromiu (menu, Pokrok, bez chyb v konzoli). Na webu se historie ukládá do IndexedDB prohlížeče (Godot `user://`), export CSV se stáhne jako soubor.

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


## 8. Backlog (zapsáno 4. 10. 2026, priority potvrzeny maintainerem)

Pracnost: M = do hodiny, S = půl dne, L = den a víc. Pořadí v rámci oblasti je návrh.

### A. Mobil a web (priorita 1)
- [x] A1 (S) Projít všech 43 her na výšku v rozměru Safari 430×660 a opravit, co přetéká.
- [x] A2 (S) Dotyk a senzory u her čtoucích polohu ukazatele: plynulé a kompenzační sledování, Brockův provázek, optický tok s nakláněním. Ověřit na telefonu.
- [x] A3 (M) Posuvný kontejner u nastavení her s mnoha volbami ověřit (Trail Making, RSVP, 3D hry).
- [x] A4 (M) Pauza časovače při přepnutí aplikace do pozadí; varování při zavření záložky uprostřed kola.
- [ ] A5 (M) Ikona pro Windows exe. Odloženo: rcedit je windows binárka, na linuxovém runneru by potřebovala wine; řešení je export Windows na windows runneru nebo bez ikony.

### B. Tréninkový režim (priorita 2)
Zadání od maintainera: délka tréninku nastavitelná 1–30 minut; sestavu navrhne aplikace podle kategorií a slabších pásem, maintainer ji může upravit a uložit jako vlastní pojmenovanou sestavu (může jich být víc).
- [x] B6 (L) Sestava: hry za sebou bez návratu do menu, přechodová obrazovka mezi hrami, souhrn na konci (celkový čas, výsledky, úrovně, RPE).
- [x] B7 (S) Doporučená denní sestava podle kategorií a podle nejslabšího pásma; během týdne se vystřídají všechny kategorie.
- [x] B8 (S) Adaptivní obtížnost: po dvou kolech v pásmu „zkušený“ nabídnout těžší variantu (větší mřížka, vyšší N-back, kratší expozice).
- [x] B9 (S) Týdenní souhrn na obrazovce Pokrok: kola, minuty, zlepšení za týden.

### C. Data a pokrok
- [x] C10 (M) Import historie ze souboru: tlačítka Záloha (JSON Lines ke stažení) a Import (na webu přes `<input type=file>`, jinde přes `FileDialog`) na obrazovce Pokrok; sloučení podle id záznamu.
- [x] C11 (M) Index únavy u N-back (časy odpovědí) a MOT (čas výběru za kolo) v `details.times_ms`.
- [x] C12 (M) U prahových her (`MetricCatalog.THRESHOLD_DRILLS`) řádek „nejlepší 3 z posledních 5 dní“ ve výsledcích i v Pokroku (`StatsHistory.stable_best`).
- [x] C13 (M) Graf v Pokroku s rozsahem 20 / 50 / vše a čárkovanými hranicemi pásem pokročilý a zkušený (`Benchmarks.bounds_for`), pokud leží blízko dat.
- [~] C14 (M) Revize pásem v `docs/BENCHMARKS.md` podle reálných dat (po pár týdnech hraní). První část hotová 5. 10. 2026: brány chybovosti u Schulteho tabulky, reakčního času, Posnera, reflektoru a dvojité úlohy a spodní hranice reakčních časů (anticipace bez pásma), protože průchod náhodným vstupem dosahoval pásma zkušený; `playthrough` teď vypisuje pásmo každého kola a náhodný vstup žádné nedostane.

### D. Zvuk
- [x] D15 (S) Tóny správně / špatně / hotovo: autoload `Sfx` syntetizuje krátké tóny při startu (žádné zvukové soubory); vypínatelné (`StatsStore.sound_enabled`, přepínač v Nastavení).
- [x] D16 (S) Metronom (tik na každý předehraný úder) u rytmického ťukání; sluchové varianty reakčního času (tón místo barvy) a Go/No-Go (vysoký tón = klikni, hluboký = nic), klíč `auditory` v konfiguraci tvoří vlastní variantu bez pásma.

### E. Aplikace jako celek
- [x] E17 (M) Obrazovka Nastavení (`ui/settings/`): jazyk (ukládá se), motiv, velikost písma (globální měřítko `Layout.text_scale` 0,9 / 1 / 1,15), zvuky, RPE, odkazy na Pokrok a Zpětnou vazbu, smazání historie. Menu má místo přepínačů jazyka a motivu tlačítko Nastavení.
- [x] E18 (S) Nápověda u každé hry: popis (jak na to) doplňuje generovaný řádek `MetricCatalog.help_text` – co hra měří, kterým směrem je lépe a hranice pásem pro zvolené nastavení (klíče `METRIC_*`, `HELP_*`).
- [x] E19 (M) Vlastní písmo s podporou češtiny: Nunito (text) a Baloo 2 (nadpisy), obě OFL, součást motivu.
- [x] E20 (L) `tools/godot.sh playthrough` (`tools/playthrough_drills.gd`): každou hru spustí bez odpočtu a náhodně ji „hraje“ (tlačítka, mezerník, kliknutí) se zrychleným časem, dokud neskončí; kontroluje metriky, řádky výsledků, záznam historie a pásmo. Běží i v CI.

### F. Hry
- [ ] F21 Úpravy stávajících her podle zpětné vazby z hraní (issues se štítkem `feedback`). Zatím: na iOS se šipky, kolečka a další symboly kreslily jako prázdný rámeček (webový export nemá systémové fonty a Nunito/Baloo je neobsahují) – přibyl `assets/fonts/symbols.ttf` (podmnožina DejaVu Sans) jako fallback všech písem motivu; Pokrok na telefonu nešel posouvat ani opustit (celá obrazovka teď roluje, varianta se vybírá z rozbalovacího seznamu); seznamy nešly posouvat tažením prstu, jen posuvníkem (`DragScroll` na každém `ScrollContainer`); kategorie v menu šly na telefonu přepínat jen šipkami (pruh pilulek posouvatelný tažením); periferní vzory šly na telefonu odpovědět jen klávesnicí – přibyla řada tlačítek 1–8 pod scénou (našel to průchod E20).
- [ ] F22 Nové hry jen pokud nějaká citelně chybí.
- [x] F25 Dotykové ovládání tréninku: kroky se přesouvají tažením za úchyt (na telefonu bez šipek), ovládací prvky jsou viditelná tlačítka.
- [x] F26 Audit všech 43 her na 430×660 ve stavu hry: bez zásadních problémů; zvětšena kolečka Trail Making (0,12 strany místo 0,10).
- [~] F30 Instrukce hry během odpočtu: vyzkoušeno (karta nad plochou, pak text pod „Start za 3“) a na přání správce odstraněno; krok tréninku vysvětluje `TrainingBrief`, rychlý start panel nastavení.
- [x] F31 Bezpečné okraje iPhonu (výřez, domovský indikátor): hlavička webu vystavuje `env(safe-area-inset-*)`, `Layout.safe_insets` je převede na jednotky a kořen aplikace se o ně odsadí.
- [x] F35 Obrazovky bez panelu: variace `Screen` je prázdný styl, obsah sedí na pozadí mezi lištami se stejnými okraji na telefonu i na desktopu.
- [x] F34 Odznaky mají barevné medailony (SVG v `assets/badges/`): na profilu vedle názvu, ve výsledcích u řádku „Nový odznak“; nezískané jsou vybledlé.
- [x] F33 Pevná spodní lišta s ikonami (Hry, Trénink, Pokrok, Profil, Nastavení) a pevná horní lišta (název obrazovky, série a denní cíl, zpětná vazba, konec; šipka zpět na obrazovkách bez záložky). Tlačítka ze spodku menu a hlavičky obrazovek se přesunuly do lišt; hra, výsledky, brief a onboarding běží bez lišt.
- [x] F32 Výsledky: hlavní řádky a sekce „Více“ (další úroveň, kolísání, únava, nejlepší 3 z 5), aby se výsledek na telefonu vešel bez posouvání.
- [x] F28 Odpočet se pletl s podněty (SART: „3“ z odpočtu vs. zakázaná trojka): odpočet říká „Start za 3“ v barvě akcentu s názvem hry nad ním, končí zeleným „Teď!“ a půlsekundovou prázdnou pauzou před prvním podnětem; totéž v Schulteho tabulce.
- [x] F29 Trénink: před každým krokem obrazovka s názvem hry, variantou, popisem a nápovědou (co měří, pásma) a tlačítkem Start; hráč tak ví, co po odpočtu hraje. Tlačítko „Ukončit trénink“ vrátí na sestavu.
- [x] F27 Rychlejší načtení: Nunito a Baloo 2 zúženy na latinku s češtinou (z 960 kB na 230 kB se symboly); skript v hlavičce webu nechá novou verzi service workeru převzít stránku a jednou ji znovu načíst, takže se aktualizace projeví hned při dalším otevření (ověřeno v Chromiu proti lokálnímu serveru).
- [x] F23 Profil (`ui/profile/`): série, úroveň s XP, denní cíl, posledních 7 dní a všechny odznaky s popisem; menu má místo řady odznaků jen kompaktní řádek s tlačítkem „Profil · odznaky n / 12“.
- [x] F24 Úvod při prvním spuštění (`ui/onboarding/`, tři stránky: co to je, jak funguje trénink, kde jsou data) s tlačítkem na první pětiminutový trénink; znovu dostupný z Nastavení. Hráč s historií ho neuvidí.

### G. Gamifikace a hravější grafika (na vedlejší větvi)
Zadání od maintainera: hry jsou monotónní a jednotvárné; chce hravější, roztomilé provedení (dětský styl, karikatura, kreslení rukou) a lepší gamifikaci. Vznikne na větvi bokem, aby šlo styl zahodit, kdyby se nelíbil.
- [x] G23 (S) Návrh stylu: paleta, tvary, písmo, ilustrační jazyk; ukázka na menu, Schulte a jedné reakční hře jako obrázky ke schválení před plošnou implementací.
- [x] G24 (L) Druhý motiv s přepínačem: maintainer vybral styl 3 („měkké oblouky“, Baloo 2 + Nunito, zaoblené karty, 3D tlačítka) v tmavé variantě jako výchozí a světlou jako přepínatelnou. Oba motivy generuje `tools/make_theme.gd` (`godot.sh theme`) z palet do `ui/theme/{dark,light}_theme.tres`; přepínač zatím v patičce menu (přesune se do Nastavení, E17).
- [~] G25 (L) Vizuální prvky her: zaoblené „3D“ buňky a pady dává motiv; animace správně (krátké zvětšení `Drill.pop`) a špatně (zatřesení `Drill.shake`) u padů a Schulteho buněk. Maskot zatím ne – maintainer ho ve výběru gamifikace nezvolil; ručně kreslené terče až podle ohlasu na styl.
- [x] G26 (S) Gamifikace: denní série, body za kolo, odznaky za pásma a milníky, denní cíl; `core/gamification.gd` vše odvozuje ze záznamů (nic navíc se neukládá, jen už ukázané odznaky v `settings.cfg`); menu ukazuje sérii, úroveň s XP lištou, dnešní minuty proti délce tréninku a odznaky, výsledky řádek „Body“ a nový odznak, souhrn tréninku body a denní cíl.
- [x] G27 (M) Zvukové efekty ladící se stylem: krátké měkké syntetizované tóny z D15 (správně dvoutón nahoru · špatně hluboký tón · hotovo trojzvuk).
