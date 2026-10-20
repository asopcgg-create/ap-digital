# AP Digital · APCGG Digital

Etapa 1: prototip PWA pentru asociații de părinți. Prima implementare demonstrativă este APCGG Digital, pentru comunitatea Colegiului German Goethe. Nu este un serviciu oficial al școlii sau al asociației. Toate documentele, cifrele, întâlnirile și proiectele sunt fictive.

## Etapa 2 conectată la Supabase

Pe lângă demonstrația locală, codul include un spațiu online separat (`/?mode=online`), cu Supabase Auth, cereri de înscriere, aprobare, roluri verificate prin RLS și date comune pentru cele șapte module. Instanța publică este conectată la proiectul Supabase al asociației; autentificarea se deschide implicit. Demonstrația rămâne la `/?mode=demo`. Într-o instalare fără configurare nu se simulează autentificarea. Ghidul complet este în [ACTIVARE-SUPABASE.md](ACTIVARE-SUPABASE.md). Datele demo nu sunt importate.

## Pornire

Node.js 22.12+ (recomandat Node 24 LTS), npm și un browser modern.

```sh
npm ci
npm run dev
```

Deschide adresa afișată. Pentru versiunea de producție și PWA:

```sh
npm run build
npm run preview
```

Service worker-ul se generează doar la build. Instalarea necesită HTTPS sau localhost; după prima vizită online, shell-ul și resursele statice sunt disponibile offline. Nu există fonturi sau imagini externe. Browserul poate șterge stocarea; modul privat poate limita persistența. O actualizare este preluată automat; reîncarcă aplicația pentru ultima interfață.

## Funcționalități

- **Acasă:** dashboard, anunț și legături către module; cifrele sunt demo.
- **Ședințe:** calendar de întâlniri, ordine de zi, confirmare/anulare participare.
- **Proiecte:** propuneri cu validare, înscriere/retragere voluntar, progres. Coordonatorul și administratorul pot modifica progresul demo.
- **Consultări:** alegere, schimbare și retragere opțiune, număr de voturi pe opțiune și total recalculat; un răspuns local per consultare. Nu reprezintă voturi oficiale.
- **Documente:** căutare, filtrare, citire și descărcare modele TXT, disponibile offline.
- **Profil:** nume fictiv, rol demo, preferință noutăți (nu trimite notificări), instalare și resetare confirmată.

Persistența folosește `localStorage`, cheia `ap-digital:v1`; datele invalide revin la setul inițial. Filele aceluiași browser se sincronizează automat. Nu există sincronizare între utilizatori sau dispozitive. Nu introduce date personale reale. Resetarea elimină propunerile și preferințele locale.

## Structură și etapa 2 / Supabase

`src/data.ts`: tipuri și date demonstrative; `src/storage.ts`: încărcare și limita adaptorului de autentificare; `src/main.tsx`: cele șapte module demo; `src/style.css`: design responsive și Tailwind; `vite.config.ts`: PWA/Workbox.

`AuthAdapter` rămâne limita compatibilă pentru demonstrația locală. Spațiul comun folosește `src/supabase.ts`, `src/AuthPortal.tsx`, `src/OnlineApp.tsx` și `src/onlineRepository.ts`. Configurația publică este descrisă în `.env.example`. Rolurile demo nu sunt citite de spațiul comun. Tabelele, funcțiile tranzacționale și politicile RLS sunt în `supabase/migrations/202610200001_online.sql`.

## Testare

```sh
npx playwright install chromium
npm test
```

Pentru Chrome deja instalat poți folosi `PW_CHANNEL=chrome npm test`. Testele demonstrației cer explicit `?mode=demo`, astfel încât să funcționeze și după activarea autentificării implicite. Rezultatele verificării sunt în `VERIFICARE.md`.

Testele pornesc preview-ul de producție (execută mai întâi build-ul). Acoperă desktop și mobil, confirmare și persistență, creare proiect, voluntariat, schimbare vot fără dublarea totalului, documente și descărcare, rol/progres, resetare, lipsa depășirii orizontale, recuperarea datelor corupte și navigare/reîncărcare offline.

## GitHub

Creează un repository gol `ap-digital` în contul ales. Din acest director:

```sh
git init -b main
git add .
git commit -m "Etapa 1: prototip AP Digital"
git remote add origin https://github.com/UTILIZATOR/ap-digital.git
git push -u origin main
```

