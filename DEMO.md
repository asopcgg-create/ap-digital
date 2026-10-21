# Demonstrație fără autentificare

Deschide `/?mode=demo`. În Profil poți simula Membru, Coordonator sau Administrator.

Sponsorizările folosesc aceleași formulare, stadii, responsabil, valori și atașamente ca spațiul online. Documentele permit încărcare în orice format (25 MB), editare, înlocuire, istoric, coș, restaurare și ștergere definitivă pentru administratorul demo. Redactarea include modelul AGA, salvare automată, istoric manual, descărcare și publicarea unei copii în Documente. Indicatorii includ sponsorizările demo.

Metadatele sunt salvate în cheia separată `ap-digital:demo-features:v1`; fișierele în IndexedDB `ap-digital-demo-files`. Nu sunt apelate API-urile asociației. Nu se trimit mesaje. Folosește numai informații fictive. Limitele de stocare ale browserului se aplică; erorile de salvare sunt afișate. Ștergerea datelor browserului elimină demonstrația locală.

Ciornele se sincronizează periodic între file ale aceluiași browser/origine; colaborarea între dispozitive necesită spațiul online. Rolurile demo sunt simulări ale interfeței, nu mecanisme de securitate. În Profil, resetarea elimină și documentele, ciornele, sponsorizările și fișierele demo.

Autentificarea, aprobarea conturilor și mesajele tranzacționale rămân specifice spațiului online.
