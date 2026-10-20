begin;
alter table public.ap_documents add column revision integer not null default 1,add column updated_at timestamptz not null default now(),add column deleted_at timestamptz,add column purge_requested_at timestamptz;
create table public.ap_document_versions(id uuid primary key default gen_random_uuid(),document_id uuid not null references public.ap_documents on delete cascade,revision integer not null,snapshot jsonb not null,changed_by uuid references auth.users,created_at timestamptz not null default now(),unique(document_id,revision));
alter table public.ap_document_versions enable row level security;
create policy document_history_staff on public.ap_document_versions for select to authenticated using(exists(select 1 from public.ap_documents d where d.id=document_id and public.ap_staff(d.association_id)));
grant select on public.ap_document_versions to authenticated;
insert into public.ap_document_versions(document_id,revision,snapshot) select id,revision,to_jsonb(d) from public.ap_documents d;
create function public.ap_document_file_history_guard() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.file_path is not null and exists(select 1 from public.ap_document_versions where snapshot->>'file_path'=new.file_path and document_id<>new.id) then raise exception 'Fișierul este asociat altui document. Încarcă o copie separată.'; end if;return new;
end $$;
create trigger ap_document_file_history_guard before insert or update on public.ap_documents for each row execute function public.ap_document_file_history_guard();
revoke all on function public.ap_document_file_history_guard() from public,anon,authenticated;
create function public.ap_document_history() returns trigger language plpgsql security definer set search_path='' as $$begin
 if tg_op='INSERT' or new.revision<>old.revision then insert into public.ap_document_versions(document_id,revision,snapshot,changed_by) values(new.id,new.revision,to_jsonb(new),auth.uid()); end if;return new;
end $$;
create trigger ap_document_history after insert or update on public.ap_documents for each row execute function public.ap_document_history();
drop trigger ap_document_file_check on public.ap_documents;
create trigger ap_document_file_check before insert or update on public.ap_documents for each row execute function public.ap_document_file_check();
drop policy documents_read on public.ap_documents;
create policy documents_read on public.ap_documents for select to authenticated using(public.ap_staff(association_id) or (public.ap_active(association_id) and deleted_at is null and purge_requested_at is null));
create function public.ap_update_document(a uuid,i uuid,v integer,p jsonb) returns void language plpgsql security definer set search_path='' as $$
declare d public.ap_documents;
begin
 if not public.ap_staff(a) then raise exception 'Acces indisponibil'; end if;
 select * into d from public.ap_documents where id=i and association_id=a for update;
 if d.id is null or d.revision is distinct from v or d.deleted_at is not null or d.purge_requested_at is not null then raise exception 'Document modificat sau indisponibil. Actualizează lista.'; end if;
 if jsonb_typeof(p) is distinct from 'object' or (p-array['title','category','body','file_path','file_name'])<>'{}'::jsonb then raise exception 'Actualizare invalidă'; end if;
 if p?'file_path' and (d.file_path is null or nullif(p->>'file_path','') is null) then raise exception 'Înlocuirea necesită un fișier valid'; end if;
 update public.ap_documents set title=coalesce(p->>'title',d.title),category=coalesce(p->>'category',d.category),body=coalesce(p->>'body',d.body),file_path=case when p?'file_path' then p->>'file_path' else d.file_path end,file_name=case when p?'file_name' then p->>'file_name' else d.file_name end,revision=revision+1,updated_at=clock_timestamp() where id=i;
end $$;
create function public.ap_trash_document(a uuid,i uuid,v integer,restore boolean default false) returns void language plpgsql security definer set search_path='' as $$begin
 if not public.ap_staff(a) then raise exception 'Acces indisponibil'; end if;
 update public.ap_documents set deleted_at=case when restore then null else clock_timestamp() end,revision=revision+1,updated_at=clock_timestamp() where id=i and association_id=a and revision=v and purge_requested_at is null and (deleted_at is not null)=restore;
 if not found then raise exception 'Document modificat sau indisponibil. Actualizează lista.'; end if;
end $$;
create function public.ap_restore_document_version(a uuid,i uuid,v integer,version integer) returns void language plpgsql security definer set search_path='' as $$declare s jsonb;d public.ap_documents;begin
 if not public.ap_staff(a) then raise exception 'Acces indisponibil'; end if;
 select * into d from public.ap_documents where id=i and association_id=a for update;
 if d.id is null or d.revision is distinct from v or d.deleted_at is not null or d.purge_requested_at is not null then raise exception 'Document modificat sau indisponibil'; end if;
 select snapshot into s from public.ap_document_versions where document_id=i and revision=version;
 if s is null then raise exception 'Versiune indisponibilă'; end if;
 update public.ap_documents set title=s->>'title',category=s->>'category',body=s->>'body',file_path=s->>'file_path',file_name=s->>'file_name',file_size=(s->>'file_size')::bigint,mime_type=s->>'mime_type',revision=revision+1,updated_at=clock_timestamp() where id=i;
