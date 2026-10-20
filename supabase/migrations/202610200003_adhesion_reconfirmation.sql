begin;
alter table public.ap_memberships drop constraint ap_memberships_status_check;
alter table public.ap_memberships add constraint ap_memberships_status_check check(status in ('pending','active','rejected','inactive'));
create sequence public.ap_application_number;
revoke all on sequence public.ap_application_number from public,anon,authenticated;
create table public.ap_applications(
 id uuid primary key default gen_random_uuid(),association_id uuid not null references public.ap_associations,
 user_id uuid not null references auth.users,
 reference text not null unique default ('AP-'||extract(year from now())::text||'-'||lpad(nextval('public.ap_application_number')::text,6,'0')),
 full_name text not null,email text not null,phone text not null default '',children jsonb not null,
 status text not null default 'draft' check(status in ('draft','submitted')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),submitted_at timestamptz,
 signed_sent_at timestamptz,privacy_version text not null default '2026-10-20',privacy_ack_at timestamptz,
 unique(association_id,user_id)
);
alter table public.ap_applications enable row level security;
revoke all on public.ap_applications from public,anon,authenticated;
grant select on public.ap_applications to authenticated;
create policy applications_read on public.ap_applications for select to authenticated using(user_id=auth.uid() or public.ap_admin(association_id));
create function public.ap_check_children(c jsonb,allow_empty boolean default false) returns boolean language sql immutable set search_path='' as $$
 select case when jsonb_typeof(c)<>'array' or c is null then false when jsonb_array_length(c)>10 or (not allow_empty and jsonb_array_length(c)=0) then false else not exists(
 select 1 from jsonb_array_elements(c) x where jsonb_typeof(x)<>'object' or jsonb_typeof(x->'full_name') is distinct from 'string' or length(trim(x->>'full_name')) not between 1 and 100 or jsonb_typeof(x->'grade') is distinct from 'string' or x->>'grade' not in ('Grupa mică','Grupa mijlocie','Grupa mare','Pregătitoare','I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII') or jsonb_typeof(x->'class_label') is distinct from 'string' or length(x->>'class_label')>20 or exists(select 1 from jsonb_object_keys(x) k where k not in ('full_name','grade','class_label'))
 ) end
$$;
revoke all on function public.ap_check_children(jsonb,boolean) from public,anon,authenticated;
create function public.ap_save_application(a uuid,n text,p text,c jsonb,ack boolean) returns public.ap_applications language plpgsql security definer set search_path='' as $$
declare result public.ap_applications;
begin
 if auth.uid() is null or not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) or not exists(select 1 from public.ap_associations where id=a) then raise exception 'Confirmă e-mailul înainte de completare';end if;
 if ack is distinct from true or length(trim(n)) not between 1 and 100 or n is null or p is null or length(p)>30 or not public.ap_check_children(c) then raise exception 'Completează numele, copiii și confirmarea informării';end if;
 insert into public.ap_applications(association_id,user_id,full_name,email,phone,children,privacy_ack_at) values(a,auth.uid(),trim(n),(select email from auth.users where id=auth.uid()),trim(p),c,now())
 on conflict(association_id,user_id) do update set full_name=excluded.full_name,email=excluded.email,phone=excluded.phone,children=excluded.children,updated_at=now(),privacy_ack_at=now() where ap_applications.status='draft'
 returning * into result;
 if result.id is null then raise exception 'Cererea trimisă nu mai poate fi modificată. Contactează asociația.';end if;
 return result;
end $$;
create function public.ap_submit_application(a uuid,signed_sent boolean) returns void language plpgsql security definer set search_path='' as $$
declare app public.ap_applications;
begin
 if auth.uid() is null or signed_sent is distinct from true then raise exception 'Confirmă trimiterea cererii semnate';end if;
 select * into app from public.ap_applications where association_id=a and user_id=auth.uid() for update;
 if app.id is null or app.status<>'draft' or app.privacy_ack_at is null then raise exception 'Cererea nu este pregătită';end if;
 if exists(select 1 from public.ap_memberships where association_id=a and user_id=auth.uid()) then raise exception 'Există deja o cerere de înscriere pentru acest cont';end if;
 update public.ap_applications set status='submitted',submitted_at=now(),signed_sent_at=now() where id=app.id;
 insert into public.ap_memberships(association_id,user_id,display_name,application_reference) values(a,auth.uid(),app.full_name,app.reference);
