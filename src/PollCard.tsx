import {Check, Vote} from 'lucide-react';
import {polls} from './data';
type Props = {poll:typeof polls[number];choice:number|undefined;onVote:(choice:number|undefined)=>void};
export function PollCard({poll:p,choice,onVote}:Props){
 const voted=choice!==undefined&&Number.isInteger(choice)&&choice>=0&&choice<p.options.length;
 const counts=p.counts.map((n,i)=>n+(voted&&choice===i?1:0));
 const total=counts.reduce((a,b)=>a+b,0);
 return <article className="card poll"><span className="pill">Consultare deschisă · demo</span><h2 id={'poll-'+p.id}>{p.title}</h2><p>{p.description}</p>
 <fieldset className="poll-options"><legend className="sr-only">{p.title}</legend>{p.options.map((o,i)=><label className={choice===i?'poll-option selected':'poll-option'} key={o}>
 <span className="option-name"><input type="radio" name={'vote-'+p.id} checked={voted&&choice===i} onChange={()=>onVote(i)}/>{o}{choice===i&&<Check size={17}/>}</span>
 <span className="vote-count">{counts[i]} voturi · {Math.round(counts[i]/total*100)}%</span><progress value={counts[i]} max={total} aria-label={'Rezultat '+o}/>
 </label>)}</fieldset>
 <div className="poll-total" role="status" aria-live="polite" aria-atomic="true"><Vote size={18}/><strong>{total} voturi în total</strong></div>
 <p className="vote-explanation">{p.counts.reduce((a,b)=>a+b,0)} voturi demonstrative + {voted?'1 vot al tău':'0 voturi ale tale'}. {voted?'Schimbarea opțiunii mută votul, fără a crește totalul.':'Alege o opțiune pentru a adăuga votul tău.'}</p>
 {voted&&<button className="outline" onClick={()=>onVote(undefined)}>Retrage votul meu</button>}
 </article>
}
