import {onlineDefault} from './appConfig';
import {createClient} from '@supabase/supabase-js';
const env=import.meta.env;
const url=env.VITE_SUPABASE_URL?.trim();
const key=(env.VITE_SUPABASE_PUBLISHABLE_KEY||env.VITE_SUPABASE_ANON_KEY)?.trim();
// Never accept server credentials in a client bundle.
function publicKey(value:string){if(value.startsWith('sb_secret_'))return false;try{const payload=JSON.parse(atob(value.split('.')[1]));return payload.role==='anon'}catch{return value.startsWith('sb_publishable_')}}
const mode=new URLSearchParams(location.search).get('mode');
const demoMode=mode==='demo'||!onlineDefault&&mode!=='online';
export const supabase=!demoMode&&url&&key&&publicKey(key)?createClient(url,key,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,flowType:'pkce'}}):null;
export const associationId=env.VITE_ASSOCIATION_ID||'8e1f2fc1-2775-49cd-91b1-c06630eec432';

