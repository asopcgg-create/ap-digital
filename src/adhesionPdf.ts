import {PDFDocument,rgb,type PDFFont} from 'pdf-lib';
import fontkit from '@pdf-lib/fontkit';
import type {Application} from './adhesionModel';
export async function buildApplicationPdf(app:Application,fontBytes:Uint8Array,logoBytes?:Uint8Array){
 const pdf=await PDFDocument.create();pdf.registerFontkit(fontkit);const font=await pdf.embedFont(fontBytes,{subset:true});
 const green=rgb(.12,.27,.23),gray=rgb(.38,.43,.40);let page=pdf.addPage([595.28,841.89]),y=788;const left=48,width=499;
 const draw=(text:string,size=11,color=green)=>{page.drawText(text,{x:left,y,size,font,color});y-=size*1.6};
 function wrap(text:string,size=11,available=width){const result:string[]=[];for(const paragraph of text.split('\n')){let line='';for(const token of paragraph.split(/\s+/)){const pieces:string[]=[];let part='';for(const char of token){if(font.widthOfTextAtSize(part+char,size)>available&&part){pieces.push(part);part=char}else part+=char}if(part)pieces.push(part);for(const word of pieces){if(font.widthOfTextAtSize((line?line+' ':'')+word,size)>available&&line){result.push(line);line=word}else line+=(line?' ':'')+word}}result.push(line)}return result}
 function paragraph(text:string,size=11){for(const line of wrap(text,size)){if(y<85){page=pdf.addPage([595.28,841.89]);y=785}draw(line,size)}y-=8}
 if(logoBytes){const logo=await pdf.embedPng(logoBytes);page.drawImage(logo,{x:48,y:746,width:46,height:46});}
 page.drawText('ASOCIAȚIA DE PĂRINȚI A',{x:108,y:780,size:12,font,color:green});page.drawText('COLEGIULUI GERMAN GOETHE',{x:108,y:761,size:12,font,color:green});y=724;
 paragraph('CERERE DE ADEZIUNE',21);paragraph('Referință: '+app.reference,10);
 paragraph('Subsemnatul/Subsemnata '+app.full_name+', solicit înscrierea în Asociația de Părinți a Colegiului German Goethe.');
 paragraph('Declar că sunt părinte/reprezentant legal al copilului/copiilor înscriși în unitate, menționați mai jos:');
 app.children.forEach((c,i)=>paragraph(`${i+1}. ${c.full_name} - ${c.grade}${c.class_label?' / '+c.class_label:''}`,11));
 paragraph('E-mail pentru cont și corespondență: '+app.email);if(app.phone)paragraph('Telefon: '+app.phone);
 paragraph('Solicit verificarea și aprobarea cererii potrivit statutului asociației. Crearea contului și transmiterea cererii nu acordă automat calitatea de membru sau drepturi statutare.');
 paragraph('Am luat la cunoștință informarea privind prelucrarea datelor prezentată în platformă (versiunea '+app.privacy_version+'). Această mențiune nu reprezintă un consimțământ general pentru alte utilizări ale datelor.',10);
 if(y<200){page=pdf.addPage([595.28,841.89]);y=785}
 y-=16;draw('Data semnării: ____________________',11);y-=28;draw('Semnătura olografă: ______________________________',11);y-=18;
 paragraph('Semnează cererea și trimite scanul sau o fotografie lizibilă la asopcgg@gmail.com. Include referința '+app.reference+' în subiectul e-mailului. Apoi confirmă trimiterea în AP Digital.',10);
 const pages=pdf.getPages();pages.forEach((p,i)=>{p.drawLine({start:{x:48,y:49},end:{x:547,y:49},thickness:.5,color:rgb(.8,.84,.8)});p.drawText(`APCGG Digital | ${app.reference} | ${i+1}/${pages.length}`,{x:48,y:32,font,size:8,color:gray})});
 pdf.setTitle('Cerere de adeziune '+app.reference);pdf.setAuthor('APCGG Digital');return pdf.save();
}
export async function downloadApplication(app:Application){
 const [fontResponse,logoResponse]=await Promise.all([fetch('/fonts/NotoSans-Regular.ttf'),fetch('/sigla-asociatie.png')]);if(!fontResponse.ok||!logoResponse.ok)throw new Error('PDF-ul nu a putut fi pregătit. Verifică conexiunea și reîncearcă.');
 const bytes=await buildApplicationPdf(app,new Uint8Array(await fontResponse.arrayBuffer()),new Uint8Array(await logoResponse.arrayBuffer()));
 const blob=new Blob([new Uint8Array(bytes)],{type:'application/pdf'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='Cerere-adeziune-'+app.reference+'.pdf';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
