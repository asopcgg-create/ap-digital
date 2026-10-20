select cron.schedule('ap-annual-reconfirmation','0 7 * * *','select public.ap_queue_reconfirmation_reminders()');
