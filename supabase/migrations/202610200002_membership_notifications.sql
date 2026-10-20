begin;
-- Private dispatch key is created and used only by the database and the worker.
create schema if not exists ap_private;
revoke all on schema ap_private from public,anon,authenticated;
create table ap_private.mail_dispatch(singleton boolean primary key default true check(singleton),token text not null default (gen_random_uuid()::text||gen_random_uuid()::text),last_claim timestamptz);
insert into ap_private.mail_dispatch(singleton) values(true);
revoke all on ap_private.mail_dispatch from public,anon,authenticated;
create table ap_private.mail_attempts(attempted_at timestamptz not null default now());
revoke all on ap_private.mail_attempts from public,anon,authenticated;
create table public.ap_mail_jobs(
 id uuid primary key default gen_random_uuid(),
 association_id uuid not null references public.ap_associations(id),
 subject_user_id uuid not null references auth.users(id),
 recipient_id uuid not null references auth.users(id),
 kind text not null check(kind in ('request','active','rejected')),
 display_name text not null,
 assigned_role text not null,
 state text not null default 'pending' check(state in ('pending','processing','sent','failed','cancelled')),
 attempts integer not null default 0,
 created_at timestamptz not null default now(),
 next_attempt_at timestamptz not null default now(),
 claimed_at timestamptz,
 claim_id uuid,
 sent_at timestamptz,
 last_error text,
 unique(association_id,subject_user_id,recipient_id,kind)
);
alter table public.ap_mail_jobs enable row level security;
revoke all on public.ap_mail_jobs from public,anon,authenticated;
create function public.ap_queue_membership_mail() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='INSERT' then
  if new.status='pending' then
   insert into public.ap_mail_jobs(association_id,subject_user_id,recipient_id,kind,display_name,assigned_role)
   select new.association_id,new.user_id,m.user_id,'request',new.display_name,new.role
   from public.ap_memberships m join auth.users u on u.id=m.user_id
   where m.association_id=new.association_id and m.status='active' and m.role='administrator' and u.email_confirmed_at is not null
   on conflict do nothing;
  end if;
 elsif old.status='pending' and new.status in ('active','rejected') then
  insert into public.ap_mail_jobs(association_id,subject_user_id,recipient_id,kind,display_name,assigned_role)
  values(new.association_id,new.user_id,new.user_id,new.status,new.display_name,new.role) on conflict do nothing;
 end if;
 return new;
end $$;
revoke all on function public.ap_queue_membership_mail() from public,anon,authenticated;
create trigger ap_membership_mail after insert or update of status on public.ap_memberships for each row execute function public.ap_queue_membership_mail();
-- Dispatch is authenticated by a private key, not by browser-provided recipients.
create function public.ap_claim_mail_jobs(dispatch_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare job public.ap_mail_jobs; recipient_email text; result jsonb:='[]'::jsonb; d ap_private.mail_dispatch; budget integer;
begin
 select * into d from ap_private.mail_dispatch where singleton for update;
 if dispatch_token is null or dispatch_token<>d.token then raise exception 'Dispatch neautorizat' using errcode='42501'; end if;
 if d.last_claim>now()-interval '50 seconds' then return result; end if;
 update ap_private.mail_dispatch set last_claim=now() where singleton;
 -- Cap SMTP attempts at 20/hour, including retries; serialize concurrent workers.
 delete from ap_private.mail_attempts where attempted_at<now()-interval '1 day';
 select greatest(0,20-count(*))::integer into budget from ap_private.mail_attempts where attempted_at>now()-interval '1 hour';
 update public.ap_mail_jobs set state='failed',last_error='Numărul maxim de încercări a fost atins.' where state='processing' and claimed_at<now()-interval '10 minutes' and attempts>=5;
 for job in select * from public.ap_mail_jobs where attempts<5 and ((state='pending' and next_attempt_at<=now()) or (state='processing' and claimed_at<now()-interval '10 minutes')) order by created_at limit least(5,budget) for update skip locked loop
  -- Re-check recipient access at send time. Stale request alerts are unnecessary.
  if job.kind='request' and (not exists(select 1 from public.ap_memberships where association_id=job.association_id and user_id=job.recipient_id and status='active' and role='administrator') or not exists(select 1 from public.ap_memberships where association_id=job.association_id and user_id=job.subject_user_id and status='pending')) then
   update public.ap_mail_jobs set state='cancelled' where id=job.id; continue;
  end if;
  if job.kind<>'request' and not exists(select 1 from public.ap_memberships where association_id=job.association_id and user_id=job.subject_user_id and status=job.kind) then update public.ap_mail_jobs set state='cancelled' where id=job.id;continue;end if;
  select email into recipient_email from auth.users where id=job.recipient_id and email_confirmed_at is not null;
  if recipient_email is null then update public.ap_mail_jobs set state='cancelled' where id=job.id;continue;end if;
  update public.ap_mail_jobs set state='processing',attempts=attempts+1,claimed_at=now(),claim_id=gen_random_uuid() where id=job.id returning * into job;
  insert into ap_private.mail_attempts default values;
  result:=result||jsonb_build_array(jsonb_build_object('id',job.id,'claim_id',job.claim_id,'email',recipient_email,'kind',job.kind,'display_name',job.display_name,'assigned_role',job.assigned_role));
 end loop;
 return result;
end $$;
create function public.ap_finish_mail_job(dispatch_token text,job_id uuid,lease_id uuid,delivered boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if dispatch_token is null or not exists(select 1 from ap_private.mail_dispatch where singleton and token=dispatch_token) then raise exception 'Dispatch neautorizat' using errcode='42501';end if;
 update public.ap_mail_jobs set state=case when delivered then 'sent' when attempts>=5 then 'failed' else 'pending' end,sent_at=case when delivered then now() else null end,next_attempt_at=now()+interval '5 minutes'*attempts,last_error=case when delivered then null else 'Expedierea SMTP nu a fost confirmată. Reîncercare automată.' end where id=job_id and claim_id=lease_id and state='processing';
end $$;
revoke all on function public.ap_claim_mail_jobs(text),public.ap_finish_mail_job(text,uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.ap_claim_mail_jobs(text),public.ap_finish_mail_job(text,uuid,uuid,boolean) to service_role;
create function public.ap_mail_status(a uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not public.ap_admin(a) then raise exception 'Acces neautorizat' using errcode='42501';end if;
 return (select jsonb_build_object('pending',count(*) filter(where state in ('pending','processing')),'sent',count(*) filter(where state='sent'),'failed',count(*) filter(where state='failed'),'last_sent_at',max(sent_at)) from public.ap_mail_jobs where association_id=a);
end $$;
revoke all on function public.ap_mail_status(uuid) from public,anon;
grant execute on function public.ap_mail_status(uuid) to authenticated;
commit;