end $$;
revoke all on function public.ap_save_application(uuid,text,text,jsonb,boolean),public.ap_submit_application(uuid,boolean) from public,anon;
grant execute on function public.ap_save_application(uuid,text,text,jsonb,boolean),public.ap_submit_application(uuid,boolean) to authenticated;
create function public.ap_school_year() returns integer language sql stable set search_path='' as $$
 select extract(year from timezone('Europe/Bucharest',now()))::integer-case when extract(month from timezone('Europe/Bucharest',now()))<9 then 1 else 0 end
$$;
revoke all on function public.ap_school_year() from public,anon;
grant execute on function public.ap_school_year() to authenticated;
create table public.ap_reconfirmations(
 id uuid primary key default gen_random_uuid(),association_id uuid not null references public.ap_associations,user_id uuid not null references auth.users,
 school_year integer not null,choice text not null check(choice in ('continuing','updated','leaving')),children jsonb not null,
 created_at timestamptz not null default clock_timestamp(),reviewed_at timestamptz,reviewed_by uuid references auth.users,review_reference text
);
alter table public.ap_reconfirmations enable row level security;
revoke all on public.ap_reconfirmations from public,anon,authenticated;
grant select on public.ap_reconfirmations to authenticated;
create policy reconfirmations_read on public.ap_reconfirmations for select to authenticated using(user_id=auth.uid() or public.ap_admin(association_id));
create function public.ap_reconfirm(a uuid,answer text,c jsonb) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.ap_active(a) or answer is null or answer not in ('continuing','updated','leaving') or not public.ap_check_children(c,answer='leaving') then raise exception 'Reconfirmare invalidă';end if;
 perform 1 from public.ap_memberships where association_id=a and user_id=auth.uid() for update;
 insert into public.ap_reconfirmations(association_id,user_id,school_year,choice,children) values(a,auth.uid(),public.ap_school_year(),answer,c);
end $$;
create function public.ap_review_departure(a uuid,r uuid,reference text) returns void language plpgsql security definer set search_path='' as $$
declare item public.ap_reconfirmations;
begin
 if not public.ap_admin(a) or reference is null or length(trim(reference)) not between 1 and 300 then raise exception 'Verificare neautorizată sau referință lipsă';end if;
 select * into item from public.ap_reconfirmations where id=r and association_id=a for update;
 if item.id is null or item.choice<>'leaving' or item.school_year<>public.ap_school_year() or item.reviewed_at is not null or item.user_id=auth.uid() then raise exception 'Închiderea accesului nu poate fi efectuată';end if;
 perform 1 from public.ap_memberships where association_id=a and user_id=item.user_id for update;
 if exists(select 1 from public.ap_reconfirmations where association_id=a and user_id=item.user_id and created_at>item.created_at) then raise exception 'Există o reconfirmare mai recentă';end if;
 update public.ap_memberships set status='inactive',resolution_reference=trim(reference) where association_id=a and user_id=item.user_id and status='active';
 if not found then raise exception 'Accesul nu mai este activ';end if;
 update public.ap_reconfirmations set reviewed_at=now(),reviewed_by=auth.uid(),review_reference=trim(reference) where id=r;
end $$;
revoke all on function public.ap_reconfirm(uuid,text,jsonb),public.ap_review_departure(uuid,uuid,text) from public,anon;
grant execute on function public.ap_reconfirm(uuid,text,jsonb),public.ap_review_departure(uuid,uuid,text) to authenticated;
-- Reminders and closure notices contain no child data or signed documents.
alter table public.ap_mail_jobs drop constraint ap_mail_jobs_kind_check;
alter table public.ap_mail_jobs add constraint ap_mail_jobs_kind_check check(kind in ('request','active','rejected','inactive') or kind ~ '^reconfirm-[0-9]{4}$');
create function public.ap_queue_reconfirmation_reminders() returns void language plpgsql security definer set search_path='' as $$
begin
 insert into public.ap_mail_jobs(association_id,subject_user_id,recipient_id,kind,display_name,assigned_role)
 select m.association_id,m.user_id,m.user_id,'reconfirm-'||public.ap_school_year()::text,m.display_name,m.role from public.ap_memberships m join auth.users u on u.id=m.user_id
 where m.status='active' and u.email_confirmed_at is not null and m.approved_at<make_date(public.ap_school_year(),9,1)::timestamptz
 and not exists(select 1 from public.ap_reconfirmations r where r.association_id=m.association_id and r.user_id=m.user_id and r.school_year=public.ap_school_year()) on conflict do nothing;
