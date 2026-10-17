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
