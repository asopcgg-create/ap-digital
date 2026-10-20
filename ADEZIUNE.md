# Adeziune și reconfirmare anuală

Cererea se completează după confirmarea contului. Platforma atribuie numărul și preia adresa verificată a contului. PDF-ul se descarcă, se semnează de mână și se trimite manual la asopcgg@gmail.com. Linkul de e-mail nu atașează automat documentul. Declarația solicitantului deschide o cerere în așteptare; administratorul verifică documentul primit și înregistrează aprobarea și rolul separat.

Nu se cer CNP, serie CI sau informații medicale. Datele copiilor sunt vizibile doar solicitantului și administratorilor. Informarea inclusă este o versiune de test: identitatea completă a operatorului, temeiurile și termenele de păstrare trebuie validate înainte de înscrieri generale.

În Profil, membrii activi pot reconfirma anual copiii și clasele. Anul școlar se calculează pe server, septembrie–august. Un copil în clasa XII nu închide automat accesul părintelui, care poate avea și alți copii. Declarația că nu mai are copii în școală se verifică de administrator; absența răspunsului nu dezactivează contul. Închiderea accesului comun păstrează cererea și istoricul privat.

Migrarea 202610200003_adhesion_reconfirmation.sql se aplică după primele două migrări. activate-reconfirmation-scheduler.sql instalează verificarea zilnică pentru notificarea anuală, o singură dată pe an școlar, pentru membrii aprobați înaintea acelui an școlar și încă nereconfirmați. Funcția ap-membership-mail trebuie publicată în versiunea corespunzătoare. Nu sunt incluse date secrete în repository.

Validare: build de producție, 9 teste ale regulilor bazei de date, 9 teste simulate ale notificărilor și 24 de verificări de browser pe desktop și telefon. Testele de browser folosesc date fictive și servicii simulate; nu trimit e-mailuri reale și nu modifică membri reali.
