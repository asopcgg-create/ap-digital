begin;
-- Technical access is independent of association membership and never grants ap_active/ap_staff.
create table public.ap_technical_access(association_id uuid not null references public.ap_associations,user_id uuid not null references auth.users,enabled boolean not null default true,created_at timestamptz not null default now(),primary key(association_id,user_id));
alter table public.ap_technical_access enable row level security;
revoke all on public.ap_technical_access from public,anon,authenticated;
create function public.ap_technical(a uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.ap_technical_access where association_id=a and user_id=auth.uid() and enabled)$$;
create function public.ap_operator(a uuid) returns boolean language sql stable security definer set search_path='' as $$select public.ap_admin(a) or public.ap_technical(a)$$;
create table public.ap_activity_log(id uuid primary key default gen_random_uuid(),association_id uuid not null references public.ap_associations,actor_id uuid,actor_name text not null,actor_role text not null,entity text not null,entity_id text,action text not null,label text,fields text[] not null default '{}',changes jsonb not null default '{}',created_at timestamptz not null default now());
create index ap_activity_search on public.ap_activity_log(association_id,created_at desc);
alter table public.ap_activity_log enable row level security;
revoke all on public.ap_activity_log from public,anon,authenticated;
create table public.ap_technical_settings(association_id uuid primary key references public.ap_associations,maintenance boolean not null default false,message text not null default 'Platforma este în mentenanță. Modificările vor fi disponibile în curând.',updated_at timestamptz not null default now());
alter table public.ap_technical_settings enable row level security;revoke all on public.ap_technical_settings from public,anon,authenticated;
create table public.ap_technical_errors(id uuid primary key default gen_random_uuid(),association_id uuid not null references public.ap_associations,module text not null,code text not null,user_id uuid,created_at timestamptz not null default now(),resolved_at timestamptz);
alter table public.ap_technical_errors enable row level security;revoke all on public.ap_technical_errors from public,anon,authenticated;
alter table public.ap_mail_jobs add column technical_retries integer not null default 0;
create function public.ap_audit_change() returns trigger language plpgsql security definer set search_path='' as $$
declare n jsonb:=case when TG_OP='DELETE' then to_jsonb(old) else to_jsonb(new) end;o jsonb:=case when TG_OP='INSERT' then '{}'::jsonb else to_jsonb(old) end;a uuid;who text;role_name text;keys text[];delta jsonb:='{}';k text;eid text;
begin
 a:=nullif(n->>'association_id','')::uuid;
 if a is null and n ? 'project_id' then select association_id into a from public.ap_projects where id=(n->>'project_id')::uuid;end if;
 if a is null and n ? 'meeting_id' then select association_id into a from public.ap_meetings where id=(n->>'meeting_id')::uuid;end if;
 if a is null and n ? 'consultation_id' then select association_id into a from public.ap_consultations where id=(n->>'consultation_id')::uuid;end if;
 if a is null and n ? 'lead_id' then select association_id into a from public.ap_sponsorships where id=(n->>'lead_id')::uuid;end if;
 if a is null and n ? 'draft_id' then select association_id into a from public.ap_drafts where id=(n->>'draft_id')::uuid;end if;
 if a is null then return coalesce(new,old);end if;
 select display_name,role into who,role_name from public.ap_memberships where association_id=a and user_id=auth.uid();
 if who is null then who:=case when public.ap_technical(a) then 'Responsabil tehnic' else 'Sistem' end;role_name:=case when public.ap_technical(a) then 'tehnic' else 'sistem' end;end if;
 select coalesce(array_agg(key order by key),'{}') into keys from jsonb_object_keys(n) key where n->key is distinct from o->key and key not in ('state_b64','plain_text','body','payload','claim_id','last_error');
 if n ? 'payload' and n->'payload' is distinct from o->'payload' then
 for k in select key from jsonb_object_keys(n->'payload') key where n->'payload'->key is distinct from o->'payload'->key loop keys:=array_append(keys,'payload.'||k);end loop;
 if jsonb_typeof(n->'payload'->'progress')='number' and n->'payload'->'progress' is distinct from o->'payload'->'progress' then delta:=delta||jsonb_build_object('progress',jsonb_build_object('before',o->'payload'->'progress','after',n->'payload'->'progress'));end if;end if;
 -- Store values only for a narrow set of non-personal workflow indicators.
 foreach k in array array['status','stage','progress','cancelled','maintenance','enabled','role'] loop
 if n->k is distinct from o->k then delta:=delta||jsonb_build_object(k,jsonb_build_object('before',o->k,'after',n->k));end if;end loop;
 eid:=coalesce(n->>'id',n->>'user_id',n->>'project_id',n->>'meeting_id');
 insert into public.ap_activity_log(association_id,actor_id,actor_name,actor_role,entity,entity_id,action,label,fields,changes) values(a,auth.uid(),who,role_name,TG_TABLE_NAME,eid,lower(TG_OP),left(coalesce(n->>'title',n->'payload'->>'title',n->>'organization',''),160),keys,delta);
 return coalesce(new,old);
