# Fișiere în Documente

În spațiul online, administratorii și coordonatorii pot publica fișiere de orice format, până la 25 MB fiecare. Membrii activi pot descărca documentele. Rămâne disponibilă și publicarea documentelor text.

Fișierele se păstrează în bucketul privat `ap-documents`; nu se folosesc URL-uri publice. Aplicația descarcă fișierul cu numele original și nu afișează conținut HTML/SVG executabil în pagină. Dimensiunea este limitată și pe server. Datele despre dimensiune și tip sunt preluate din metadatele stocării. Un fișier publicat nu poate fi suprascris ori eliminat prin operația de curățare a încărcărilor eșuate. Nu există scanare antivirus automată.

Instalare: aplicați migrarea `202610200004_document_files.sql` după migrările existente, apoi publicați interfața. Migrarea creează bucketul privat și regulile pentru acces. Nu modificați bucketul în public.

Verificări: `node tests/document-files.mjs`; `npm run test:online -- --grep 'documente:'`; `npm run build`. Testele folosesc date fictive și servicii simulate pentru browser, respectiv PostgreSQL local pentru regulile de acces.

## Actualizare, versiuni și coș

Administratorii și coordonatorii pot edita titlul, categoria și textul/descrierea și pot înlocui un fișier. Fiecare modificare păstrează versiunea anterioară. Istoricul și fișierele versiunilor vechi sunt vizibile numai echipei de coordonare/administrare. Membrii descarcă doar versiunea curentă a documentelor publicate.

„Mută în coș” ascunde documentul și fișierul de membri și permite restaurarea. „Restabilește versiunea” creează o nouă revizie, fără pierderea istoricului. Modificările concurente se resping dacă versiunea deschisă a devenit veche.

Numai administratorii pot șterge definitiv un document deja aflat în coș, după confirmare în interfață. Procesul elimină fișierele curente și istorice prin API-ul Storage, apoi elimină documentul și versiunile din bază. Dacă eliminarea se întrerupe, documentul rămâne în coș cu opțiune de reîncercare și nu poate fi restaurat parțial. Operația se finalizează doar după ce fișierele nu mai există în Storage. Testele nu execută ștergeri reale în proiectul publicat.
