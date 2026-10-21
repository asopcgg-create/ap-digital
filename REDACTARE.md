# Redactare colaborativă

Rubrică în spațiul comun online, accesibilă administratorilor și coordonatorilor activi. Se creează o ciornă goală sau un model de proces-verbal AGA, opțional legat de o întâlnire. Modelul este orientativ: cvorumul, drepturile de vot, hotărârile și validarea se consemnează potrivit documentelor asociației; aplicația nu semnează și nu validează automat procesul-verbal.

Mai multe sesiuni pot redacta același text. Yjs și CodeMirror combină modificările; salvarea folosește versiuni comparate pe server și reunește din nou starea la conflicte. Supabase Realtime notifică modificările protejate prin RLS. O verificare la 3 secunde asigură recuperarea după întreruperea conexiunii live. Salvarea pornește după aproximativ 700 ms de pauză la scriere.

Salvarea automată păstrează starea curentă. Butonul „Păstrează versiunea în istoric” reține un reper descărcabil, iar publicarea păstrează și ea un reper. „Publică o copie în Documente” creează un document separat, vizibil membrilor aprobați; modificările ulterioare ale ciornei nu schimbă acea copie. Repetarea publicării aceleiași versiuni este blocată pe server.

Textul nesalvat rămâne doar în memoria sesiunii: nu există jurnal de text în localStorage. La erori, editorul indică modificările nesalvate, reîncearcă și permite descărcarea unei copii TXT. Părăsirea editorului cu modificări nesalvate cere confirmare. Închiderea browserului fără salvare poate pierde aceste modificări. Limite: 100.000 de caractere și 1 MB stare colaborativă; o copie publicată are limita de 50.000 de caractere a documentelor text.

Ciornele și versiunile nu sunt expuse membrilor obișnuiți. Editorul se încarcă separat la deschiderea rubricii. În demonstrația locală editorul folosește stocare în browser și sincronizare periodică între file; colaborarea între dispozitive necesită cont online și baza comună. Nu sunt afișate cursoare sau prezența nominală a celorlalți redactori.

Instalare: `202610210003_document_management.sql`, apoi `202610210004_collaborative_drafts.sql`. A doua migrare adaugă `ap_drafts` la publicația existentă `supabase_realtime`. Configurația a fost verificată în proiect. Tabelele nu acceptă scrieri directe din client; RPC verifică rolul și asociația.

Verificări: `node tests/document-management.mjs`, `node --experimental-strip-types tests/collab-session.mjs`, `npm run test:online -- --grep 'documente:|redactare:'`, `npm run build`. Testele folosesc date fictive și servicii simulate. Testul de browser deschide două sesiuni, verifică reunirea contribuțiilor, o eroare de salvare, descărcarea copiei, istoricul și publicarea.

Referințe de implementare: https://github.com/yjs/y-codemirror.next și https://supabase.com/docs/guides/realtime/postgres-changes.