end $$;
create function public.ap_maintenance_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare n jsonb:=case when TG_OP='DELETE' then to_jsonb(old) else to_jsonb(new) end;a uuid;
begin
 if auth.uid() is null then return coalesce(new,old);end if;
 a:=nullif(n->>'association_id','')::uuid;
 if a is null and n ? 'project_id' then select association_id into a from public.ap_projects where id=(n->>'project_id')::uuid;end if;
 if a is null and n ? 'meeting_id' then select association_id into a from public.ap_meetings where id=(n->>'meeting_id')::uuid;end if;
 if a is null and n ? 'consultation_id' then select association_id into a from public.ap_consultations where id=(n->>'consultation_id')::uuid;end if;
 if a is null and n ? 'lead_id' then select association_id into a from public.ap_sponsorships where id=(n->>'lead_id')::uuid;end if;
 if a is null and n ? 'draft_id' then select association_id into a from public.ap_drafts where id=(n->>'draft_id')::uuid;end if;
 if exists(select 1 from public.ap_technical_settings where association_id=a and maintenance) then raise exception 'Platforma este în mentenanță. Reîncearcă mai târziu.';end if;
 return coalesce(new,old);
end $$;
do $$declare t text;begin
 foreach t in array array['ap_memberships','ap_projects','ap_comments','ap_interactions','ap_consultations','ap_suggestions','ap_meetings','ap_attendance','ap_documents','ap_drafts','ap_applications','ap_reconfirmations','ap_sponsorships','ap_sponsorship_files','ap_draft_versions'] loop
 if to_regclass('public.'||t) is not null then
 execute format('create trigger ap_activity after insert or update or delete on public.%I for each row execute function public.ap_audit_change()',t);
 execute format('create trigger ap_maintenance before insert or update or delete on public.%I for each row execute function public.ap_maintenance_guard()',t);
 end if;end loop;
 foreach t in array array['ap_technical_access','ap_technical_settings','ap_technical_errors'] loop execute format('create trigger ap_activity after insert or update or delete on public.%I for each row execute function public.ap_audit_change()',t);end loop;
end $$;
create function public.ap_access_status(a uuid) returns jsonb language sql stable security definer set search_path='' as $$select jsonb_build_object('technical',public.ap_technical(a),'maintenance',coalesce((select maintenance from public.ap_technical_settings where association_id=a),false),'message',coalesce((select message from public.ap_technical_settings where association_id=a),'')) where auth.uid() is not null$$;
create function public.ap_set_maintenance(a uuid,enabled boolean,note text) returns void language plpgsql security definer set search_path='' as $$begin
 if not public.ap_operator(a) or length(trim(note)) not between 1 and 300 then raise exception 'Acces neautorizat sau mesaj invalid';end if;
 insert into public.ap_technical_settings(association_id,maintenance,message) values(a,enabled,trim(note)) on conflict(association_id) do update set maintenance=excluded.maintenance,message=excluded.message,updated_at=now();end $$;
