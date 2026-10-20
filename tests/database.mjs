import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const pg=new PGlite();let passed=0;
const A='8e1f2fc1-2775-49cd-91b1-c06630eec432',B='00000000-0000-4000-8000-000000000099';
const admin='00000000-0000-4000-8000-000000000001',member='00000000-0000-4000-8000-000000000002',other='00000000-0000-4000-8000-000000000003',late='00000000-0000-4000-8000-000000000004',pending='00000000-0000-4000-8000-000000000005';
await pg.exec(`create role anon;create role authenticated;create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;grant usage on schema auth to authenticated;grant execute on function auth.uid() to authenticated;`);
await pg.exec(fs.readFileSync(new URL('../supabase/migrations/202610200001_online.sql',import.meta.url),'utf8'));
await pg.exec(`insert into ap_associations values('${B}','Other');insert into auth.users values('${admin}'),('${member}'),('${other}'),('${late}'),('${pending}');insert into ap_memberships(association_id,user_id,display_name,status,role,approved_at,application_reference) values('${A}','${admin}','Admin','active','administrator','2026-01-01','CER-1'),('${A}','${member}','Member','active','membru','2026-01-01','CER-2'),('${B}','${other}','Other','active','administrator','2026-01-01','CER-3'),('${A}','${late}','Late','active','membru',now()+interval '1 day','CER-4');`);
async function as(user,fn){await pg.exec('begin');try{await pg.query("select set_config('request.jwt.claim.sub',$1,true)",[user||'']);await pg.exec('set local role '+(user?'authenticated':'anon'));const result=await fn();await pg.exec('commit');return result}catch(e){await pg.exec('rollback');throw e}}
async function test(name,fn){await fn();console.log('✓ '+name);passed++}
const denied=fn=>assert.rejects(fn);
const project={title:'Shared project',description:'A community idea',category:'Educație',progress:0,tasks:[],plan:{stage:'Idee'}};
let id,pollId,multiId;
await test('membership cannot self-approve or assign privileged role',async()=>{
 await denied(()=>as(pending,()=>pg.query(`insert into ap_memberships(association_id,user_id,display_name,status,role) values($1,$2,'Pending','active','administrator')`,[A,pending])));
 await as(pending,()=>pg.query(`insert into ap_memberships(association_id,user_id,display_name,application_reference) values($1,$2,'Pending','CER-5')`,[A,pending]));
 await denied(()=>as(pending,()=>pg.query(`update ap_memberships set status='active' where user_id=$1`,[pending])));
 await denied(()=>as(pending,()=>pg.query('select ap_snapshot($1)',[A])));
});
await test('shared projects isolated from other associations and anonymous users',async()=>{
 id=(await as(member,()=>pg.query('insert into ap_projects(association_id,payload) values($1,$2) returning id',[A,project]))).rows[0].id;
 assert.equal((await as(admin,()=>pg.query('select * from ap_projects'))).rows.length,1);
 assert.equal((await as(other,()=>pg.query('select * from ap_projects'))).rows.length,0);
 await denied(()=>as(null,()=>pg.query('select * from ap_projects')));
 await denied(()=>as(other,()=>pg.query('insert into ap_projects(association_id,payload) values($1,$2)',[A,project])));
});
await test('project ownership, identity and stale revisions protected',async()=>{
 assert.equal((await as(late,()=>pg.query('update ap_projects set payload=$1 where id=$2 returning id',[project,id]))).rows.length,0);
 await denied(()=>as(member,()=>pg.query('update ap_projects set owner_id=$1 where id=$2',[admin,id])));
 await as(member,()=>pg.query('update ap_projects set payload=$1 where id=$2 and revision=1',[{...project,title:'Updated'},id]));
 assert.equal((await as(member,()=>pg.query('update ap_projects set payload=$1 where id=$2 and revision=1 returning id',[project,id]))).rows.length,0);
});
await test('support/volunteer uniqueness and no impersonation',async()=>{
 await as(member,()=>pg.query(`insert into ap_interactions(project_id,kind) values($1,'support'),($1,'volunteer')`,[id]));
 await denied(()=>as(member,()=>pg.query(`insert into ap_interactions(project_id,kind) values($1,'support')`,[id])));
 await denied(()=>as(member,()=>pg.query(`insert into ap_interactions(project_id,user_id,kind) values($1,$2,'support')`,[id,admin])));
});
const poll=(multiple=false)=>({title:'Community poll',description:'Choose activity',options:['Reading','Garden'],status:'open',multiple,deadline:'2099-01-01T00:00:00Z',eligibilityRule:'opening',allowSuggestions:true,projectId:'',beneficiaries:[],createdAt:'2026-01-01T00:00:00Z'});
await test('only staff may publish consultations',async()=>{
 await denied(()=>as(member,()=>pg.query('insert into ap_consultations(association_id,payload) values($1,$2)',[A,poll()])));
 pollId=(await as(admin,()=>pg.query('insert into ap_consultations(association_id,payload) values($1,$2) returning id',[A,poll()]))).rows[0].id;
 multiId=(await as(admin,()=>pg.query('insert into ap_consultations(association_id,payload) values($1,$2) returning id',[A,poll(true)]))).rows[0].id;
});
await test('eligibility cutoff, valid options, unique ballots and identity enforced',async()=>{
 await denied(()=>as(late,()=>pg.query('insert into ap_ballots(consultation_id,choices) values($1,$2)',[pollId,[0]])));
 for(const choices of [[0,1],[99],[-1],[],[null]])await denied(()=>as(member,()=>pg.query('insert into ap_ballots(consultation_id,choices) values($1,$2)',[pollId,choices])));
 await denied(()=>as(member,()=>pg.query('insert into ap_ballots(consultation_id,user_id,choices) values($1,$2,$3)',[pollId,admin,[0]])));
 await as(member,()=>pg.query('insert into ap_ballots(consultation_id,choices) values($1,$2)',[pollId,[0]]));
 await denied(()=>as(member,()=>pg.query('insert into ap_ballots(consultation_id,choices) values($1,$2)',[pollId,[1]])));
});
await test('ballot changes/withdrawal; aggregate snapshot does not expose other ballots',async()=>{
 await as(member,()=>pg.query('update ap_ballots set choices=$1 where consultation_id=$2',[[1],pollId]));
 const own=(await as(member,()=>pg.query('select ap_snapshot($1) s',[A]))).rows[0].s;
 const shared=(await as(admin,()=>pg.query('select ap_snapshot($1) s',[A]))).rows[0].s;
 assert.deepEqual(own.consultations.find(p=>p.id===pollId).counts,[0,0]);assert.deepEqual(shared.consultations.find(p=>p.id===pollId).counts,[0,1]);assert.equal(shared.ballots.length,0);assert.equal(own.ballots.length,1);
 await as(member,()=>pg.query('delete from ap_ballots where consultation_id=$1',[pollId]));
 assert.equal((await as(admin,()=>pg.query('select ap_snapshot($1) s',[A]))).rows[0].s.consultations.find(p=>p.id===pollId).responses,0);
});
await test('multiple choices are counted as one response',async()=>{
 await as(member,()=>pg.query('insert into ap_ballots(consultation_id,choices) values($1,$2)',[multiId,[0,1]]));
 const s=(await as(admin,()=>pg.query('select ap_snapshot($1) s',[A]))).rows[0].s.consultations.find(p=>p.id===multiId);assert.equal(s.responses,1);assert.deepEqual(s.counts,[1,1]);
});
await test('fixed question and options; append only through authorized moderation',async()=>{
 await denied(()=>as(admin,()=>pg.query(`update ap_consultations set payload=jsonb_set(payload,'{title}','"Changed"') where id=$1`,[pollId])));
 await denied(()=>as(admin,()=>pg.query(`update ap_consultations set payload=jsonb_set(payload,'{options}','["Reading","Garden","Sport"]') where id=$1`,[pollId])));
 const sid=(await as(member,()=>pg.query('insert into ap_suggestions(consultation_id,label) values($1,$2) returning id',[pollId,'Sport']))).rows[0].id;
 await denied(()=>as(member,()=>pg.query('select ap_moderate($1,true)',[sid])));
 await as(admin,()=>pg.query('select ap_moderate($1,true)',[sid]));
 assert.deepEqual((await as(member,()=>pg.query('select payload from ap_consultations where id=$1',[pollId]))).rows[0].payload.options,['Reading','Garden','Sport']);
});
await test('closed polls block voting, withdrawal and reopening',async()=>{
 await as(admin,()=>pg.query(`update ap_consultations set payload=jsonb_set(payload,'{status}','"closed"') where id=$1`,[multiId]));
 await denied(()=>as(member,()=>pg.query('insert into ap_ballots(consultation_id,choices) values($1,$2)',[multiId,[0]])));
 assert.equal((await as(member,()=>pg.query('delete from ap_ballots where consultation_id=$1 returning *',[multiId]))).rows.length,0);
 await denied(()=>as(admin,()=>pg.query(`update ap_consultations set payload=jsonb_set(payload,'{status}','"open"') where id=$1`,[multiId])));
});
await test('approval requires administrator and Council resolution reference',async()=>{
 await denied(()=>as(member,()=>pg.query('select ap_review_member($1,$2,$3,$4,$5)',[A,pending,'active','CD-1','administrator'])));
 await denied(()=>as(admin,()=>pg.query('select ap_review_member($1,$2,$3,$4,$5)',[A,pending,'active','','membru'])));
 await as(admin,()=>pg.query('select ap_review_member($1,$2,$3,$4,$5)',[A,pending,'active','CD-1','membru']));
 assert.equal((await as(pending,()=>pg.query('select status,role from ap_memberships where user_id=$1',[pending]))).rows[0].status,'active');
});
await test('comments cannot be deleted by other members; staff-only documents/meetings',async()=>{
 const idc=(await as(member,()=>pg.query('insert into ap_comments(project_id,body) values($1,$2) returning id',[id,'A good idea']))).rows[0].id;
 assert.equal((await as(late,()=>pg.query('delete from ap_comments where id=$1 returning id',[idc]))).rows.length,0);
 await denied(()=>as(member,()=>pg.query("insert into ap_documents(association_id,title,body) values($1,'Title','Body')",[A])));
 await denied(()=>as(member,()=>pg.query("insert into ap_meetings(association_id,title,starts_at,place) values($1,'Meeting',now(),'Library')",[A])));
});
await test('malformed project data cannot break the shared interface',async()=>{
 for(const payload of [{...project,title:{text:'bad'}},{...project,tasks:'bad'}])await denied(()=>as(member,()=>pg.query('insert into ap_projects(association_id,payload) values($1,$2)',[A,payload])));
});
await test('server enforces deadline even if browser clock differs',async()=>{
 const expiring={...poll(),eligibilityRule:'closing',deadline:new Date(Date.now()+300).toISOString()};
 const exp=(await as(admin,()=>pg.query('insert into ap_consultations(association_id,payload) values($1,$2) returning id',[A,expiring]))).rows[0].id;
 await new Promise(resolve=>setTimeout(resolve,350));
 await denied(()=>as(member,()=>pg.query('insert into ap_ballots(consultation_id,choices) values($1,$2)',[exp,[0]])));
});
console.log(`\n${passed} PostgreSQL integration tests passed.`);await pg.close();
