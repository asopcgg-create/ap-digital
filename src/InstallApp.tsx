import {useState, useSyncExternalStore} from 'react';
import {Download, Smartphone, X} from 'lucide-react';

type InstallEvent = Event & {prompt:()=>Promise<void>; userChoice:Promise<{outcome:'accepted'|'dismissed'}>};
let pending:InstallEvent|null=null;
const standalone=window.matchMedia('(display-mode: standalone)');
const isStandalone=()=>standalone.matches || Boolean((navigator as Navigator & {standalone?:boolean}).standalone);
let installed=isStandalone();
const listeners=new Set<()=>void>();
const notify=()=>listeners.forEach(listener=>listener());
// Capture before the home page mounts, including while the user is signing in.
window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();pending=event as InstallEvent;notify()});
window.addEventListener('appinstalled',()=>{installed=true;pending=null;notify()});
standalone.addEventListener('change',()=>{installed=isStandalone();notify()});
const subscribe=(listener:()=>void)=>{listeners.add(listener);return()=>{listeners.delete(listener)}};
const snapshot=()=>installed?'installed':pending?'ready':'manual';

export function InstallApp({inline=false}:{inline?:boolean}){
 const state=useSyncExternalStore(subscribe,snapshot);
 const [help,setHelp]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState('');
 const [dismissed,setDismissed]=useState(()=>{try{return sessionStorage.getItem('ap-digital:install-dismissed')==='1'}catch{return false}});
 function dismiss(){setDismissed(true);try{sessionStorage.setItem('ap-digital:install-dismissed','1')}catch{}}
 const ios=/iPad|iPhone|iPod/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
 const mobile=ios||/Android|Mobile|Tablet|Silk/i.test(navigator.userAgent)||Boolean((navigator as Navigator & {userAgentData?:{mobile:boolean}}).userAgentData?.mobile);
 if(state==='installed'||(!inline&&(dismissed||!mobile)))return null;
 async function install(){
  if(!pending){setHelp(value=>!value);return}
  const event=pending;pending=null;notify();setBusy(true);setError('');
  try{await event.prompt();const choice=await event.userChoice;if(choice.outcome==='accepted'){installed=true;notify()}else setHelp(true)}
  catch{setError('Invitația de instalare nu s-a deschis. Urmează pașii de mai jos.');setHelp(true)}
  finally{setBusy(false)}
 }
 return <section className={inline?'install-app install-inline':'install-app card'} aria-label="Instalarea aplicației">{!inline&&<button className="install-close icon-button" aria-label="Închide invitația de instalare" onClick={dismiss}><X size={20}/></button>}<Smartphone size={25} aria-hidden="true"/><div className="install-copy"><h2>AP Digital, la o atingere</h2><p>{inline?'Instalează AP Digital pentru acces rapid de pe acest dispozitiv.':'Adaugă AP Digital pe ecranul telefonului pentru acces rapid.'}</p><button className="primary" disabled={busy} onClick={()=>void install()} aria-expanded={help} aria-controls="install-instructions"><Download size={18} aria-hidden="true"/>{busy?'Se deschide instalarea…':'Instalează'}</button>{help&&<div id="install-instructions" className="install-instructions">{ios?<><h3>Pe iPhone sau iPad</h3><ol><li>Deschide platforma în Safari.</li><li>Apasă Partajare (pătratul cu săgeata în sus).</li><li>Alege „Adaugă pe ecranul principal”, apoi „Adaugă”.</li></ol></>:<><h3>Din meniul browserului</h3><p>Caută „Instalează aplicația” sau „Adaugă pe ecranul principal” în meniul browserului ori pictograma de instalare din bara de adrese.</p><p>Dacă opțiunea lipsește, încearcă în Chrome sau Edge, direct în browser, în afara aplicațiilor de mesagerie. Este posibil ca aplicația să fie deja instalată.</p></>}<p>Instalarea nu înlocuiește conexiunea la internet pentru voturi, cont și datele comunității.</p><button className="text-button" onClick={()=>setHelp(false)}>Închide instrucțiunile</button></div>}{error&&<p role="status">{error}</p>}</div></section>
}