create function public.ap_report_error(a uuid,m text,c text) returns void language plpgsql security definer set search_path='' as $$begin
 if not (public.ap_active(a) or public.ap_technical(a)) then return;end if;
 if m not in ('aplicatie','documente','redactare','sponsorizari','salvare','incarcare') or c not in ('operation_failed','load_failed','runtime_error','storage_failed') then return;end if;
 if (select count(*) from public.ap_technical_errors where user_id=auth.uid() and created_at>now()-interval '1 hour')>=20 then return;end if;
 insert into public.ap_technical_errors(association_id,module,code,user_id) values(a,m,c,auth.uid());end $$;
create function public.ap_resolve_error(a uuid,i uuid) returns void language plpgsql security definer set search_path='' as $$begin if not public.ap_operator(a) then raise exception 'Acces neautorizat';end if;update public.ap_technical_errors set resolved_at=now() where association_id=a and id=i and resolved_at is null;end $$;
create function public.ap_retry_mail(a uuid,i uuid) returns void language plpgsql security definer set search_path='' as $$begin
 if not public.ap_operator(a) then raise exception 'Acces neautorizat';end if;
 update public.ap_mail_jobs set state='pending',attempts=0,next_attempt_at=now(),technical_retries=technical_retries+1,claim_id=null,claimed_at=null where association_id=a and id=i and state='failed' and technical_retries=0 and created_at>now()-interval '7 days';
 if not found then raise exception 'Reîncercarea este permisă o singură dată pentru un mesaj eșuat recent.';end if;
 insert into public.ap_activity_log(association_id,actor_id,actor_name,actor_role,entity,entity_id,action) values(a,auth.uid(),'Operator','tehnic','ap_mail_jobs',i::text,'retry');end $$;
