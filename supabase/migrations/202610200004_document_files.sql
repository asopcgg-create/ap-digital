-- Private attachments; existing text documents remain valid.
alter table public.ap_documents add column file_path text, add column file_name text, add column file_size bigint, add column mime_type text;
alter table public.ap_documents drop constraint ap_documents_body_check;
alter table public.ap_documents add constraint document_content check (
 (file_path is null and file_name is null and file_size is null and mime_type is null and length(body) between 1 and 50000)
 or (file_path is not null and file_name is not null and file_size is not null and mime_type is not null and length(file_name) between 1 and 255 and file_size between 1 and 26214400 and length(body)<=50000)
);
create unique index ap_documents_file_path_unique on public.ap_documents(file_path) where file_path is not null;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('ap-documents','ap-documents',false,26214400,null);
create function public.ap_document_file_check() returns trigger language plpgsql security definer set search_path='' as $$
declare obj storage.objects;
begin
 if new.file_path is null then return new; end if;
 if new.file_path !~ ('^'||new.association_id::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception 'Calea fișierului nu este validă.'; end if;
 select * into obj from storage.objects where bucket_id='ap-documents' and name=new.file_path;
 if not found then raise exception 'Fișierul trebuie încărcat înainte de publicare.'; end if;
 new.file_size := (obj.metadata->>'size')::bigint;
 new.mime_type := coalesce(obj.metadata->>'mimetype','application/octet-stream');
 if new.file_size is null then raise exception 'Dimensiunea fișierului nu a putut fi verificată.'; end if;
 return new;
end $$;
revoke all on function public.ap_document_file_check() from public,anon,authenticated;
create trigger ap_document_file_check before insert on public.ap_documents for each row execute function public.ap_document_file_check();
create function public.ap_document_can_upload(p text) returns boolean language sql stable set search_path='' as $$
 select case when p ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then public.ap_staff(split_part(p,'/',1)::uuid) else false end
$$;
create policy ap_document_upload on storage.objects for insert to authenticated with check (bucket_id='ap-documents' and public.ap_document_can_upload(name));
create policy ap_document_download on storage.objects for select to authenticated using (
 bucket_id='ap-documents' and (
 exists(select 1 from public.ap_documents d where d.file_path=name and public.ap_active(d.association_id))
 or (owner_id=auth.uid()::text and public.ap_document_can_upload(name)))
);
create function public.ap_document_file_published(p text) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.ap_documents where file_path=p)$$;
revoke all on function public.ap_document_file_published(text) from public,anon;
grant execute on function public.ap_document_file_published(text) to authenticated;
-- Failed publication can clean up its own unpublished upload; published files are immutable.
create policy ap_document_cleanup on storage.objects for delete to authenticated using (
 bucket_id='ap-documents' and owner_id=auth.uid()::text
 and not public.ap_document_file_published(name)
);
