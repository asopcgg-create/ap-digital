# Administrare tehnică și jurnal

Se instalează migrările `202610230001_technical_audit.sql` și `202610230002_audit_identity.sql`, apoi versiunea nouă a aplicației. Nu conțin parole și nu creează acces implicit pentru o adresă de e-mail.

## Acces

Contul tehnic folosește autentificarea Supabase existentă. Accesul este păstrat separat în `ap_technical_access`: nu reprezintă calitate de membru și nu acordă `ap_active`, `ap_staff` sau `ap_admin`. Administratorul poate activa sau retrage accesul unui cont cu e-mail confirmat din Administrare tehnică. Revocarea este verificată la fiecare apel; interfața reverifică la 15 secunde. Un administrator care are și acces tehnic păstrează interfața administrativă.

Responsabilul tehnic vede diagnosticul, totalurile fișierelor, ultimele 50 de operații de e-mail și erori cu coduri generice. Nu vede destinatarii, conținutul mesajelor, parolele, secretele SMTP, cererile de adeziune sau documentele private. Administratorul vede identitatea autorului și titlul înregistrării în jurnal; vizualizarea tehnică arată rolul și identificatorul înregistrării. Identitatea conturilor tehnice este afișată administratorului prin e-mail.

## Jurnal

Declanșatoare în baza de date înregistrează crearea, modificarea și ștergerea proiectelor, comentariilor, implicării, consultărilor, propunerilor, ședințelor, confirmărilor, documentelor, ciornelor/versiunilor păstrate, cererilor, reconfirmărilor, membrilor și sponsorizărilor/atașamentelor. Sunt urmărite și schimbările de acces tehnic, mentenanța, erorile și reîncercările e-mailurilor. Acțiunile anterioare instalării nu sunt reconstruite.

Jurnalul păstrează autorul, rolul la momentul operației, ora serverului, entitatea, acțiunea, titlul (numai pentru administratori), câmpurile schimbate și valorile unor indicatori de flux limitați explicit: status, etapă, progres, anulare, mentenanță, acces și rol. Nu copiază conținutul documentelor, ciornele, formularele complete, mesajele brute de eroare sau răspunsurile la vot. Nu urmărește tabelul buletinelor de vot. Nu este un istoric integral al conținutului; documentele au propriul istoric.

Clienții, inclusiv administratorii, nu au drepturi directe de inserare/modificare/ștergere a jurnalului. Proprietarul bazei de date rămâne capabil să administreze baza. Filtrele au paginare de 100 de evenimente și cursor compus (dată + ID).

## Operații

- Mentenanța este reversibilă, anunțată prin mesaj și blochează server-side scrierile comunității și operațiile Storage. Citirea rămâne disponibilă. Controalele tehnice funcționează în continuare. Nu a fost activată în producție în timpul instalării. Procesele interne fără sesiune de utilizator, inclusiv coada e-mailurilor, continuă.
- E-mailurile acceptate SMTP nu sunt garantate ca livrate în Inbox. Reîncercarea manuală este permisă numai pentru un mesaj eșuat, creat în ultimele șapte zile, o singură dată; folosește aceeași înregistrare/destinatar. Rămân limitele și Message-ID-ul stabil ale lucrătorului existent. SMTP nu garantează eliminarea duplicatelor după un răspuns ambiguu.
- Încărcările fără document asociat pot fi în curs; panoul nu le șterge automat. Totalurile includ coșul și versiunile. Nu reprezintă limita planului.
- Raportarea erorilor trimite numai module/coduri permise, maximum 20 de înregistrări per utilizator/oră. Include erorile de încărcare/salvare ale aplicației și erori de execuție; nu înlocuiește toate jurnalele furnizorului.
- Versiunea afișează ora compilării. Verificarea actualizării cere browserului să actualizeze service worker-ul; salvarea lucrului precede reîncărcarea.

Teste: `node tests/technical-audit.mjs`, `npm run test:online -- --grep 'tehnic:|administrator: jurnal'`, `npm run build`.