Înlocuiește `UTILIZATOR`. Nu publica `.env`, date personale sau `node_modules`. `.gitignore` include excluderile. Proiectul are licență MIT; înlocuiește titularul generic cu entitatea care publică proiectul.

## Publicare gratuită pe Cloudflare Pages

1. Creează un cont Cloudflare și conectează repository-ul în **Workers & Pages → Create → Pages → Connect to Git**.
2. Selectează repository-ul și ramura `main`.
3. Preset: **React (Vite)**. Build command: `npm run build`. Output directory: `dist`. Root: directorul care conține acest README (gol dacă este rădăcina repository-ului).
4. Setează variabila de build `NODE_VERSION` la `24`. Nu sunt necesare secrete.
5. Publică. Cloudflare furnizează o adresă HTTPS `*.pages.dev`. Actualizările pe `main` declanșează build-uri noi.
6. Deschide site-ul online, instalează aplicația din meniul browserului (Safari iOS: Partajează → Adaugă pe ecranul principal), apoi verifică offline după prima încărcare completă.

Configurația urmează [documentația oficială Pages](https://developers.cloudflare.com/pages/configuration/build-configuration/) și [ghidul React](https://developers.cloudflare.com/pages/framework-guides/deploy-a-react-site/). Poți folosi planul gratuit în limitele sale curente. Prototipul nu necesită server sau bază de date. Versiunea demo este publicată la https://ap-digital.pages.dev, din repository-ul https://github.com/asopcgg-create/ap-digital.

## Licență

MIT. Numele APCGG și al școlii sunt folosite doar pentru demonstrație; verificați dreptul de utilizare înaintea unei lansări oficiale.

## Calendar, sarcini și discuții

În Ședințe este disponibil calendarul lunar, navigarea între luni, filtrarea pe o zi și exportul `.ics` pentru import în Apple Calendar, Google Calendar sau Outlook. Importul este o acțiune a utilizatorului; aplicația nu sincronizează automat calendarul și nu solicită acces la contul de calendar. Evenimentele demonstrative sunt pe 28 octombrie și 12 noiembrie 2026, ore Europe/Bucharest, exportate în UTC.

În Proiecte, „Susține ideea” adaugă o singură susținere locală și permite retragerea ei. Deschide „Etape, sarcini și comentarii” pentru planul proiectului. Poți adăuga sarcini într-o etapă, cu responsabil fictiv și termen, bifa finalizarea lor și șterge cu confirmare. Progresul sarcinilor este calculat din sarcinile bifate, separat de progresul general al proiectului. Comentariile sunt text simplu, limitate la 1.000 de caractere, cu nume fictiv din Profil și data adăugării.

Nu există autentificare: aceste funcții sunt demonstrative și modificabile local de oricine folosește browserul. Noile câmpuri sunt adăugate automat datelor existente, fără resetarea voturilor sau a propunerilor. Calendarul și datele locale funcționează și offline după actualizarea PWA.

## Fișa ghidată a proiectului și Comunitatea în cifre

„Propune un proiect” deschide un formular în opt etape și un rezumat: idee, scop/beneficiari, pași, echipă, resurse, calendar, pregătire, evaluare. Exemplele folosesc un colț de lectură. Propunerea necesită titlu, descriere și cel puțin un nivel beneficiar. Restul poate rămâne de completat; fiecare etapă permite cererea de ajutor. Ciornele pot fi salvate incomplet și reluate din lista proiectelor. Câmpurile sunt salvate automat în browser sub cheia `ap-digital:project-draft:<id sau new>`; „Închide formularul” păstrează această ciornă. Resetarea din Profil șterge și ciornele formularelor.

Beneficiarii se aleg dintre Grădiniță, Școală primară, Gimnaziu, Liceu; grupele/clasele sunt opționale, fără nume de copii. Sunt structurate și categoria, tipul activității, amploarea, participanții, ajutorul necesar, resursele, bugetul în lei, durata și acordurile de obținut. Se validează datele calendarului și bugetul. Pașii unui proiect nou devin sarcini; editarea fișei nu suprascrie sarcinile deja existente. Butonul „Vezi / editează fișa proiectului” permite completări ulterioare. Schema `ProjectPlan` și opțiunile comune sunt în `src/projectModel.ts`.

„Comunitatea în cifre” filtrează după nivel beneficiar, categorie, tip și stadiu. Ciornele sunt excluse implicit și pot fi incluse explicit. Graficul arată numărul de proiecte, susțineri sau înscrieri ca voluntar, grupate după categorie, nivel beneficiar, tip ori stadiu. Valorile sunt disponibile și într-un tabel accesibil. Tabelul proiectelor include și bugetul cunoscut; bugetele neestimate nu sunt considerate zero.

Numerele reprezintă proiecte și interacțiuni demo, nu membri unici. Un proiect cu mai multe niveluri beneficiare apare în fiecare grup aferent, deci barele acelei grupări nu se însumează pentru un total unic. Nivelul beneficiar nu reprezintă nivelul persoanei care susține proiectul. Nu se calculează rate de participare fără numărul real al membrilor eligibili și nu se atribuie voturi din consultări proiectelor fără o legătură explicită. Proiectele vechi păstrează interacțiunile; doar cele trei proiecte inițiale primesc metadate demo, iar propunerile vechi fără clasificări rămân „Necompletat”.

## Crearea consultărilor

Butonul „Creează o consultare” permite titlu, explicație, 2–20 opțiuni diferite, selecție unică sau multiplă, termen-limită (ora dispozitivului), proiect asociat opțional și niveluri beneficiare. Consultarea poate fi salvată ca ciornă sau deschisă pentru vot. Ciornele se editează; după deschidere întrebarea și opțiunile existente sunt fixe. Un termen viitor este obligatoriu la deschidere. Expirarea și închiderea manuală blochează modificarea răspunsului și păstrează rezultatele.

La selecție multiplă, fiecare bifare aparține aceluiași răspuns local; procentele se raportează la numărul răspunsurilor, deci pot însuma peste 100%. La retragere se elimină toate selecțiile răspunsului. Consultările noi pornesc de la zero; cele două consultări inițiale păstrează totalurile fictive și voturile locale existente.

Autorul poate permite propuneri de opțiuni. Acestea intră într-o listă de verificare demo, de unde se aprobă sau se resping; doar după aprobare devin votabile. Sunt disponibile filtre pentru consultări deschise, ciorne și închise.

Numărul eligibililor și regula pentru membri noi sunt declarative, pentru simulare. Fără autentificare nu se verifică apartenența sau drepturile de vot. Administrarea este disponibilă tuturor local, iar voturile nu sunt centralizate între persoane. Asocierea unui proiect este salvată și afișată, dar nu introduce voturile în graficele de proiecte și nu transformă automat o consultare în proiect.

## Coordonator și contact din școală

Etapa „Echipa” include numele coordonatorului și opțiunea „Coordonatorul este și persoana de contact din școală”. Dacă este bifată, rezumatul folosește automat coordonatorul; altfel apare un câmp separat. Contactul separat este păstrat când opțiunea este bifată, astfel încât să poată fi recuperat la debifare. Ambele câmpuri pot fi completate ulterior; descrierea veche a echipei nu este interpretată automat ca nume de coordonator. Datele și ciornele existente sunt normalizate fără resetare.

În spațiul comun, ciornele nu se salvează automat în browser: folosește explicit „Salvează ca ciornă”. O salvare refuzată păstrează formularul deschis. Tokenul de sesiune este gestionat de clientul oficial Supabase; conținutul proiectelor nu este copiat în localStorage.


## Aspect comun pentru demo și online

`AppShell.tsx` definește meniul lateral, navigarea mobilă și antetul ambelor versiuni. `HomeIntro.tsx` definește prezentarea și indicatorii paginii Acasă. `Calendar.tsx` primește întâlnirile din Supabase în modul online și datele demonstrative în demo; include filtrare pe zi/lună și export iCalendar. Datele și drepturile de acces ale celor două moduri rămân separate.

Întâlnirile online nu au încă un câmp de final: exportul estimează o durată de o oră, indicată în descrierea evenimentului.

## Adeziune și reconfirmare

Fluxul de cerere PDF semnată și trimisă manual, verificarea administratorului și reconfirmarea anuală sunt descrise în [ADEZIUNE.md](ADEZIUNE.md). Informarea despre date este o versiune de test, de validat înaintea înscrierilor generale.

## Fișiere în Documente

Încărcarea privată a fișierelor de orice format (maximum 25 MB), drepturile și verificările sunt descrise în [DOCUMENTE.md](DOCUMENTE.md).

## Sponsorizări și parteneriate

Propuneri private, gestionarea discuțiilor, documente și indicatori agregați: [SPONSORIZARI.md](SPONSORIZARI.md).