end $$;
revoke all on function public.ap_queue_reconfirmation_reminders() from public,anon,authenticated;
-- Keep existing requests/approvals and add notices when access is actually closed.
create or replace function public.ap_queue_membership_mail() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='INSERT' then
  if new.status='pending' then
   insert into public.ap_mail_jobs(association_id,subject_user_id,recipient_id,kind,display_name,assigned_role)
   select new.association_id,new.user_id,m.user_id,'request',new.display_name,new.role from public.ap_memberships m join auth.users u on u.id=m.user_id where m.association_id=new.association_id and m.status='active' and m.role='administrator' and u.email_confirmed_at is not null on conflict do nothing;
  end if;
 elsif (old.status='pending' and new.status in ('active','rejected')) or (old.status='active' and new.status='inactive') then
  insert into public.ap_mail_jobs(association_id,subject_user_id,recipient_id,kind,display_name,assigned_role) values(new.association_id,new.user_id,new.user_id,new.status,new.display_name,new.role) on conflict do nothing;
 end if;
 return new;
end $$;
create or replace function public.ap_claim_mail_jobs(dispatch_token text) returns jsonb language plpgsql security definer set search_path='' as $$
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
  if job.kind like 'reconfirm-%' and (not exists(select 1 from public.ap_memberships where association_id=job.association_id and user_id=job.subject_user_id and status='active') or exists(select 1 from public.ap_reconfirmations where association_id=job.association_id and user_id=job.subject_user_id and school_year=substring(job.kind from 11)::integer)) then update public.ap_mail_jobs set state='cancelled' where id=job.id;continue;end if;
  if job.kind<>'request' and job.kind not like 'reconfirm-%' and not exists(select 1 from public.ap_memberships where association_id=job.association_id and user_id=job.subject_user_id and status=job.kind) then update public.ap_mail_jobs set state='cancelled' where id=job.id;continue;end if;
  select email into recipient_email from auth.users where id=job.recipient_id and email_confirmed_at is not null;
  if recipient_email is null then update public.ap_mail_jobs set state='cancelled' where id=job.id;continue;end if;
  update public.ap_mail_jobs set state='processing',attempts=attempts+1,claimed_at=now(),claim_id=gen_random_uuid() where id=job.id returning * into job;
  insert into ap_private.mail_attempts default values;
  result:=result||jsonb_build_array(jsonb_build_object('id',job.id,'claim_id',job.claim_id,'email',recipient_email,'kind',job.kind,'display_name',job.display_name,'assigned_role',job.assigned_role));
 end loop;
 return result;
end $$;

alter table public.ap_applications add column verified_at timestamptz, add column verified_by uuid references auth.users;
create function public.ap_verify_signed_application(a uuid,u uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.ap_admin(a) then raise exception 'Verificare neautorizată';end if;
 update public.ap_applications set verified_at=now(),verified_by=auth.uid() where association_id=a and user_id=u and status='submitted';
 if not found then raise exception 'Nu există cerere trimisă pentru verificare';end if;
end $$;
revoke all on function public.ap_verify_signed_application(uuid,uuid) from public,anon;
grant execute on function public.ap_verify_signed_application(uuid,uuid) to authenticated;
create or replace function public.ap_review_member(a uuid,u uuid,decision text,reference text,assigned_role text default 'membru') returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.ap_admin(a) or decision not in ('active','rejected') or assigned_role not in ('membru','coordonator','administrator') or length(trim(reference)) not between 1 and 300 then raise exception 'Aprobare neautorizată sau referință lipsă'; end if;
 if decision='active' and not exists(select 1 from public.ap_memberships where association_id=a and user_id=u and length(trim(application_reference))>0) then raise exception 'Este necesară referința cererii semnate'; end if;
 if decision='active' and exists(select 1 from public.ap_applications where association_id=a and user_id=u and (status<>'submitted' or verified_at is null)) then raise exception 'Verifică documentul semnat înainte de aprobare';end if;
 update public.ap_memberships set status=decision,role=case when decision='active' then assigned_role else 'membru' end,approved_at=case when decision='active' then now() else null end,resolution_reference=trim(reference) where association_id=a and user_id=u and status='pending';
 if not found then raise exception 'Cererea nu mai este în așteptare'; end if;
end $$;

commit;
