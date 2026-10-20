# Fișiere în Documente

În spațiul online, administratorii și coordonatorii pot publica fișiere de orice format, până la 25 MB fiecare. Membrii activi pot descărca documentele. Rămâne disponibilă și publicarea documentelor text.

Fișierele se păstrează în bucketul privat `ap-documents`; nu se folosesc URL-uri publice. Aplicația descarcă fișierul cu numele original și nu afișează conținut HTML/SVG executabil în pagină. Dimensiunea este limitată și pe server. Datele despre dimensiune și tip sunt preluate din metadatele stocării. Un fișier publicat nu poate fi suprascris ori eliminat prin operația de curățare a încărcărilor eșuate. Nu există scanare antivirus automată.

Instalare: aplicați migrarea `202610200004_document_files.sql` după migrările existente, apoi publicați interfața. Migrarea creează bucketul privat și regulile pentru acces. Nu modificați bucketul în public.

Verificări: `node tests/document-files.mjs`; `npm run test:online -- --grep 'documente:'`; `npm run build`. Testele folosesc date fictive și servicii simulate pentru browser, respectiv PostgreSQL local pentru regulile de acces.
