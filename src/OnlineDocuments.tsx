import {useState} from 'react';
import {associationId} from './supabase';
import {db,checked,type CloudDocument} from './onlineRepository';
export const MAX_DOCUMENT_BYTES=25*1024*1024;
const bucket='ap-documents';
function saveBlob(blob:Blob,name:string){const url=URL.createObjectURL(new Blob([blob],{type:'application/octet-stream'}));const a=document.createElement('a');a.href=url;a.download=name.replace(/[\x00-\x1f/\\]/g,'_');a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)}
export function OnlineDocuments({documents,staff,onAction}:{documents:CloudDocument[];staff:boolean;onAction:(fn:()=>Promise<void>,success?:string)=>Promise<void>}){
 const[kind,setKind]=useState('file'),[query,setQuery]=useState('');
 const action=(fn:()=>Promise<void>,success?:string)=>{void onAction(fn,success).catch(()=>{})};
 const filtered=documents.filter(d=>`${d.title} ${d.file_name||''}`.toLocaleLowerCase('ro').includes(query.toLocaleLowerCase('ro')));
 return <>{staff&&<form className="card form" onSubmit={e=>{e.preventDefault();const form=e.currentTarget,f=new FormData(form);action(async()=>{
 const title=String(f.get('title')||'').trim(),category=String(f.get('category')),body=String(f.get('body')||'').trim();
 if(kind==='text'){await checked(db().from('ap_documents').insert({association_id:associationId,title,category,body}));}
 else {const file=f.get('file');if(!(file instanceof File)||!file.size)throw new Error('Alege un fișier care nu este gol.');if(file.size>MAX_DOCUMENT_BYTES)throw new Error('Fișierul depășește limita de 25 MB.');
 const path=associationId+'/'+crypto.randomUUID();await checked(db().storage.from(bucket).upload(path,file,{upsert:false,contentType:file.type||'application/octet-stream'}));
 try{await checked(db().from('ap_documents').insert({association_id:associationId,title,category,body,file_path:path,file_name:file.name,file_size:file.size,mime_type:file.type||'application/octet-stream'}));}catch(error){await db().storage.from(bucket).remove([path]);throw error;}}
 form.reset();},'Documentul a fost publicat în spațiul comun.');}}>
 <h2>Publică un document</h2><label>Tip document<select value={kind} onChange={e=>setKind(e.target.value)}><option value="file">Fișier</option><option value="text">Text</option></select></label>
 <label>Titlu document<input name="title" required maxLength={120}/></label><label>Categorie<select name="category"><option>Organizare</option><option>Hotărâri</option><option>Ghiduri</option></select></label>
 {kind==='file'&&<label>Alege fișierul<input type="file" name="file" required/><small>Orice format · maximum 25 MB per fișier.</small></label>}
 <label>{kind==='file'?'Descriere (opțional)':'Conținut'}<textarea name="body" required={kind==='text'} maxLength={50000}/></label><small>Accesibil membrilor aprobați. Publică doar documente destinate comunității.</small><button className="primary">Publică documentul</button></form>}
 <label>Caută documente<input value={query} onChange={e=>setQuery(e.target.value)}/></label><div className="two-grid">{filtered.map(d=><article className="card p-5" key={d.id}><span className="pill">{d.category}</span><h2>{d.title}</h2>{d.file_path?<><p className="document-file-name">{d.file_name}</p><small>{((d.file_size||0)/1024/1024).toLocaleString('ro',{maximumFractionDigits:2})} MB</small>{d.body&&<p className="cloud-document">{d.body}</p>}<button className="outline" onClick={()=>action(async()=>{const{data,error}=await db().storage.from(bucket).download(d.file_path!);if(error)throw error;saveBlob(data,d.file_name||d.title)},'Fișierul este pregătit pentru descărcare.')}>Descarcă fișierul</button></>:<><details><summary>Citește documentul</summary><pre className="cloud-document">{d.body}</pre></details><button className="outline" onClick={()=>saveBlob(new Blob([d.body],{type:'text/plain;charset=utf-8'}),d.title+'.txt')}>Descarcă textul</button></>}</article>)}</div>{!filtered.length&&<p>{documents.length?'Niciun document nu corespunde căutării.':'Nu există încă documente publicate.'}</p>}</>;
}
