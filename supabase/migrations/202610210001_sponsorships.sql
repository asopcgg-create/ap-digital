begin;
create table public.ap_sponsorships(
 id uuid primary key default gen_random_uuid(),association_id uuid not null references public.ap_associations,
 created_by uuid not null default auth.uid() references auth.users,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),revision integer not null default 1,
 organization text not null check(length(trim(organization)) between 1 and 160),sector text not null default '' check(length(sector)<=160),
 support_types text[] not null check(cardinality(support_types) between 1 and 4 and support_types <@ array['Bani','Produse','Servicii','Voluntariat']::text[]),
 contact_name text not null default '' check(length(contact_name)<=160),contact_email text not null default '' check(length(contact_email)<=254),contact_phone text not null default '' check(length(contact_phone)<=60),
 introduction text not null default '' check(length(introduction)<=1000),summary text not null default '' check(length(summary)<=2000),project_id uuid references public.ap_projects,
 stage text not null default 'propus' check(stage in ('propus','de_contactat','discutii','confirmat','inchis')),
 responsible_id uuid references auth.users,next_step text not null default '' check(length(next_step)<=1000),next_contact date,notes text not null default '' check(length(notes)<=10000),
 estimated_amount numeric(14,2) not null default 0 check(estimated_amount between 0 and 999999999999),confirmed_amount numeric(14,2) not null default 0 check(confirmed_amount between 0 and 999999999999),received_amount numeric(14,2) not null default 0 check(received_amount between 0 and confirmed_amount)
);
create index ap_sponsorships_association on public.ap_sponsorships(association_id,created_at desc);
alter table public.ap_sponsorships enable row level security;
create policy sponsorship_staff on public.ap_sponsorships for select to authenticated using(public.ap_staff(association_id));
grant select on public.ap_sponsorships to authenticated;
create function public.ap_propose_sponsorship(a uuid,p jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; project uuid; types text[];
begin
 if not public.ap_active(a) then raise exception 'Acces indisponibil'; end if;
 if jsonb_typeof(p) is distinct from 'object' or (p-array['organization','sector','support_types','contact_name','contact_email','contact_phone','introduction','summary','project_id'])<>'{}'::jsonb then raise exception 'Propunere invalidă'; end if;
 if jsonb_typeof(p->'support_types') is distinct from 'array' then raise exception 'Alege tipul de sprijin'; end if;
 select array_agg(distinct value) into types from jsonb_array_elements_text(p->'support_types');
 project:=nullif(p->>'project_id','')::uuid;
 if project is not null and not exists(select 1 from public.ap_projects where id=project and association_id=a) then raise exception 'Proiect invalid'; end if;
 insert into public.ap_sponsorships(association_id,organization,sector,support_types,contact_name,contact_email,contact_phone,introduction,summary,project_id)
 values(a,trim(p->>'organization'),trim(coalesce(p->>'sector','')),types,trim(coalesce(p->>'contact_name','')),trim(coalesce(p->>'contact_email','')),trim(coalesce(p->>'contact_phone','')),trim(coalesce(p->>'introduction','')),trim(coalesce(p->>'summary','')),project) returning id into result;
 return result;
end $$;
create function public.ap_manage_sponsorship(a uuid,i uuid,v integer,p jsonb) returns void language plpgsql security definer set search_path='' as $$
declare old public.ap_sponsorships; responsible uuid;
begin
 if not public.ap_staff(a) then raise exception 'Doar echipa de coordonare poate gestiona discuțiile'; end if;
 if jsonb_typeof(p) is distinct from 'object' or (p-array['stage','responsible_id','next_step','next_contact','notes','estimated_amount','confirmed_amount','received_amount'])<>'{}'::jsonb then raise exception 'Actualizare invalidă'; end if;
 select * into old from public.ap_sponsorships where id=i and association_id=a for update;
 if old.id is null or old.revision is distinct from v then raise exception 'Oportunitatea a fost modificată între timp. Actualizează lista.'; end if;
 responsible:=nullif(p->>'responsible_id','')::uuid;
 if responsible is not null and not exists(select 1 from public.ap_memberships where association_id=a and user_id=responsible and status='active' and role in ('administrator','coordonator')) then raise exception 'Responsabilul trebuie să fie un coordonator sau administrator activ'; end if;
 update public.ap_sponsorships set stage=p->>'stage',responsible_id=responsible,next_step=coalesce(p->>'next_step',''),next_contact=nullif(p->>'next_contact','')::date,notes=coalesce(p->>'notes',''),estimated_amount=coalesce(nullif(p->>'estimated_amount',''),'0')::numeric,confirmed_amount=coalesce(nullif(p->>'confirmed_amount',''),'0')::numeric,received_amount=coalesce(nullif(p->>'received_amount',''),'0')::numeric,revision=revision+1,updated_at=clock_timestamp() where id=i;
end $$;
create table public.ap_sponsorship_files(id uuid primary key default gen_random_uuid(),lead_id uuid not null references public.ap_sponsorships, file_path text unique not null,file_name text not null check(length(file_name) between 1 and 255),file_size bigint not null check(file_size between 1 and 26214400),mime_type text not null,created_at timestamptz not null default now());
alter table public.ap_sponsorship_files enable row level security;
create policy sponsorship_files_staff on public.ap_sponsorship_files for select to authenticated using(exists(select 1 from public.ap_sponsorships s where s.id=lead_id and public.ap_staff(s.association_id)));
grant select on public.ap_sponsorship_files to authenticated;
create function public.ap_sponsorship_file_access(p text) returns boolean language sql stable security definer set search_path='' as $$
 select case when p ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}$' and split_part(p,'/',1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' and split_part(p,'/',2) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' and split_part(p,'/',3) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 then exists(select 1 from public.ap_sponsorships where id=split_part(p,'/',2)::uuid and association_id=split_part(p,'/',1)::uuid and public.ap_staff(association_id)) else false end
