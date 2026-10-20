# Calendar: editare, anulare și confirmări

În Ședințe, administratorii și coordonatorii pot programa, edita și anula întâlniri. Membrii aprobați văd totalul confirmărilor și pot confirma sau retrage participarea la întâlniri programate. Lista cu numele participanților este disponibilă numai administratorilor și coordonatorilor din aceeași asociație; nu include e-mailuri sau date despre copii.

Anularea necesită un motiv. Întâlnirea și confirmările rămân în istoric, fără ștergere definitivă. Nu se acceptă confirmări sau retrageri noi după anulare. Editarea păstrează confirmările, inclusiv la schimbarea datei. Persoana care modifică sau anulează trebuie să anunțe separat participanții; nu sunt trimise e-mailuri automate.

Totalul numără confirmările păstrate, inclusiv ale conturilor devenite ulterior inactive. Lista de coordonare indică statusul acestor conturi. Numărul reprezintă confirmări, nu prezența efectivă la întâlnire. Exporturile ICS păstrează identificatorul evenimentului, includ versiunea și STATUS:CANCELLED pentru anulări. Un calendar extern trebuie să importe exportul actualizat; nu există sincronizare automată.

Orele formularului sunt în Europe/Bucharest, indiferent de fusul dispozitivului. O oră inexistentă la trecerea la ora de vară este respinsă. În ora repetată din toamnă se folosește apariția validă rezultată din conversie.

Demonstrația oferă același flux cu participanți fictivi și persistență locală. În Profil se poate simula rolul Coordonator/Administrator. Resetarea demonstrației readuce exemplele inițiale. Datele demo nu sunt trimise în baza comună.

Instalare: `202610210002_meeting_management.sql`, după migrările anterioare. Verificări: `node tests/meeting-management.mjs`, `node --experimental-strip-types tests/meeting-time.mjs`, `npm run test:online -- --grep calendar`, `PW_CHANNEL=chrome npm test -- --grep 'demo: confirmare'`, `npm run build`. Testele folosesc persoane fictive și servicii simulate; nu anulează întâlniri reale.
