import {test,expect} from '@playwright/test';
test.beforeEach(async({page},testInfo)=>{if(testInfo.title.startsWith('iPhone')||testInfo.title.startsWith('desktop has'))return;await page.addInitScript(()=>Object.defineProperty(navigator,'userAgent',{configurable:true,value:'Mozilla/5.0 (Linux; Android 14) Mobile'}))});
test('manual instructions on home',async({page})=>{
 await page.goto('/?mode=demo');await page.getByRole('button',{name:'Instalează',exact:true}).click();
 await expect(page.getByRole('heading',{name:'Din meniul browserului'})).toBeVisible();
 await page.getByRole('button',{name:'Închide instrucțiunile'}).click();
 await expect(page.getByRole('heading',{name:'Din meniul browserului'})).toHaveCount(0);
});
test('iPhone guidance',async({page})=>{
 await page.addInitScript(()=>Object.defineProperty(navigator,'userAgent',{configurable:true,value:'iPhone'}));
 await page.goto('/?mode=demo');await page.getByRole('button',{name:'Instalează',exact:true}).click();
 await expect(page.getByText('Deschide platforma în Safari.')).toBeVisible();
});
test('native prompt dismissal, retry and installation',async({page})=>{
 await page.goto('/?mode=demo');
 await page.evaluate(()=>{const event=new Event('beforeinstallprompt',{cancelable:true});Object.assign(event,{prompt:async()=>{},userChoice:Promise.resolve({outcome:'dismissed'})});window.dispatchEvent(event)});
 await page.getByRole('button',{name:'Instalează',exact:true}).click();
 await expect(page.getByRole('heading',{name:'Din meniul browserului'})).toBeVisible();
 await page.evaluate(()=>{const event=new Event('beforeinstallprompt',{cancelable:true});Object.assign(event,{prompt:async()=>{},userChoice:Promise.resolve({outcome:'accepted'})});window.dispatchEvent(event)});
 await page.getByRole('button',{name:'Instalează',exact:true}).click();
 await expect(page.getByRole('region',{name:'Instalarea aplicației'})).toHaveCount(0);
});
test('installed app hides the invitation',async({page})=>{
 await page.goto('/?mode=demo');await page.evaluate(()=>window.dispatchEvent(new Event('appinstalled')));
 await expect(page.getByRole('region',{name:'Instalarea aplicației'})).toHaveCount(0);
});

test('close persists across reload and navigation',async({page})=>{
 await page.goto('/?mode=demo');await page.getByRole('button',{name:'Închide invitația de instalare'}).click();
 await expect(page.getByRole('region',{name:'Instalarea aplicației'})).toHaveCount(0);
 await page.reload();await expect(page.getByRole('heading',{level:1})).toBeVisible();
 await expect(page.getByRole('region',{name:'Instalarea aplicației'})).toHaveCount(0);
});

test('desktop has no popup even in a narrow window; profile offers installation',async({page})=>{
 await page.addInitScript(()=>{Object.defineProperty(navigator,'userAgent',{configurable:true,value:'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'});Object.defineProperty(navigator,'userAgentData',{value:{mobile:false}});Object.defineProperty(navigator,'maxTouchPoints',{value:0})});
 await page.goto('/?mode=demo');await expect(page.getByRole('heading',{level:1})).toBeVisible();
 await expect(page.getByRole('region',{name:'Instalarea aplicației'})).toHaveCount(0);
 await page.goto('/?mode=demo#Profil');await expect(page.getByRole('button',{name:'Instalează',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'Instalează',exact:true}).click();await expect(page.getByRole('heading',{name:'Din meniul browserului'})).toBeVisible();
});
test('profile installation is available after dismissing mobile popup',async({page})=>{
 await page.goto('/?mode=demo');await page.getByRole('button',{name:'Închide invitația de instalare'}).click();
 await page.goto('/?mode=demo#Profil');await expect(page.getByRole('button',{name:'Instalează',exact:true})).toBeVisible();
});