$$;
create function public.ap_sponsorship_file_linked(p text) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.ap_sponsorship_files where file_path=p)$$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('ap-sponsorships','ap-sponsorships',false,26214400,null);
create policy sponsorship_upload on storage.objects for insert to authenticated with check(bucket_id='ap-sponsorships' and public.ap_sponsorship_file_access(name));
create policy sponsorship_download on storage.objects for select to authenticated using(bucket_id='ap-sponsorships' and public.ap_sponsorship_file_access(name));
create policy sponsorship_cleanup on storage.objects for delete to authenticated using(bucket_id='ap-sponsorships' and owner_id=auth.uid()::text and not public.ap_sponsorship_file_linked(name));
create function public.ap_attach_sponsorship_file(a uuid,i uuid,p text,f text) returns void language plpgsql security definer set search_path='' as $$
declare obj storage.objects;
begin
 if not public.ap_staff(a) or not public.ap_sponsorship_file_access(p) or split_part(p,'/',1)<>a::text or split_part(p,'/',2)<>i::text then raise exception 'Acces indisponibil'; end if;
 select * into obj from storage.objects where bucket_id='ap-sponsorships' and name=p;
 if not found then raise exception 'Fișierul nu a fost încărcat'; end if;
 insert into public.ap_sponsorship_files(lead_id,file_path,file_name,file_size,mime_type) values(i,p,f,(obj.metadata->>'size')::bigint,coalesce(obj.metadata->>'mimetype','application/octet-stream'));
end $$;
create function public.ap_sponsorship_stats(a uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not public.ap_active(a) then raise exception 'Acces indisponibil'; end if;
 return (select jsonb_build_object('active',count(*) filter(where stage not in ('inchis','confirmat')),'confirmed',count(*) filter(where stage='confirmat'),'confirmed_amount',coalesce(sum(confirmed_amount),0),'received_amount',coalesce(sum(received_amount),0)) from public.ap_sponsorships where association_id=a);
end $$;
create function public.ap_sponsorship_list(a uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare staff boolean;
begin
 if not public.ap_active(a) then raise exception 'Acces indisponibil'; end if;
 staff:=public.ap_staff(a);
 return jsonb_build_object('leads',coalesce((select jsonb_agg(case when staff then to_jsonb(s)||jsonb_build_object('files',coalesce((select jsonb_agg(to_jsonb(f) order by f.created_at) from public.ap_sponsorship_files f where f.lead_id=s.id),'[]'::jsonb)) else jsonb_build_object('id',s.id,'organization',s.organization,'sector',s.sector,'support_types',s.support_types,'contact_name',s.contact_name,'contact_email',s.contact_email,'contact_phone',s.contact_phone,'introduction',s.introduction,'summary',s.summary,'project_id',s.project_id,'stage',s.stage,'created_at',s.created_at) end order by s.created_at desc) from public.ap_sponsorships s where s.association_id=a and (staff or s.created_by=auth.uid())),'[]'::jsonb),'assignees',case when staff then coalesce((select jsonb_agg(jsonb_build_object('id',user_id,'name',display_name) order by display_name) from public.ap_memberships where association_id=a and status='active' and role in ('administrator','coordonator')),'[]'::jsonb) else '[]'::jsonb end,'stats',public.ap_sponsorship_stats(a));
end $$;
revoke all on function public.ap_propose_sponsorship(uuid,jsonb),public.ap_manage_sponsorship(uuid,uuid,integer,jsonb),public.ap_sponsorship_file_access(text),public.ap_sponsorship_file_linked(text),public.ap_attach_sponsorship_file(uuid,uuid,text,text),public.ap_sponsorship_stats(uuid),public.ap_sponsorship_list(uuid) from public,anon;
grant execute on function public.ap_propose_sponsorship(uuid,jsonb),public.ap_manage_sponsorship(uuid,uuid,integer,jsonb),public.ap_sponsorship_file_access(text),public.ap_sponsorship_file_linked(text),public.ap_attach_sponsorship_file(uuid,uuid,text,text),public.ap_sponsorship_stats(uuid),public.ap_sponsorship_list(uuid) to authenticated;
commit;
