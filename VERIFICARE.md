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
