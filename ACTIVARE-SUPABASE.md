# Activarea spațiului comun APCGG Digital

Activat la 20 octombrie 2026: proiectul Supabase `prgtvtuwsmhpsmbkkgmp`, regiunea UE Irlanda. Migrarea inițială a fost executată cu acordul titularului, prin SQL Editor; cele 11 tabele au RLS activ. Configurația publică este salvată în Cloudflare Pages, iar adresa implicită deschide autentificarea. Demonstrația separată rămâne la `/?mode=demo`. Nu au fost importate datele demo. Primul cont al asociației și aprobarea sa nu au fost încă efectuate. Pașii de mai jos rămân ghid de instalare; nu reaplica migrarea pe proiectul deja configurat.

## 1. Cont și proiect

Deschide https://supabase.com/dashboard. Creează sau conectează contul destinat asociației; pentru continuitate se poate folosi asopcgg@gmail.com. Parola și confirmarea adresei sunt introduse de titularul contului. Creează proiectul `ap-digital` și păstrează separat parola bazei de date. Alege regiunea corespunzătoare utilizatorilor din UE. Nu publica parola sau cheia secretă.

Instalarea/conectarea integrării Supabase în aplicația de lucru permite configurarea asistată. Sugestia unei integrări nu înseamnă că este deja conectată.

## 2. Baza de date

Pe un proiect nou, execută migrarea `supabase/migrations/202610200001_online.sql` prin SQL Editor sau fluxul oficial de migrări Supabase. Migrarea este tranzacțională și se execută o singură dată. Pe un proiect existent verifică mai întâi obiectele și istoricul migrărilor; nu șterge tabele pentru a o reaplica.

Asociația inițială are ID `8e1f2fc1-2775-49cd-91b1-c06630eec432`. Migrarea introduce numai numele asociației. Nu introduce persoane, documente, voturi, ședințe sau proiecte fictive.

## 3. Autentificare

Activează Email / Password și confirmarea adresei. Setează Site URL la `https://ap-digital.pages.dev`. Adaugă exact URL-urile de întoarcere:

- `https://ap-digital.pages.dev/?mode=online`
- `https://ap-digital.pages.dev/?mode=online&recovery=1`

Pentru dezvoltare, adaugă echivalentele pentru originea locală aleasă. Nu utiliza redirecționări generice către domenii necunoscute. Configurează parola minimă de 12 caractere și opțiunile de securitate disponibile.

