# Sponsorizări și parteneriate

Rubrică disponibilă membrilor aprobați în spațiul comun online. Membrii pot propune organizații și contacte și își văd doar propriile propuneri și stadiul acestora. Administratorii și coordonatorii activi gestionează toate oportunitățile: responsabil, următorul pas, data revenirii, notițe interne și sume în RON. Nu se trimit mesaje automat companiilor.

Stadii: Propunere → De contactat → În discuții → Confirmat / Închis. Stadiul este o evidență internă, nu semnează un acord. Se poate alege un proiect din asociație sau sprijin general. Nu există ștergere definitivă din interfață; oportunitățile finalizate se închid.

Contactele altor membri, notițele și documentele parteneriatelor nu sunt expuse membrilor obișnuiți. Documentele sunt în bucketul privat `ap-sponsorships`, separat de documentele comunității; orice format, maximum 25 MB, descărcare fără afișare executabilă în pagină. Fără scanare antivirus automată.

Indicatorii agregați din rubrică și Comunitatea în cifre includ oportunități active, parteneriate în stadiul Confirmat, sume confirmate și sume primite. Sumele sunt istorice pentru toate oportunitățile, inclusiv cele închise; numărul parteneriatelor confirmate reflectă stadiul curent. Suma primită nu poate depăși suma confirmată. Produsele, serviciile și voluntariatul nu sunt convertite automat în bani. Nu există integrare contabilă.

Instalare: migrarea `202610210001_sponsorships.sql` după migrările anterioare. Tabelele nu acceptă scrieri directe de la clienți; operațiile verificate folosesc RPC. Gestionarea verifică rolul, asociația, responsabilul activ și versiunea pentru a evita suprascrierea modificărilor concurente. Conturile inactive nu au acces. Nu se stochează contacte în localStorage. În demonstrația locală rubrica nu apare.

Verificări: `node tests/sponsorships.mjs`, `npm run test:online -- --grep 'sponsorizări:'`, `npm run build`. Date fictive, servicii simulate în browser și reguli PostgreSQL testate local; fără mesaje trimise persoanelor de contact.