create function public.ap_activity(a uuid,q text default '',module_filter text default '',action_filter text default '',since_at timestamptz default null,until_at timestamptz default null,before_at timestamptz default null,before_id uuid default null) returns jsonb language plpgsql stable security definer set search_path='' as $$declare full_access boolean:=public.ap_admin(a);r jsonb;begin
 if not public.ap_operator(a) then raise exception 'Acces neautorizat';end if;
 select coalesce(jsonb_agg(row_data order by created_at desc,id desc),'[]') into r from (select id,created_at,jsonb_build_object('id',id,'created_at',created_at,'actor',case when full_access then actor_name else actor_role end,'role',actor_role,'entity',entity,'entity_id',entity_id,'action',action,'label',case when full_access then label else '' end,'fields',fields,'changes',changes) row_data from public.ap_activity_log where association_id=a and (module_filter='' or entity=module_filter) and (action_filter='' or action=action_filter) and (since_at is null or created_at>=since_at) and (until_at is null or created_at<=until_at) and (before_at is null or (created_at,id)<(before_at,coalesce(before_id,'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid))) and (q='' or (case when full_access then actor_name||' '||coalesce(label,'') else actor_role end) ilike '%'||left(q,100)||'%') order by created_at desc,id desc limit 100) x;return r;end $$;
create function public.ap_diagnostics(a uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$declare r jsonb;begin
 if not public.ap_operator(a) then raise exception 'Acces neautorizat';end if;
 select jsonb_build_object('server_time',now(),'database','ok','maintenance',coalesce((select maintenance from public.ap_technical_settings where association_id=a),false),'message',coalesce((select message from public.ap_technical_settings where association_id=a),'Platforma este în mentenanță.'),
 'mail',coalesce((select jsonb_agg(jsonb_build_object('id',id,'kind',kind,'state',state,'attempts',attempts,'technical_retries',technical_retries,'created_at',created_at,'sent_at',sent_at)) from (select * from public.ap_mail_jobs where association_id=a order by created_at desc limit 50) j),'[]'),
 'errors',coalesce((select jsonb_agg(jsonb_build_object('id',id,'module',module,'code',code,'created_at',created_at,'resolved_at',resolved_at)) from (select * from public.ap_technical_errors where association_id=a order by created_at desc limit 50) e),'[]'),
 'storage',coalesce((select jsonb_agg(to_jsonb(b)) from (select bucket_id,count(*) objects,count(*) filter(where (bucket_id='ap-documents' and not exists(select 1 from public.ap_documents d where d.file_path=so.name) and not exists(select 1 from public.ap_document_versions v where v.snapshot->>'file_path'=so.name)) or (bucket_id='ap-sponsorships' and not exists(select 1 from public.ap_sponsorship_files f where f.file_path=so.name))) unlinked,coalesce(sum(case when metadata->>'size' ~ '^[0-9]+$' then (metadata->>'size')::bigint else 0 end),0) bytes from storage.objects so where name like a::text||'/%' group by bucket_id) b),'[]')) into r;return r;end $$;
-- Grant/revoke is an explicit administrator action; no passwords or implicit accounts in migrations.
create function public.ap_set_technical_access(a uuid,u uuid,enabled boolean) returns void language plpgsql security definer set search_path='' as $$begin
 if not public.ap_admin(a) then raise exception 'Doar administratorul poate acorda acces tehnic';end if;
 if not exists(select 1 from auth.users where id=u and email_confirmed_at is not null) then raise exception 'Contul trebuie să aibă e-mail confirmat';end if;
 insert into public.ap_technical_access(association_id,user_id,enabled) values(a,u,enabled) on conflict(association_id,user_id) do update set enabled=excluded.enabled;end $$;
revoke all on function public.ap_audit_change(),public.ap_maintenance_guard() from public,anon,authenticated;
revoke all on function public.ap_technical(uuid),public.ap_operator(uuid),public.ap_access_status(uuid),public.ap_set_maintenance(uuid,boolean,text),public.ap_report_error(uuid,text,text),public.ap_resolve_error(uuid,uuid),public.ap_retry_mail(uuid,uuid),public.ap_activity(uuid,text,text,text,timestamptz,timestamptz,timestamptz,uuid),public.ap_diagnostics(uuid),public.ap_set_technical_access(uuid,uuid,boolean) from public,anon;
grant execute on function public.ap_technical(uuid),public.ap_operator(uuid),public.ap_access_status(uuid),public.ap_set_maintenance(uuid,boolean,text),public.ap_report_error(uuid,text,text),public.ap_resolve_error(uuid,uuid),public.ap_retry_mail(uuid,uuid),public.ap_activity(uuid,text,text,text,timestamptz,timestamptz,timestamptz,uuid),public.ap_diagnostics(uuid),public.ap_set_technical_access(uuid,uuid,boolean) to authenticated;

create function public.ap_technical_accounts(a uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$begin
 if not public.ap_admin(a) then raise exception 'Acces neautorizat';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('email',u.email,'enabled',t.enabled)) from public.ap_technical_access t join auth.users u on u.id=t.user_id where t.association_id=a),'[]');end $$;
create function public.ap_technical_by_email(a uuid,e text,enabled boolean) returns void language plpgsql security definer set search_path='' as $$declare u uuid;begin
 if not public.ap_admin(a) then raise exception 'Acces neautorizat';end if;
 select id into u from auth.users where lower(email)=lower(trim(e)) and email_confirmed_at is not null;
 if u is null then raise exception 'Adresa nu are încă un cont confirmat';end if;
 perform public.ap_set_technical_access(a,u,enabled);end $$;
create function public.ap_storage_maintenance() returns trigger language plpgsql security definer set search_path='' as $$declare path text:=case when TG_OP='DELETE' then old.name else new.name end;a uuid;begin
 if auth.uid() is null then return coalesce(new,old);end if;
 if split_part(path,'/',1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
 a:=split_part(path,'/',1)::uuid;if exists(select 1 from public.ap_technical_settings where association_id=a and maintenance) then raise exception 'Platforma este în mentenanță. Încărcarea fișierelor este suspendată.';end if;end if;return coalesce(new,old);end $$;
create trigger ap_storage_maintenance before insert or update or delete on storage.objects for each row execute function public.ap_storage_maintenance();
revoke all on function public.ap_storage_maintenance() from public,anon,authenticated;
revoke all on function public.ap_technical_accounts(uuid),public.ap_technical_by_email(uuid,text,boolean) from public,anon;
grant execute on function public.ap_technical_accounts(uuid),public.ap_technical_by_email(uuid,text,boolean) to authenticated;

commit;
