import {test,expect} from '@playwright/test';
test('manual instructions on home',async({page})=>{
 await page.goto('/?mode=demo');await page.getByRole('button',{name:'Instalează AP Digital',exact:true}).click();
 await expect(page.getByRole('heading',{name:'Din meniul browserului'})).toBeVisible();
 await page.getByRole('button',{name:'Închide instrucțiunile'}).click();
 await expect(page.getByRole('heading',{name:'Din meniul browserului'})).toHaveCount(0);
});
test('iPhone guidance',async({page})=>{
 await page.addInitScript(()=>Object.defineProperty(navigator,'userAgent',{value:'iPhone'}));
 await page.goto('/?mode=demo');await page.getByRole('button',{name:'Instalează AP Digital',exact:true}).click();
 await expect(page.getByText('Deschide platforma în Safari.')).toBeVisible();
});
test('native prompt dismissal, retry and installation',async({page})=>{
 await page.goto('/?mode=demo');
 await page.evaluate(()=>{const event=new Event('beforeinstallprompt',{cancelable:true});Object.assign(event,{prompt:async()=>{},userChoice:Promise.resolve({outcome:'dismissed'})});window.dispatchEvent(event)});
 await page.getByRole('button',{name:'Instalează AP Digital',exact:true}).click();
 await expect(page.getByRole('heading',{name:'Din meniul browserului'})).toBeVisible();
 await page.evaluate(()=>{const event=new Event('beforeinstallprompt',{cancelable:true});Object.assign(event,{prompt:async()=>{},userChoice:Promise.resolve({outcome:'accepted'})});window.dispatchEvent(event)});
 await page.getByRole('button',{name:'Instalează AP Digital',exact:true}).click();
 await expect(page.getByRole('region',{name:'Instalarea aplicației'})).toHaveCount(0);
});
test('installed app hides the invitation',async({page})=>{
 await page.goto('/?mode=demo');await page.evaluate(()=>window.dispatchEvent(new Event('appinstalled')));
 await expect(page.getByRole('region',{name:'Instalarea aplicației'})).toHaveCount(0);
});
