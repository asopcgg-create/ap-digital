import {createClient} from 'npm:@supabase/supabase-js@2';
import nodemailer from 'npm:nodemailer@9';
// Only the scheduler's private dispatch key can claim persisted jobs. No request
// body, recipient, subject or HTML supplied by the caller is accepted.
Deno.serve(async (request:Request)=>{
 if(request.method!=='POST')return new Response('Method not allowed',{status:405});
 const token=request.headers.get('x-ap-dispatch');
 if(!token||token.length>150)return new Response('Unauthorized',{status:401});
 const password=Deno.env.get('AP_SMTP_PASSWORD');
 if(!password)return Response.json({error:'SMTP_NOT_CONFIGURED'},{status:503});
 const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:jobs,error}=await db.rpc('ap_claim_mail_jobs',{dispatch_token:token});
 if(error)return new Response('Unauthorized or unavailable',{status:403});
 if(!Array.isArray(jobs)||jobs.length===0)return Response.json({processed:0});
 const transport=nodemailer.createTransport({host:'smtp.gmail.com',port:465,secure:true,auth:{user:'asopcgg@gmail.com',pass:password},connectionTimeout:10000,greetingTimeout:10000,socketTimeout:15000});
 let sent=0;
 try{for(const job of jobs){
  const name=String(job.display_name).replace(/[\r\n]/g,' ').slice(0,100);
  const subject=String(job.kind).startsWith('reconfirm-')?'Reconfirmă situația de membru — AP Digital':job.kind==='inactive'?'Accesul tău în AP Digital a fost închis':job.kind==='request'?'Cerere nouă de înscriere — AP Digital':job.kind==='active'?'Accesul tău în AP Digital a fost activat':'Rezultatul cererii tale — AP Digital';
  const text=String(job.kind).startsWith('reconfirm-')?`Bună, ${name}!\n\nTe rugăm să reconfirmi situația copiilor pentru anul școlar ${String(job.kind).slice(10)}-${Number(String(job.kind).slice(10))+1}. Intră în cont, la Profil → Reconfirmarea anuală. Nu este necesară o nouă adeziune.\nhttps://ap-digital.pages.dev/?mode=online#Profil\n\nDacă un copil a terminat clasa a XII-a și mai ai copii la Goethe, declară situația tuturor copiilor. Lipsa răspunsului nu închide automat accesul.`:job.kind==='inactive'?`Bună, ${name}!\n\nAccesul tău în spațiul comun AP Digital a fost închis după verificarea situației de către asociație. Pentru corecturi sau clarificări, contactează asopcgg@gmail.com. Documentele și istoricul nu sunt șterse automat.\nhttps://ap-digital.pages.dev/?mode=online`:job.kind==='request'?`O cerere nouă a fost trimisă de ${name}.\n\nIntră în Profil → Cereri de înscriere pentru verificare și atribuirea rolului.\nhttps://ap-digital.pages.dev/?mode=online#Profil\n\nCrearea contului și aprobarea înscrierii sunt pași separați.`:job.kind==='active'?`Bună, ${name}!\n\nAccesul tău în spațiul comun AP Digital este activ. Rol în platformă: ${job.assigned_role}.\nhttps://ap-digital.pages.dev/?mode=online\n\nRolul tehnic nu echivalează cu o funcție statutară.`:`Bună, ${name}!\n\nCererea ta de acces în AP Digital nu a fost aprobată. Pentru clarificări, contactează asociația la asopcgg@gmail.com.\nhttps://ap-digital.pages.dev/?mode=online`;
  let delivered=false;
  try{const info=await transport.sendMail({from:'APCGG Digital <asopcgg@gmail.com>',to:job.email,replyTo:'asopcgg@gmail.com',subject,text,messageId:`<${job.id}@ap-digital.pages.dev>`});delivered=info.accepted?.length===1;if(delivered)sent++}catch{/* Never log credentials, addresses, messages or SMTP responses. */}
  const {error:finishError}=await db.rpc('ap_finish_mail_job',{dispatch_token:token,job_id:job.id,lease_id:job.claim_id,delivered});
  if(finishError)return Response.json({error:'QUEUE_UPDATE_FAILED'},{status:500});
 }}finally{transport.close()}
 return Response.json({processed:jobs.length,sent});
});
