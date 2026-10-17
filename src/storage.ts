import {initial,type State} from './data';
export const STORAGE_KEY='ap-digital:v1';
export function load():State {try {const raw=JSON.parse(localStorage.getItem(STORAGE_KEY)||'null');if(!raw || raw.version!==1 || !Array.isArray(raw.attendance)||!Array.isArray(raw.volunteering)||!Array.isArray(raw.projects)||!raw.profile||!['membru','coordonator','administrator'].includes(raw.profile.role)||typeof raw.profile.name!=='string'||typeof raw.votes!=='object'||raw.votes===null) return structuredClone(initial);if(!raw.projects.every((p:unknown)=>{const x=p as Record<string,unknown>;return x&&typeof x.id==='string'&&typeof x.title==='string'&&typeof x.description==='string'&&typeof x.category==='string'&&typeof x.progress==='number'&&typeof x.volunteers==='number'}))return structuredClone(initial);return raw;}catch{return structuredClone(initial)}}
// Replace these boundaries with Supabase session + repository adapters in stage 2.
// Demo roles are presentation controls only; enforce real permissions with server-side RLS.
export interface AuthAdapter { getSession():Promise<{userId:string;role:State['profile']['role']}|null>; signOut():Promise<void> }
export const demoAuth:AuthAdapter={async getSession(){return {userId:'demo-local',role:load().profile.role}},async signOut(){}};
export const canCoordinate=(role:State['profile']['role'])=>role==='administrator'||role==='coordonator';