Confirmarea adresei și recuperarea parolei folosesc serviciul de e-mail Supabase. Serviciul implicit are restricții pentru testare; configurează SMTP înainte de invitarea membrilor. Nu au fost trimise mesaje prin această implementare. Referințe: [parole și recuperare](https://supabase.com/docs/guides/auth/passwords), [SMTP](https://supabase.com/docs/guides/auth/auth-smtp).

## 4. Configurația aplicației

Copiază `.env.example` în `.env.local` pentru dezvoltare. În Cloudflare Pages configurează variabilele de build:

- `VITE_SUPABASE_URL`: URL-ul proiectului.
- `VITE_SUPABASE_PUBLISHABLE_KEY`: cheia publică publishable. Alternativ, cheia anon publică în `VITE_SUPABASE_ANON_KEY`.
- `VITE_ASSOCIATION_ID`: ID-ul asociației de mai sus.
- `VITE_ONLINE_DEFAULT=false`: păstrează demonstrația ca intrare implicită. Setează `true` după verificarea activării, pentru intrare directă în autentificare.

Nu folosi `service_role`, `sb_secret_...`, parola bazei de date sau tokenuri administrative în variabile Vite. Clientul respinge cheile secrete cunoscute. Modificarea variabilelor necesită un build nou. Nu este suficientă reîncărcarea browserului.

## 5. Primul administrator

Contul de administrare Supabase este separat de contul de membru din aplicație. Persoana desemnată înregistrează un cont în spațiul online cu propria adresă, confirmă adresa și trimite cererea cu referința documentului semnat. Contul nu primește automat calitatea de membru. Primul administrator trebuie desemnat în baza de date de titularul proiectului, după verificarea cererii și aprobării Consiliului Director.

În SQL Editor, înlocuiește referințele din exemplu cu documentele reale înainte de executare; exemplul nu trebuie rulat cu textele de înlocuit:

```sql
update public.ap_memberships
set status = 'active', role = 'administrator', approved_at = now(),
    resolution_reference = 'INLOCUIESTE-CU-DECIZIA-CD'
where association_id = '8e1f2fc1-2775-49cd-91b1-c06630eec432'
  and user_id = (
    select id from auth.users
    where email = 'INLOCUIESTE-CU-EMAILUL-PERSOANEI-DESEMNATE' and email_confirmed_at is not null
  )
  and status = 'pending'
  and length(trim(application_reference)) > 0
returning user_id, display_name, status, role;
```

Verifică întoarcerea exact a rândului intenționat. Operația de desemnare a primului administrator nu a fost executată. Administratorii următori înregistrează aprobările din Profil, cu referința deciziei. Rolul de administrator este un drept operațional în aplicație, nu dovada unui mandat de președinte sau membru al Consiliului Director.

## 6. Drepturi și date comune

- Cont fără cerere: acces numai la autentificare și formularul de înscriere.
- Cerere în așteptare sau respinsă: acces numai la propria stare; fără datele comunității.
- Membru activ: vizualizare, propuneri de proiecte, editarea propriilor proiecte, sarcini în acestea, comentarii proprii, susținere, voluntariat, confirmări și răspunsuri la consultările eligibile.
- Coordonator: și editarea proiectelor, administrarea consultărilor și moderarea opțiunilor, programarea întâlnirilor și publicarea documentelor text.
- Administrator: și verificarea cererilor de înscriere / drepturilor de acces, cu referința aprobării Consiliului Director.

Politicile RLS și funcțiile bazei de date verifică drepturile; câmpurile de rol din browser sau metadata contului nu sunt considerate autoritate. Identitățile, totalurile de voturi și numărul susținătorilor nu se acceptă de la client. Actualizarea unui proiect/unei consultări folosește versiunea citită pentru a detecta modificările concurente. Datele sunt reîncărcate după salvare și periodic la 15 secunde.

Consultări: un răspuns per membru, schimbare și retragere până la termen, selecție unică/multiplă, agregare pe server fără publicarea voturilor individuale. Regula „la deschidere” folosește data aprobării ca membru; regula „până la închidere” admite membrii aprobați în timpul consultării. O bifare multiplă rămâne un singur răspuns. La închidere se blochează modificările. Opțiunile noi se introduc prin moderare, păstrând pozițiile opțiunilor existente. Schimbarea eligibilității sau a întrebării după deschidere este refuzată.

## 7. Limitele primei integrări

Spațiul comun are o interfață separată de demo. Acoperă proiecte, sarcini, comentarii, voluntariat, susținere, consultări, ședințe cu confirmare, documente text și statistici. Calendarul lunar și exportul `.ics` rămân disponibile în demonstrație; integrarea lor în spațiul comun este o extensie ulterioară. Documentele online se introduc ca text; încărcarea fișierelor PDF nu este încă implementată.

Ciornele online sunt salvate explicit pe server; nu există salvare automată offline și nici coadă de sincronizare. Interfața statică PWA este disponibilă offline după prima vizită, dar încărcarea datelor comune și salvarea cer internet. Datele încărcate rămân doar în memoria sesiunii până la reîncărcare sau deconectare.

Nu sunt încă implementate: hotărâri statutare, mandate de reprezentanți ai claselor, cvorumuri AG/CD/CRP, semnături, gestiunea cotizațiilor, excluderea sau încetarea calității de membru. Nu se deduc aceste funcții din rolurile operaționale. Consultările online nu devin automat voturi oficiale. Înscrierea cu o referință nu semnează electronic cererea.

## 8. Verificare înainte de invitarea membrilor

```sh
npm run build
PW_CHANNEL=chrome npm test
npm run test:database
npm run test:online
```

Testele PostgreSQL rulează migrarea și RLS în PGlite. Testele online de browser folosesc exclusiv un serviciu simulat la `ap-digital-test.supabase.co`; nu contactează un cont Supabase real și nu trimit mesaje. După conectare, verifică separat cu două conturi de test în proiectul real: confirmarea adresei, înscrierea, aprobarea, partajarea unui proiect, voturile, deconectarea și refuzul accesului neautorizat. Ștergerea datelor de test dintr-un cont online se face numai cu autorizare explicită.

## Verificare efectuată pe proiectul real

API-ul Auth răspunde, furnizorul e-mail este activ, înscrierea este permisă și confirmarea adresei este obligatorie. Domeniul site-ului este `https://ap-digital.pages.dev`, cu cele două URL-uri exacte de revenire enumerate mai sus. Parola minimă configurată este de 12 caractere. Pagina publicată afișează formularul de autentificare. Citirile anonime ale proiectelor și membrilor, respectiv apelul anonim al snapshot-ului, au fost refuzate cu 401 / permission denied. Verificarea SQL raportează 11 tabele din 11 cu RLS activ. Nu s-au creat conturi de test și nu s-au trimis e-mailuri; confirmarea adresei, recuperarea și fluxul cu două conturi reale necesită verificare după înregistrarea primelor conturi. SMTP pentru invitații la scară nu este configurat.


## Îmbunătățiri cont — 20 octombrie 2026

- Confirmarea parolei la înregistrare și la schimbarea parolei.
- Retrimiterea confirmării adresei; pauză de 60 de secunde în interfață între solicitări de e-mail. Limitele reale rămân cele aplicate de Supabase; pauza din browser nu este o protecție anti-abuz pe server.
- Recuperare cu răspuns neutru, fără confirmarea existenței contului.
- Mesaje pentru linkuri expirate și explicația deschiderii în același browser (PKCE).
- Explicație despre cont, cererea de membru, datele utilizate și contactul asociației. Informarea completă privind protecția datelor rămâne de definitivat de asociație.
- 14 verificări ale spațiului online cu API simulat, desktop și mobil, inclusiv confirmare parolă, retrimitere, recuperare, expirare și actualizarea parolei. Build verificat.

SMTP personalizat este încă oprit; contul Resend conectat nu are domenii. Pentru activare este necesar un domeniu autorizat și verificarea DNS, apoi configurarea SMTP. Nu folosi domeniul școlii fără autorizare. Nu dezactiva confirmarea adresei ca soluție la lipsa SMTP. Șabloanele Supabase sunt blocate pentru editare până la configurarea SMTP personalizat.

Primul administrator și testele cu e-mailuri reale necesită desemnarea persoanei și parcurgerea personală a confirmării/parolei. Nu au fost create conturi reale de test sau aprobări fictive.
