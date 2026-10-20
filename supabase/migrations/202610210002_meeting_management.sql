begin;
alter table public.ap_meetings add column revision integer not null default 1,add column cancelled boolean not null default false,add column cancellation_reason text not null default '' check(length(cancellation_reason)<=500),add column cancelled_at timestamptz;
create function public.ap_edit_meeting(a uuid,i uuid,v integer,t text,s timestamptz,p text,g text[]) returns void language plpgsql security definer set search_path='' as $$
declare m public.ap_meetings;
begin
 if not public.ap_staff(a) then raise exception 'Doar administratorii și coordonatorii pot edita întâlniri'; end if;
 select * into m from public.ap_meetings where id=i and association_id=a for update;
 if m.id is null or m.revision is distinct from v then raise exception 'Întâlnirea a fost modificată între timp. Actualizează lista.'; end if;
 if m.cancelled then raise exception 'Întâlnirea este anulată'; end if;
 if s is null or not isfinite(s) or length(trim(t)) not between 1 and 120 or length(trim(p)) not between 1 and 300 or cardinality(g)>100 or length(array_to_string(g,E'\n'))>3000 then raise exception 'Verifică datele întâlnirii'; end if;
 update public.ap_meetings set title=trim(t),starts_at=s,place=trim(p),agenda=coalesce(g,'{}'),revision=revision+1 where id=i;
end $$;
create function public.ap_cancel_meeting(a uuid,i uuid,v integer,r text) returns void language plpgsql security definer set search_path='' as $$
declare m public.ap_meetings;
begin
 if not public.ap_staff(a) then raise exception 'Doar administratorii și coordonatorii pot anula întâlniri'; end if;
 select * into m from public.ap_meetings where id=i and association_id=a for update;
 if m.id is null or m.revision is distinct from v or m.cancelled then raise exception 'Întâlnirea a fost modificată între timp. Actualizează lista.'; end if;
 if length(trim(coalesce(r,''))) not between 1 and 500 then raise exception 'Adaugă motivul anulării'; end if;
 update public.ap_meetings set cancelled=true,cancellation_reason=trim(r),cancelled_at=clock_timestamp(),revision=revision+1 where id=i;
end $$;
create function public.ap_meeting_participants(a uuid,i uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not public.ap_staff(a) or not exists(select 1 from public.ap_meetings where id=i and association_id=a) then raise exception 'Lista este disponibilă doar administratorilor și coordonatorilor asociației'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('name',coalesce(m.display_name,'Cont indisponibil'),'status',coalesce(m.status,'indisponibil')) order by m.display_name,t.user_id) from public.ap_attendance t left join public.ap_memberships m on m.user_id=t.user_id and m.association_id=a where t.meeting_id=i),'[]'::jsonb);
end $$;
-- Serialize attendance writes and cancellation so a cancelled event cannot accept new confirmations.
create function public.ap_attendance_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare m public.ap_meetings;
begin
 select * into m from public.ap_meetings where id=case when tg_op='DELETE' then old.meeting_id else new.meeting_id end for update;
 if m.id is null or m.cancelled or (case when tg_op='DELETE' then old.user_id else new.user_id end)<>auth.uid() or not public.ap_active(m.association_id) then raise exception 'Confirmarea nu este disponibilă pentru această întâlnire'; end if;
 if tg_op='DELETE' then return old; else return new; end if;
end $$;
create trigger ap_attendance_guard before insert or delete on public.ap_attendance for each row execute function public.ap_attendance_guard();
revoke all on function public.ap_edit_meeting(uuid,uuid,integer,text,timestamptz,text,text[]),public.ap_cancel_meeting(uuid,uuid,integer,text),public.ap_meeting_participants(uuid,uuid),public.ap_attendance_guard() from public,anon;
grant execute on function public.ap_edit_meeting(uuid,uuid,integer,text,timestamptz,text,text[]),public.ap_cancel_meeting(uuid,uuid,integer,text),public.ap_meeting_participants(uuid,uuid) to authenticated;
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
 'documents',coalesce((select jsonb_agg(to_jsonb(d) order by d.created_at desc) from public.ap_documents d where d.association_id=a),'[]'::jsonb)
 ) into result;
 return result;
end $$;

commit;
