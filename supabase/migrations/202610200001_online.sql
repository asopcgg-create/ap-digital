-- APCGG: no personal data, demo votes or demo projects are imported.
begin;
create table public.ap_associations(id uuid primary key, name text not null);
insert into public.ap_associations values ('8e1f2fc1-2775-49cd-91b1-c06630eec432','APCGG Digital');
create table public.ap_memberships(
 association_id uuid references public.ap_associations not null,
 user_id uuid references auth.users on delete cascade not null,
 display_name text not null check(length(trim(display_name)) between 1 and 100),
 status text not null default 'pending' check(status in ('pending','active','rejected')),
 role text not null default 'membru' check(role in ('membru','coordonator','administrator')),
 requested_at timestamptz not null default now(), approved_at timestamptz,
 application_reference text not null default '' check(length(application_reference)<=300),
 resolution_reference text not null default '' check(length(resolution_reference)<=300),
 primary key(association_id,user_id)
);
create function public.ap_active(a uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.ap_memberships where association_id=a and user_id=auth.uid() and status='active')
$$;
create function public.ap_staff(a uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.ap_memberships where association_id=a and user_id=auth.uid() and status='active' and role in ('coordonator','administrator'))
$$;
create function public.ap_admin(a uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.ap_memberships where association_id=a and user_id=auth.uid() and status='active' and role='administrator')
$$;
create table public.ap_projects(
 id uuid primary key default gen_random_uuid(), association_id uuid not null references public.ap_associations,
 owner_id uuid not null default auth.uid() references auth.users, payload jsonb not null,
 revision integer not null default 1, created_at timestamptz not null default now()
);
create function public.ap_project_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='UPDATE' then
  if new.id<>old.id or new.association_id<>old.association_id or new.owner_id<>old.owner_id or new.created_at<>old.created_at then raise exception 'Identitatea proiectului nu poate fi schimbată'; end if;
  if new.revision<>old.revision then raise exception 'Versiune invalidă'; end if;
  new.revision:=old.revision+1;
 end if;
 if jsonb_typeof(new.payload)<>'object' or length(trim(coalesce(new.payload->>'title',''))) not between 1 and 90 or length(coalesce(new.payload->>'description',''))>2000 then raise exception 'Fișă invalidă'; end if;
 -- Aggregates and discussions have separate server-controlled tables.
 if jsonb_typeof(new.payload->'title') is distinct from 'string' or jsonb_typeof(new.payload->'description') is distinct from 'string' or jsonb_typeof(new.payload->'category') is distinct from 'string' or jsonb_typeof(new.payload->'tasks') is distinct from 'array' then raise exception 'Structură de proiect invalidă'; end if;
 if jsonb_array_length(new.payload->'tasks')>1000 or exists(select 1 from jsonb_array_elements(new.payload->'tasks') t where jsonb_typeof(t)<>'object' or jsonb_typeof(t->'id') is distinct from 'string' or jsonb_typeof(t->'title') is distinct from 'string' or jsonb_typeof(t->'stage') is distinct from 'string' or jsonb_typeof(t->'owner') is distinct from 'string' or jsonb_typeof(t->'due') is distinct from 'string' or jsonb_typeof(t->'done') is distinct from 'boolean') then raise exception 'Sarcini invalide'; end if;
 new.payload:=new.payload-'comments'-'supporters'-'volunteers';
 return new;