end $$;
create or replace function public.ap_document_file_published(p text) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.ap_documents where file_path=p) or exists(select 1 from public.ap_document_versions where snapshot->>'file_path'=p)$$;
create function public.ap_document_file_access(p text) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.ap_documents d where d.purge_requested_at is null and ((d.file_path=p and d.deleted_at is null and public.ap_active(d.association_id)) or (public.ap_staff(d.association_id) and (d.file_path=p or exists(select 1 from public.ap_document_versions v where v.document_id=d.id and v.snapshot->>'file_path'=p)))))$$;
create function public.ap_document_file_purge(p text) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.ap_documents d where public.ap_admin(d.association_id) and d.deleted_at is not null and d.purge_requested_at is not null and (d.file_path=p or exists(select 1 from public.ap_document_versions v where v.document_id=d.id and v.snapshot->>'file_path'=p)))$$;
drop policy ap_document_download on storage.objects;
create policy ap_document_download on storage.objects for select to authenticated using(bucket_id='ap-documents' and (public.ap_document_file_access(name) or public.ap_document_file_purge(name) or (owner_id=auth.uid()::text and public.ap_document_can_upload(name) and not public.ap_document_file_published(name))));
drop policy ap_document_cleanup on storage.objects;
create policy ap_document_cleanup on storage.objects for delete to authenticated using(bucket_id='ap-documents' and (public.ap_document_file_purge(name) or (owner_id=auth.uid()::text and not public.ap_document_file_published(name))));
create function public.ap_prepare_document_purge(a uuid,i uuid,v integer) returns text[] language plpgsql security definer set search_path='' as $$declare paths text[];d public.ap_documents;begin
 if not public.ap_admin(a) then raise exception 'Doar administratorii pot șterge definitiv'; end if;
 select * into d from public.ap_documents where id=i and association_id=a for update;
 if d.id is null or d.revision is distinct from v or d.deleted_at is null then raise exception 'Document modificat sau nu este în coș'; end if;
 if d.purge_requested_at is null then update public.ap_documents set purge_requested_at=clock_timestamp() where id=i; end if;
 select coalesce(array_agg(distinct path) filter(where path is not null),'{}') into paths from (select file_path path from public.ap_documents where id=i union select snapshot->>'file_path' from public.ap_document_versions where document_id=i) s;return paths;
end $$;
create function public.ap_finish_document_purge(a uuid,i uuid) returns void language plpgsql security definer set search_path='' as $$declare d public.ap_documents;begin
 if not public.ap_admin(a) then raise exception 'Acces indisponibil'; end if;
 select * into d from public.ap_documents where id=i and association_id=a for update;
 if d.id is null or d.deleted_at is null or d.purge_requested_at is null then raise exception 'Ștergerea nu a fost pregătită'; end if;
 if exists(select 1 from storage.objects o where o.bucket_id='ap-documents' and (o.name=d.file_path or exists(select 1 from public.ap_document_versions v where v.document_id=i and v.snapshot->>'file_path'=o.name))) then raise exception 'Fișierele nu au fost eliminate. Reîncearcă ștergerea.'; end if;
 delete from public.ap_documents where id=i;
end $$;
revoke all on function public.ap_document_history(),public.ap_update_document(uuid,uuid,integer,jsonb),public.ap_trash_document(uuid,uuid,integer,boolean),public.ap_restore_document_version(uuid,uuid,integer,integer),public.ap_document_file_access(text),public.ap_document_file_purge(text),public.ap_prepare_document_purge(uuid,uuid,integer),public.ap_finish_document_purge(uuid,uuid) from public,anon;
grant execute on function public.ap_update_document(uuid,uuid,integer,jsonb),public.ap_trash_document(uuid,uuid,integer,boolean),public.ap_restore_document_version(uuid,uuid,integer,integer),public.ap_document_file_access(text),public.ap_document_file_purge(text),public.ap_prepare_document_purge(uuid,uuid,integer),public.ap_finish_document_purge(uuid,uuid) to authenticated;
create or replace function public.ap_snapshot(a uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
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
 'meetings',coalesce((select jsonb_agg(to_jsonb(m)||jsonb_build_object('confirmed_count',(select count(*) from public.ap_attendance t where t.meeting_id=m.id)) order by m.starts_at) from public.ap_meetings m where m.association_id=a),'[]'::jsonb),
 'attendance',coalesce((select jsonb_agg(t.meeting_id) from public.ap_attendance t join public.ap_meetings m on m.id=t.meeting_id where m.association_id=a and t.user_id=auth.uid()),'[]'::jsonb),
 'documents',coalesce((select jsonb_agg(to_jsonb(d) order by d.created_at desc) from public.ap_documents d where d.association_id=a and d.deleted_at is null and d.purge_requested_at is null),'[]'::jsonb)
 ) into result;
 return result;
end $$;

commit;
