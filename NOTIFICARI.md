# Notificări pentru înscriere

La trimiterea cererii de înscriere (după confirmarea e-mailului), administratorii activi primesc un e-mail. Solicitantul primește rezultatul după trecerea cererii din așteptare în aprobată sau respinsă; aprobarea include rolul de acces. Crearea contului fără cerere nu trimite alertă administratorului. Nu se trimit notificări retroactive pentru înregistrările anterioare instalării.

Interfața actualizează lista cererilor și indicatorul din Profil la 15 secunde și la revenirea în fereastră. Acasă afișează legătura spre cererile noi. În Profil este disponibilă starea agregată a e-mailurilor: în așteptare, acceptate de expeditor, eroare. Acceptarea de către SMTP nu confirmă livrarea în Inbox.

## Instalare

1. Migrarea `supabase/migrations/202610200002_membership_notifications.sql` creează coada și declanșatorul. A fost aplicată în proiectul APCGG la 20 octombrie 2026.
2. Funcția `supabase/functions/ap-membership-mail/index.ts` a fost publicată în Supabase. Verificarea JWT rămâne activă. Destinatarii și mesajele sunt derivați exclusiv din evenimentele stocate pe server, niciodată din corpul cererii HTTP.
3. `supabase/activate-mail-scheduler.sql` activează pg_net și pg_cron și programează funcția la fiecare minut. A fost aplicat; nu repeta migrarea de creare a tabelelor. Jobul se identifică prin numele `ap-membership-mail`.
4. **Pas rămas:** utilizatorul introduce personal parola de aplicație Gmail în Edge Functions → Secrets, sub numele `AP_SMTP_PASSWORD`. Nu este parola contului AP Digital și nu se introduce în chat, GitHub sau variabile VITE. Setarea SMTP din Auth nu este accesibilă automat funcțiilor.
5. După salvare, se verifică trimiterea cu o cerere reală de test autorizată și aprobarea/respingerea ei. Nu s-au trimis e-mailuri reale de notificare în verificările locale.

## Protecții și limite

- Coada are RLS și nu poate fi citită sau modificată direct de anonimi/membri. Funcțiile de procesare pot fi apelate doar cu rolul serverului și cheia privată din schema nepublică. În browser există doar starea agregată pentru administratori.
- Cheia privată de procesare este generată și folosită doar pe server; nu este expusă sau inclusă în cod. Cheia legacy anon din scriptul de programare este publică și nu acordă dreptul de expediere fără cheia privată.
- Sunt verificate din nou drepturile destinatarilor înaintea expedierii. Alertele pentru cereri deja soluționate sunt anulate.
- Loturi de maximum 5, limită totală de 20 de încercări SMTP/oră, inclusiv reîncercările. Limită precaută pentru Gmail în testare, separată de limitele Supabase Auth.
- Erorile sunt reîncercate de maximum 5 ori, cu întârziere crescătoare; revendicările abandonate expiră după 10 minute. Starea „eroare” necesită investigare manuală. Nu se înregistrează parole, destinatari sau răspunsuri SMTP brute în logurile funcției.
- SMTP nu oferă garanția exact-o-dată: o întrerupere după expediere dar înaintea confirmării în baza de date poate genera un duplicat. Identificatorul mesajului rămâne stabil.
- E-mailurile nu conțin numărul cererii/contractului, documente sau date despre copii. Conținutul este text simplu.

## Verificări

`npm run test:notifications`: 7 teste PostgreSQL și 7 verificări ale funcției cu SMTP simulat. `npm run test:online`: 18 verificări desktop/mobil. Build-ul de producție a trecut. Endpointul publicat răspunde 401 dacă lipsește cheia privată, chiar când cheia anon este validă.