end $$;
create trigger ap_projects_guard before insert or update on public.ap_projects for each row execute function public.ap_project_guard();
create table public.ap_interactions(
 project_id uuid not null references public.ap_projects on delete cascade,
 user_id uuid not null default auth.uid() references auth.users,
 kind text not null check(kind in ('support','volunteer')),
 primary key(project_id,user_id,kind)
);
create table public.ap_comments(
 id uuid primary key default gen_random_uuid(),project_id uuid not null references public.ap_projects on delete cascade,
 user_id uuid not null default auth.uid() references auth.users,body text not null check(length(trim(body)) between 1 and 1000),
 created_at timestamptz not null default now()
);
create table public.ap_consultations(
 id uuid primary key default gen_random_uuid(),association_id uuid not null references public.ap_associations,
 owner_id uuid not null default auth.uid() references auth.users,
 payload jsonb not null, opened_at timestamptz, closed_at timestamptz, revision integer not null default 1
);
create function public.ap_consultation_guard() returns trigger language plpgsql set search_path='' as $$
declare opt jsonb; n integer; distinct_n integer;
begin
 if tg_op='UPDATE' then
  if new.id<>old.id or new.association_id<>old.association_id or new.owner_id<>old.owner_id then raise exception 'Identitatea consultării nu poate fi schimbată'; end if;
  if new.revision<>old.revision then raise exception 'Versiune invalidă'; end if;
  new.revision:=old.revision+1;
  if old.payload->>'status'<>'draft' then
   if old.payload->>'status'='closed' and new.payload is distinct from old.payload then raise exception 'Consultare închisă'; end if;
   if new.payload->>'status' not in ('open','closed') then raise exception 'Redeschiderea nu este permisă'; end if;
   if (new.payload-'status'-'options') is distinct from (old.payload-'status'-'options') then raise exception 'Întrebarea și regulile sunt fixe după deschidere'; end if;
   if new.payload->'options' is distinct from old.payload->'options' and current_user<>'postgres' then raise exception 'Opțiunile se adaugă prin moderare'; end if;
   new.opened_at:=old.opened_at;
  end if;
 end if;
 if jsonb_typeof(new.payload)<>'object' or new.payload->>'status' not in ('draft','open','closed') or new.payload->>'status' is null then raise exception 'Consultare invalidă'; end if;
 opt:=new.payload->'options';
 if jsonb_typeof(opt) is distinct from 'array' then raise exception 'Opțiuni invalide'; end if;
 select count(*),count(distinct lower(trim(value#>>'{}'))) into n,distinct_n from jsonb_array_elements(opt);
 if n<2 or n>20 or n<>distinct_n or exists(select 1 from jsonb_array_elements(opt) v where jsonb_typeof(v)<>'string' or length(trim(v#>>'{}')) not between 1 and 120) then raise exception 'Sunt necesare 2–20 opțiuni diferite'; end if;
 if length(trim(coalesce(new.payload->>'title',''))) not between 1 and 120 or length(trim(coalesce(new.payload->>'description',''))) not between 1 and 2000 then raise exception 'Completează titlul și explicația'; end if;
 if new.payload->>'eligibilityRule' is null or new.payload->>'eligibilityRule' not in ('opening','closing') or jsonb_typeof(new.payload->'multiple') is distinct from 'boolean' then raise exception 'Reguli invalide'; end if;
 if new.payload->>'status'='open' and (tg_op='INSERT' or old.payload->>'status'='draft') then
  if nullif(new.payload->>'deadline','') is null or (new.payload->>'deadline')::timestamptz<=now() then raise exception 'Termen viitor obligatoriu'; end if;
  new.opened_at:=now();
 end if;
 if jsonb_typeof(new.payload->'title') is distinct from 'string' or jsonb_typeof(new.payload->'description') is distinct from 'string' then raise exception 'Text invalid'; end if;
 if nullif(new.payload->>'deadline','') is not null then perform (new.payload->>'deadline')::timestamptz; end if;
 if tg_op='INSERT' then new.closed_at:=case when new.payload->>'status'='closed' then now() else null end;
 else new.closed_at:=case when new.payload->>'status'='closed' and old.payload->>'status'<>'closed' then now() else old.closed_at end; end if;
 -- Never accept client-supplied counters or participant totals.
 new.payload:=new.payload-'counts'-'eligibleCount'-'responseCount';
 return new;
end $$;
create trigger ap_consultations_guard before insert or update on public.ap_consultations for each row execute function public.ap_consultation_guard();
create function public.ap_eligible(p uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.ap_consultations c join public.ap_memberships m on m.association_id=c.association_id
 where c.id=p and m.user_id=auth.uid() and m.status='active' and c.payload->>'status'='open'
 and (c.payload->>'deadline')::timestamptz>now()
 and (c.payload->>'eligibilityRule'='closing' or m.approved_at<=c.opened_at))
$$;
create table public.ap_ballots(
 consultation_id uuid not null references public.ap_consultations on delete cascade,
 user_id uuid not null default auth.uid() references auth.users,
 choices integer[] not null, primary key(consultation_id,user_id)
);
create function public.ap_ballot_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare p jsonb; n integer;
begin
 if tg_op='DELETE' then
  if not public.ap_eligible(old.consultation_id) then raise exception 'Votul nu mai poate fi retras'; end if; return old;
 end if;
 if new.user_id is distinct from auth.uid() or not public.ap_eligible(new.consultation_id) then raise exception 'Nu ai drept de răspuns la această consultare'; end if;
 if tg_op='UPDATE' and (new.consultation_id<>old.consultation_id or new.user_id<>old.user_id) then raise exception 'Identitate invalidă'; end if;
 select payload into p from public.ap_consultations where id=new.consultation_id for share;
 if not public.ap_eligible(new.consultation_id) then raise exception 'Consultarea nu mai primește răspunsuri'; end if;
 n:=cardinality(new.choices);
 if n<1 or n>jsonb_array_length(p->'options') or (not (p->>'multiple')::boolean and n<>1)
 or exists(select 1 from unnest(new.choices) x where x is null or x<0 or x>=jsonb_array_length(p->'options'))
 or n<>(select count(distinct x) from unnest(new.choices) x) then raise exception 'Răspuns invalid'; end if;
 return new;
end $$;
create trigger ap_ballots_guard before insert or update or delete on public.ap_ballots for each row execute function public.ap_ballot_guard();
create table public.ap_suggestions(
 id uuid primary key default gen_random_uuid(),consultation_id uuid not null references public.ap_consultations on delete cascade,
 user_id uuid not null default auth.uid() references auth.users, label text not null check(length(trim(label)) between 1 and 120),
 status text not null default 'pending' check(status in ('pending','approved','rejected'))
);
create table public.ap_meetings(
 id uuid primary key default gen_random_uuid(),association_id uuid not null references public.ap_associations,
 title text not null check(length(trim(title)) between 1 and 120),starts_at timestamptz not null,
 place text not null check(length(place)<=300),agenda text[] not null default '{}'
);
create table public.ap_attendance(meeting_id uuid not null references public.ap_meetings on delete cascade,user_id uuid not null default auth.uid() references auth.users,primary key(meeting_id,user_id));
create table public.ap_documents(
 id uuid primary key default gen_random_uuid(),association_id uuid not null references public.ap_associations,
 title text not null check(length(trim(title)) between 1 and 120),category text not null default 'Organizare',
 body text not null check(length(body) between 1 and 50000),created_at timestamptz not null default now()
);
-- Helpers do not trust user-editable JWT metadata or local demo roles.
create function public.ap_project_association(p uuid) returns uuid language sql stable security definer set search_path='' as $$select association_id from public.ap_projects where id=p$$;
create function public.ap_poll_association(p uuid) returns uuid language sql stable security definer set search_path='' as $$select association_id from public.ap_consultations where id=p$$;
create function public.ap_meeting_association(p uuid) returns uuid language sql stable security definer set search_path='' as $$select association_id from public.ap_meetings where id=p$$;
alter table public.ap_associations enable row level security;
create policy associations_read on public.ap_associations for select to authenticated using(true);
alter table public.ap_memberships enable row level security;
create policy memberships_read on public.ap_memberships for select to authenticated using(user_id=auth.uid() or public.ap_staff(association_id));
create policy memberships_request on public.ap_memberships for insert to authenticated with check(user_id=auth.uid() and status='pending' and role='membru' and approved_at is null and resolution_reference='');
alter table public.ap_projects enable row level security;
create policy projects_read on public.ap_projects for select to authenticated using(public.ap_active(association_id));
create policy projects_insert on public.ap_projects for insert to authenticated with check(public.ap_active(association_id) and owner_id=auth.uid());
create policy projects_update on public.ap_projects for update to authenticated using(public.ap_active(association_id) and (owner_id=auth.uid() or public.ap_staff(association_id))) with check(public.ap_active(association_id) and (owner_id=auth.uid() or public.ap_staff(association_id)));
alter table public.ap_interactions enable row level security;
create policy interactions_read on public.ap_interactions for select to authenticated using(user_id=auth.uid() and public.ap_active(public.ap_project_association(project_id)));
create policy interactions_insert on public.ap_interactions for insert to authenticated with check(user_id=auth.uid() and public.ap_active(public.ap_project_association(project_id)));
create policy interactions_delete on public.ap_interactions for delete to authenticated using(user_id=auth.uid() and public.ap_active(public.ap_project_association(project_id)));
alter table public.ap_comments enable row level security;
create policy comments_read on public.ap_comments for select to authenticated using(public.ap_active(public.ap_project_association(project_id)));
create policy comments_insert on public.ap_comments for insert to authenticated with check(user_id=auth.uid() and public.ap_active(public.ap_project_association(project_id)));
create policy comments_delete on public.ap_comments for delete to authenticated using(public.ap_active(public.ap_project_association(project_id)) and (user_id=auth.uid() or public.ap_staff(public.ap_project_association(project_id))));
alter table public.ap_consultations enable row level security;
create policy consultations_read on public.ap_consultations for select to authenticated using(public.ap_active(association_id) and (payload->>'status'<>'draft' or public.ap_staff(association_id)));
create policy consultations_insert on public.ap_consultations for insert to authenticated with check(public.ap_staff(association_id) and owner_id=auth.uid());
create policy consultations_update on public.ap_consultations for update to authenticated using(public.ap_staff(association_id)) with check(public.ap_staff(association_id));
alter table public.ap_ballots enable row level security;
create policy ballots_own_read on public.ap_ballots for select to authenticated using(user_id=auth.uid() and public.ap_active(public.ap_poll_association(consultation_id)));
create policy ballots_insert on public.ap_ballots for insert to authenticated with check(user_id=auth.uid() and public.ap_eligible(consultation_id));
create policy ballots_update on public.ap_ballots for update to authenticated using(user_id=auth.uid() and public.ap_eligible(consultation_id)) with check(user_id=auth.uid() and public.ap_eligible(consultation_id));
create policy ballots_delete on public.ap_ballots for delete to authenticated using(user_id=auth.uid() and public.ap_eligible(consultation_id));
alter table public.ap_suggestions enable row level security;
create policy suggestions_read on public.ap_suggestions for select to authenticated using(public.ap_active(public.ap_poll_association(consultation_id)) and (user_id=auth.uid() or public.ap_staff(public.ap_poll_association(consultation_id))));
create policy suggestions_insert on public.ap_suggestions for insert to authenticated with check(user_id=auth.uid() and status='pending' and public.ap_eligible(consultation_id) and exists(select 1 from public.ap_consultations c where c.id=consultation_id and (c.payload->>'allowSuggestions')::boolean));
alter table public.ap_meetings enable row level security;
create policy meetings_read on public.ap_meetings for select to authenticated using(public.ap_active(association_id));
create policy meetings_insert on public.ap_meetings for insert to authenticated with check(public.ap_staff(association_id));
alter table public.ap_attendance enable row level security;
create policy attendance_read on public.ap_attendance for select to authenticated using(user_id=auth.uid() and public.ap_active(public.ap_meeting_association(meeting_id)));
create policy attendance_insert on public.ap_attendance for insert to authenticated with check(user_id=auth.uid() and public.ap_active(public.ap_meeting_association(meeting_id)));
create policy attendance_delete on public.ap_attendance for delete to authenticated using(user_id=auth.uid() and public.ap_active(public.ap_meeting_association(meeting_id)));
alter table public.ap_documents enable row level security;
create policy documents_read on public.ap_documents for select to authenticated using(public.ap_active(association_id));
create policy documents_insert on public.ap_documents for insert to authenticated with check(public.ap_staff(association_id));
-- Only an operational administrator may record the Council's membership approval.
create function public.ap_review_member(a uuid,u uuid,decision text,reference text,assigned_role text default 'membru') returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.ap_admin(a) or decision not in ('active','rejected') or assigned_role not in ('membru','coordonator','administrator') or length(trim(reference)) not between 1 and 300 then raise exception 'Aprobare neautorizată sau referință lipsă'; end if;
 if decision='active' and not exists(select 1 from public.ap_memberships where association_id=a and user_id=u and length(trim(application_reference))>0) then raise exception 'Este necesară referința cererii semnate'; end if;
 update public.ap_memberships set status=decision,role=case when decision='active' then assigned_role else 'membru' end,approved_at=case when decision='active' then now() else null end,resolution_reference=trim(reference) where association_id=a and user_id=u and status='pending';
 if not found then raise exception 'Cererea nu mai este în așteptare'; end if;
end $$;
create function public.ap_moderate(s uuid,accept boolean) returns void language plpgsql security definer set search_path='' as $$
declare proposal public.ap_suggestions; poll public.ap_consultations;
begin
 select * into proposal from public.ap_suggestions where id=s for update;
 select * into poll from public.ap_consultations where id=proposal.consultation_id for update;
 if proposal.id is null or not public.ap_staff(poll.association_id) or proposal.status<>'pending' or poll.payload->>'status'<>'open' or (poll.payload->>'deadline')::timestamptz<=now() then raise exception 'Moderare indisponibilă'; end if;
 if accept then
  update public.ap_consultations set payload=jsonb_set(payload,'{options}',payload->'options'||jsonb_build_array(trim(proposal.label))) where id=poll.id;
 end if;
 update public.ap_suggestions set status=case when accept then 'approved' else 'rejected' end where id=s;
end $$;
-- A single consistent snapshot; ballots of other people never leave the server.
create function public.ap_snapshot(a uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not public.ap_active(a) then raise exception 'Calitatea de membru nu este activă'; end if;
 select jsonb_build_object(
 'projects',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'owner_id',p.owner_id,'revision',p.revision,'payload',p.payload,
 'supporters',(select count(*) from public.ap_interactions i where i.project_id=p.id and kind='support' and i.user_id<>auth.uid()),
 'volunteers',(select count(*) from public.ap_interactions i where i.project_id=p.id and kind='volunteer' and i.user_id<>auth.uid()),
 'comments',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'userId',c.user_id,'body',c.body,'createdAt',c.created_at,'author',m.display_name) order by c.created_at) from public.ap_comments c join public.ap_memberships m on m.user_id=c.user_id and m.association_id=a where c.project_id=p.id),'[]'::jsonb))) from public.ap_projects p where p.association_id=a),'[]'::jsonb),
 'interactions',coalesce((select jsonb_agg(to_jsonb(i)) from public.ap_interactions i join public.ap_projects p on p.id=i.project_id where p.association_id=a and i.user_id=auth.uid()),'[]'::jsonb),
 'consultations',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'revision',c.revision,'payload',c.payload,'can_vote',public.ap_eligible(c.id),
 'counts',(select jsonb_agg((select count(*) from public.ap_ballots b where b.consultation_id=c.id and b.user_id<>auth.uid() and idx=any(b.choices)) order by idx) from generate_series(0,jsonb_array_length(c.payload->'options')-1) idx),
 'responses',(select count(*) from public.ap_ballots b where b.consultation_id=c.id and b.user_id<>auth.uid()),
 'eligible',(select count(*) from public.ap_memberships m where m.association_id=a and m.status='active' and (c.payload->>'eligibilityRule'='closing' and m.approved_at<=least(coalesce(c.closed_at,now()),coalesce(nullif(c.payload->>'deadline','')::timestamptz,now())) or c.payload->>'eligibilityRule'='opening' and m.approved_at<=c.opened_at)))) from public.ap_consultations c where c.association_id=a and (c.payload->>'status'<>'draft' or public.ap_staff(a))),'[]'::jsonb),
 'ballots',coalesce((select jsonb_agg(to_jsonb(b)) from public.ap_ballots b join public.ap_consultations c on c.id=b.consultation_id where c.association_id=a and b.user_id=auth.uid()),'[]'::jsonb),
 'suggestions',coalesce((select jsonb_agg(to_jsonb(s)) from public.ap_suggestions s join public.ap_consultations c on c.id=s.consultation_id where c.association_id=a and (s.user_id=auth.uid() or public.ap_staff(a))),'[]'::jsonb),
 'meetings',coalesce((select jsonb_agg(to_jsonb(m) order by m.starts_at) from public.ap_meetings m where m.association_id=a),'[]'::jsonb),
 'attendance',coalesce((select jsonb_agg(t.meeting_id) from public.ap_attendance t join public.ap_meetings m on m.id=t.meeting_id where m.association_id=a and t.user_id=auth.uid()),'[]'::jsonb),
 'documents',coalesce((select jsonb_agg(to_jsonb(d) order by d.created_at desc) from public.ap_documents d where d.association_id=a),'[]'::jsonb)
 ) into result;
 return result;
