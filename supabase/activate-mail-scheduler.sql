-- Run only after the worker is deployed. The key never leaves server-side storage.
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;
select cron.schedule('ap-membership-mail','* * * * *',$job$
 select net.http_post(
  url:='https://prgtvtuwsmhpsmbkkgmp.supabase.co/functions/v1/ap-membership-mail',
  headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InByZ3R2dHV3c21ocHNtYmtrZ21wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0OTc3OTQsImV4cCI6MjEwODA3Mzc5NH0.sHGQ1Ifdpeky7LtgxdHKY7_hZDiM7zje-GPHsWSDJyk','x-ap-dispatch',(select token from ap_private.mail_dispatch where singleton)),
  body:='{}'::jsonb,timeout_milliseconds:=10000
 );
$job$);
