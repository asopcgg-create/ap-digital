# Verificare Etapa 1 — 17 octombrie 2026

- `npm run build`: trecut (TypeScript + Vite + generare service worker Workbox).
- `PW_CHANNEL=chrome npm test`: 4 teste trecute, desktop 1440 px și mobil 390 px, Chrome headless.
- Confirmare ședință și păstrare după reîncărcare.
- Ordine de zi, creare propunere și înscriere voluntar.
- Vot, schimbare opțiune, total fără dublare și persistență.
- Căutare documente, stare fără rezultate, previzualizare și descărcare TXT.
- Profil, simulare rol coordonator, progres proiect și resetare.
- Reîncărcare și navigare cu rețeaua oprită după activarea service worker-ului.
- Recuperare la JSON corupt în localStorage; lipsa depășirii orizontale pe cele două dimensiuni.
- `npm install` a raportat 0 vulnerabilități la instalare.

Capturi desktop și mobil furnizate separat. Instalarea efectivă pe iPhone/Android și publicarea Cloudflare nu au fost efectuate. Autentificarea și RLS Supabase sunt rezervate etapei 2.

## Corecții după prima publicare

- Rezultate pe opțiuni afișate în voturi și procente, total anunțat accesibil.
- Retragerea votului scade totalul; schimbarea opțiunii păstrează un singur vot.
- Sincronizare între file prin evenimentul storage; eliminarea opțiunilor invalide la încărcare.
- Meniu mobil ascuns și din navigarea cu tastatura; focus păstrat în dialogul documentului.
- Sigla asociației adăugată ca fișier original, inclusă în cache-ul offline.
- Build TypeScript/Vite trecut; 8 teste Playwright trecute pe desktop și mobil.

## Calendar, sarcini și discuții — 18 octombrie 2026

Calendar lunar cu selectarea zilelor și export iCalendar în UTC (orele ședințelor sunt Europe/Bucharest). Exportul include titlu, loc, interval și ordine de zi; rândurile sunt pliate la maximum 75 octeți UTF-8.

Proiectele au susținere locală unică, etape, sarcini cu responsabil fictiv și termen, bifare și ștergere confirmată. Progresul sarcinilor este separat de progresul general editabil al proiectului. Comentariile păstrează autorul fictiv și data; pot fi șterse cu confirmare.

Datele vechi sunt completate cu noile câmpuri la încărcare, păstrând propunerile, voturile și înscrierile. Totul rămâne local, fără notificări sau sincronizare între persoane.

Build TypeScript/Vite/PWA trecut. Din cele 14 verificări desktop/mobil, 12 au trecut în prima rulare; după corectarea etichetei pentru Etapă, cele două teste de sarcini/comentarii au trecut la reluare. Sunt verificate descărcarea .ics și timpii UTC, navigarea lunilor, susținerea/retragerea, adăugarea/bifarea/ștergerea sarcinilor, comentariile, persistența după reîncărcare și migrarea formatului anterior.

## Formular extins și Comunitatea în cifre — 18 octombrie 2026

Formular în etape, selecții structurate pentru niveluri/grupe/clase, activitate, resurse, buget, perioadă, acorduri și stadiu; rezumat cu elementele de clarificat; ciorne automate și explicite; editare și migrare fără pierderea voturilor/înscrierilor.

Grafice filtrabile cu tabele de valori, separarea proiectelor/susținerilor/înscrierilor, excluderea implicită a ciornelor, stări fără rezultate, avertizare pentru beneficiari multipli și lipsa numărului membrilor unici. Cele 14 verificări anterioare au trecut; după clarificarea etichetelor listelor de selectare, au trecut și cele 4 verificări noi (desktop/mobil) pentru creare/editare, ciorne, validare și agregări filtrate. Build TypeScript/Vite/PWA trecut.

## Consultări configurabile — 18 octombrie 2026

Build trecut; 22 teste desktop/mobil trecute. Sunt acoperite crearea unei consultări noi, opțiuni duplicate, ciornă și publicare, proiect asociat, selecție multiplă cu un singur răspuns, retragere, propunere/aprobare de opțiuni, închidere manuală și la termen, persistență și păstrarea voturilor din schema veche. Testele specifice au fost reluate după adăugarea actualizării automate a stării de expirare, fără reîncărcare.

Eligibilitatea și regula pentru membri noi sunt declarative în demo; nu există autentificare sau autorizare reală. Controalele administrative sunt locale și disponibile tuturor. Voturile din consultări nu sunt adunate la statisticile proiectelor.

## 20 octombrie 2026 — coordonator și pregătirea spațiului comun

- Build de producție: trecut, cu manifest și precache PWA generate.
- 26 verificări de browser pentru demonstrație, pe desktop și mobil: trecute. Include coordonator/contact comun, actualizarea numelui, reluarea proiectului, recuperarea contactului separat și compatibilitatea datelor existente.
- 6 verificări de browser pentru autentificare, sesiune, deconectare, acces în așteptare și păstrarea formularului la refuzul salvării: trecute, cu API Supabase simulat, fără conturi reale.
- 12 scenarii PostgreSQL/PGlite: trecute. Migrarea reală, roluri SQL anon/authenticated, politici RLS, izolare între asociații, interdicția auto-aprobării, proprietatea proiectelor, versiuni concurente, unicitate susțineri/voluntariat/voturi, eligibilitate la deschidere, schimbare/retragere răspuns, agregare fără expunerea voturilor individuale, selecție multiplă, moderare, închidere, aprobarea cererilor și drepturi de publicare.
- Niciun proiect Supabase nu a fost creat/conectat; e-mailurile și funcționarea în două conturi reale nu au fost verificate. Activarea urmează ghidul ACTIVARE-SUPABASE.md.
