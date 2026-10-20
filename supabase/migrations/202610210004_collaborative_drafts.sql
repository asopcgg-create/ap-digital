begin;
create table public.ap_drafts(id uuid primary key default gen_random_uuid(),association_id uuid not null references public.ap_associations,title text not null check(length(trim(title)) between 1 and 120),meeting_id uuid references public.ap_meetings,revision integer not null default 1,state_b64 text not null default '',plain_text text not null default '' check(length(plain_text)<=100000),updated_at timestamptz not null default now(),updated_by uuid references auth.users,published_revision integer);
alter table public.ap_drafts enable row level security;
create policy drafts_staff on public.ap_drafts for select to authenticated using(public.ap_staff(association_id));
grant select on public.ap_drafts to authenticated;
create table public.ap_draft_versions(id uuid primary key default gen_random_uuid(),draft_id uuid not null references public.ap_drafts on delete cascade,revision integer not null,title text not null,plain_text text not null,created_at timestamptz not null default now(),created_by uuid references auth.users);
alter table public.ap_draft_versions enable row level security;
create policy draft_history_staff on public.ap_draft_versions for select to authenticated using(exists(select 1 from public.ap_drafts d where d.id=draft_id and public.ap_staff(d.association_id)));
grant select on public.ap_draft_versions to authenticated;
create function public.ap_create_draft(a uuid,t text,m uuid default null,s text default '',p text default '') returns public.ap_drafts language plpgsql security definer set search_path='' as $$declare d public.ap_drafts;begin
 if not public.ap_staff(a) then raise exception 'Acces indisponibil'; end if;
 if m is not null and not exists(select 1 from public.ap_meetings where id=m and association_id=a) then raise exception 'Întâlnire invalidă'; end if;
 if length(s)>1400000 or octet_length(decode(s,'base64'))>1048576 or length(p)>100000 then raise exception 'Document prea mare'; end if;
 insert into public.ap_drafts(association_id,title,meeting_id,updated_by,state_b64,plain_text) values(a,trim(t),m,auth.uid(),s,p) returning * into d;return d;
end $$;
-- Full CRDT states are merged by clients; compare-and-swap forces a merge on concurrent saves.
create function public.ap_save_draft(a uuid,i uuid,v integer,s text,p text) returns jsonb language plpgsql security definer set search_path='' as $$declare d public.ap_drafts;begin
 if not public.ap_staff(a) then raise exception 'Acces indisponibil'; end if;
 select * into d from public.ap_drafts where id=i and association_id=a for update;
 if d.id is null then raise exception 'Ciornă indisponibilă'; end if;
 if d.revision is distinct from v then return jsonb_build_object('saved',false,'draft',to_jsonb(d)); end if;
 if s is null or length(s)>1400000 or octet_length(decode(s,'base64'))>1048576 or length(p)>100000 then raise exception 'Documentul depășește limita editorului'; end if;
 update public.ap_drafts set state_b64=s,plain_text=p,revision=revision+1,updated_at=clock_timestamp(),updated_by=auth.uid() where id=i returning * into d;
 return jsonb_build_object('saved',true,'draft',to_jsonb(d));
end $$;
create function public.ap_checkpoint_draft(a uuid,i uuid,v integer) returns void language plpgsql security definer set search_path='' as $$declare d public.ap_drafts;begin
 if not public.ap_staff(a) then raise exception 'Acces indisponibil'; end if;
 select * into d from public.ap_drafts where id=i and association_id=a for update;
 if d.id is null or d.revision is distinct from v then raise exception 'Ciornă modificată între timp. Așteaptă sincronizarea.'; end if;
 insert into public.ap_draft_versions(draft_id,revision,title,plain_text,created_by) values(i,d.revision,d.title,d.plain_text,auth.uid());
end $$;
create function public.ap_publish_draft(a uuid,i uuid,v integer) returns uuid language plpgsql security definer set search_path='' as $$declare d public.ap_drafts;doc uuid;begin
 if not public.ap_staff(a) then raise exception 'Acces indisponibil'; end if;
 select * into d from public.ap_drafts where id=i and association_id=a for update;
 if d.id is null or d.revision is distinct from v or d.published_revision=v then raise exception 'Ciornă modificată sau copie deja publicată. Actualizează înainte de publicare.'; end if;
 if length(trim(d.plain_text)) not between 1 and 50000 then raise exception 'Copia publicată trebuie să conțină între 1 și 50.000 de caractere'; end if;
 insert into public.ap_documents(association_id,title,category,body) values(a,d.title,'Procese-verbale',d.plain_text) returning id into doc;
 insert into public.ap_draft_versions(draft_id,revision,title,plain_text,created_by) values(i,d.revision,d.title,d.plain_text,auth.uid());
 update public.ap_drafts set published_revision=v where id=i;return doc;
end $$;
revoke all on function public.ap_create_draft(uuid,text,uuid,text,text),public.ap_save_draft(uuid,uuid,integer,text,text),public.ap_checkpoint_draft(uuid,uuid,integer),public.ap_publish_draft(uuid,uuid,integer) from public,anon;
grant execute on function public.ap_create_draft(uuid,text,uuid,text,text),public.ap_save_draft(uuid,uuid,integer,text,text),public.ap_checkpoint_draft(uuid,uuid,integer),public.ap_publish_draft(uuid,uuid,integer) to authenticated;
do $$begin if exists(select 1 from pg_publication where pubname='supabase_realtime') then alter publication supabase_realtime add table public.ap_drafts;end if;end $$;
commit;