end $$;
-- Explicit least-privilege grants: no broad ALL grants on future tables.
grant usage on schema public to authenticated;
grant select on public.ap_associations to authenticated;
grant select,insert on public.ap_memberships to authenticated;
grant select,insert,update on public.ap_projects,public.ap_consultations to authenticated;
grant select,insert,delete on public.ap_interactions,public.ap_comments,public.ap_attendance to authenticated;
grant select,insert,update,delete on public.ap_ballots to authenticated;
grant select,insert on public.ap_suggestions,public.ap_meetings,public.ap_documents to authenticated;
-- PostgreSQL grants EXECUTE to PUBLIC by default; revoke every exposed function.
revoke all on function public.ap_active(uuid),public.ap_staff(uuid),public.ap_admin(uuid),public.ap_eligible(uuid),public.ap_project_association(uuid),public.ap_poll_association(uuid),public.ap_meeting_association(uuid),public.ap_review_member(uuid,uuid,text,text,text),public.ap_moderate(uuid,boolean),public.ap_snapshot(uuid),public.ap_project_guard(),public.ap_consultation_guard(),public.ap_ballot_guard() from public,anon;
grant execute on function public.ap_active(uuid),public.ap_staff(uuid),public.ap_admin(uuid),public.ap_eligible(uuid),public.ap_project_association(uuid),public.ap_poll_association(uuid),public.ap_meeting_association(uuid),public.ap_review_member(uuid,uuid,text,text,text),public.ap_moderate(uuid,boolean),public.ap_snapshot(uuid) to authenticated;
commit;
