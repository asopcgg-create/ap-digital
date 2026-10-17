# AP Digital · APCGG Digital

Etapa 1: prototip PWA pentru asociații de părinți. Prima implementare demonstrativă este APCGG Digital, pentru comunitatea Colegiului German Goethe. Nu este un serviciu oficial al școlii sau al asociației. Toate documentele, cifrele, întâlnirile și proiectele sunt fictive.

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
- **Consultări:** alegere și schimbare opțiune, rezultate recalculabile; un răspuns local per consultare. Nu reprezintă voturi oficiale.
- **Documente:** căutare, filtrare, citire și descărcare modele TXT, disponibile offline.
- **Profil:** nume fictiv, rol demo, preferință noutăți (nu trimite notificări), instalare și resetare confirmată.

Persistența folosește `localStorage`, cheia `ap-digital:v1`; datele invalide revin la setul inițial. Nu există sincronizare între utilizatori sau dispozitive. Nu introduce date personale reale. Resetarea elimină propunerile și preferințele locale.

## Structură și etapa 2 / Supabase

`src/data.ts`: tipuri și date demonstrative; `src/storage.ts`: încărcare și limita adaptorului de autentificare; `src/main.tsx`: cele șase module; `src/style.css`: design responsive și Tailwind; `vite.config.ts`: PWA/Workbox.

`AuthAdapter` definește sesiunea și deconectarea, `Role` definește membru/coordonator/administrator, iar `canCoordinate` controlează doar interfața. Nu există autentificare reală sau protecție de date prin aceste roluri. `.env.example` rezervă configurația publică pentru integrarea ulterioară, fără a inițializa un client Supabase.

Pentru etapa 2: implementează adaptorul cu Supabase Auth; creează tabele pentru asociații, membri, ședințe, confirmări, proiecte, voluntari, consultări, opțiuni, voturi și documente; înlocuiește salvarea locală cu un repository asincron. Impune izolarea pe asociație și autorizarea cu RLS pe fiecare tabel și bucket. Rolul trebuie citit din apartenența verificată pe server, nu din câmpuri editabile în browser. Impune unicitate `(consultation_id, user_id)` și `(meeting_id, user_id)`. Nu publica niciodată cheia `service_role` în Vite. Planifică migrarea/resetarea datelor demo separat; nu le importa în producție.

## Testare

```sh
npx playwright install chromium
npm test
```

Pentru Chrome deja instalat poți folosi `PW_CHANNEL=chrome npm test`. Rezultatele verificării sunt în `VERIFICARE.md`.

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

Configurația urmează [documentația oficială Pages](https://developers.cloudflare.com/pages/configuration/build-configuration/) și [ghidul React](https://developers.cloudflare.com/pages/framework-guides/deploy-a-react-site/). Poți folosi planul gratuit în limitele sale curente. Prototipul nu necesită server sau bază de date. Nu a fost creat automat un repository sau un deployment.

## Licență

MIT. Numele APCGG și al școlii sunt folosite doar pentru demonstrație; verificați dreptul de utilizare înaintea unei lansări oficiale.
