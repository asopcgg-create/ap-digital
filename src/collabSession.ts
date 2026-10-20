import * as Y from 'yjs';
export type Draft={id:string;association_id:string;title:string;revision:number;state_b64:string;plain_text:string;updated_at:string;meeting_id:string|null;published_revision?:number|null};
export type DraftTransport={get:()=>Promise<Draft>;save:(revision:number,state:string,text:string)=>Promise<{saved:boolean;draft:Draft}>};
export function encode(bytes:Uint8Array){let result='';for(let i=0;i<bytes.length;i+=8192)result+=String.fromCharCode(...bytes.subarray(i,i+8192));return btoa(result)}
export function decode(value:string){return Uint8Array.from(atob(value),c=>c.charCodeAt(0))}
const remoteOrigin={remote:true};
export class CollabSession{
 doc=new Y.Doc();text=this.doc.getText('content');revision:number;dirty=false;status='Salvat';error='';private generation=0;private timer:ReturnType<typeof setTimeout>|undefined;private poll:ReturnType<typeof setInterval>|undefined;private saving:Promise<void>|null=null;private disposed=false;private listeners=new Set<()=>void>();
 row:Draft;private transport:DraftTransport;
 constructor(row:Draft,transport:DraftTransport){this.row=row;this.transport=transport;this.revision=row.revision;if(row.state_b64)Y.applyUpdate(this.doc,decode(row.state_b64),remoteOrigin);this.doc.on('update',(_update:Uint8Array,origin:unknown)=>{if(origin!==remoteOrigin){this.generation++;this.dirty=true;this.status='Modificări nesalvate';clearTimeout(this.timer);this.timer=setTimeout(()=>{void this.flush().catch(()=>{})},700)}this.notify()});}
 listen(fn:()=>void){this.listeners.add(fn);return()=>{this.listeners.delete(fn)}}
 private notify(){for(const fn of this.listeners)fn()}
 receive(row:Draft){if(this.disposed||row.revision<this.revision)return;if(row.state_b64)Y.applyUpdate(this.doc,decode(row.state_b64),remoteOrigin);this.revision=row.revision;this.row=row;this.notify()}
 start(){this.poll=setInterval(()=>{void this.sync().catch(()=>{});if(this.dirty)void this.flush().catch(()=>{})},3000)}
 async sync(){try{const row=await this.transport.get();this.receive(row);if(!this.dirty){this.error='';this.status='Salvat';this.notify()}}catch(e){this.error=e instanceof Error?e.message:'Conexiune indisponibilă';this.status=this.dirty?'Modificări nesalvate · reîncercăm':'Sincronizare întreruptă';this.notify();throw e}}
 flush():Promise<void>{if(this.saving)return this.saving.then(()=>this.dirty?this.flush():undefined);if(!this.dirty)return Promise.resolve();this.saving=this.persist().finally(()=>{this.saving=null});return this.saving}
 private async persist(){this.status='Se salvează…';this.notify();try{for(let attempt=0;attempt<8&&this.dirty&&!this.disposed;attempt++){const generation=this.generation;const state=Y.encodeStateAsUpdate(this.doc);if(state.length>1048576||this.text.length>100000)throw new Error('Documentul depășește limita editorului. Descarcă o copie și continuă într-o ciornă nouă.');const result=await this.transport.save(this.revision,encode(state),this.text.toString());this.receive(result.draft);if(result.saved&&generation===this.generation)this.dirty=false;}if(this.dirty)throw new Error('Mai multe modificări simultane. Reîncercăm sincronizarea.');this.error='';this.status='Salvat';this.notify()}catch(e){this.error=e instanceof Error?e.message:'Salvarea nu a reușit';this.status='Modificări nesalvate · reîncercăm';this.notify();throw e}}
 dispose(){this.disposed=true;clearTimeout(this.timer);clearInterval(this.poll);this.listeners.clear();this.doc.destroy()}
}
export const agaTemplate=`PROCES-VERBAL AGA — CIORNĂ

Data și ora:
Locul / forma desfășurării:
Președintele ședinței:
Secretarul ședinței:

1. Participanți și verificarea cvorumului
[Se completează potrivit statutului și evidenței reprezentanților cu drept de vot.]

2. Ordinea de zi
1.
2.

3. Dezbateri și propuneri

4. Hotărâri și rezultatele voturilor
[Pentru fiecare: textul hotărârii, pentru / împotrivă / abțineri.]

5. Responsabili și termene

6. Anexe

7. Validare și semnături
[Se completează după verificarea documentului.]
`;
