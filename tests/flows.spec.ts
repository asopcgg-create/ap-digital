import {test,expect,type Page} from '@playwright/test';
async function navigate(page:Page,label:string){if(await page.getByRole('button',{name:'Deschide meniul'}).isVisible())await page.getByRole('button',{name:'Deschide meniul'}).click();await page.getByRole('navigation').getByRole('button',{name:label,exact:true}).click()}
test('participare, propuneri, voluntariat, voturi, documente și profil persistente',async({page})=>{
 await page.goto('/');await expect(page.getByRole('heading',{level:1})).toContainText('Împreună');
 await navigate(page,'Ședințe');await page.getByText('Vezi ordinea de zi').first().click();await expect(page.getByText('Prioritățile comunității pentru acest an')).toBeVisible();await page.getByRole('button',{name:'Confirm participarea'}).first().click();await page.reload();await expect(page.getByRole('button',{name:'Participarea confirmată'})).toHaveCount(1);
 await navigate(page,'Proiecte');await page.getByRole('button',{name:'Propune un proiect'}).click();await page.getByLabel('Titlul proiectului').fill('Atelier demo de robotică');await page.getByLabel('Descriere',{exact:true}).fill('Construim împreună roboți din materiale reciclate.');await page.getByRole('button',{name:'Salvează propunerea'}).click();const card=page.getByRole('article').filter({hasText:'Atelier demo de robotică'});await card.getByRole('button',{name:'Mă implic'}).click();await expect(card.getByRole('button',{name:'Înscris'})).toBeVisible();await page.reload();await expect(page.getByText('Atelier demo de robotică',{exact:true})).toBeVisible();
 await navigate(page,'Consultări');const poll=page.getByRole('article').first();await poll.getByRole('radio',{name:'Colțul de lectură',exact:false}).click();await expect(poll.getByRole('radio').first()).toBeChecked();await poll.getByRole('radio',{name:'Curtea verde',exact:false}).click();await expect(poll.getByText('55 voturi în total',{exact:false})).toBeVisible();await page.reload();await expect(page.getByRole('radio',{name:/Curtea verde/})).toBeChecked();
 await navigate(page,'Documente');await page.getByLabel('Caută documente').fill('inexistent');await expect(page.getByText('Niciun document găsit.',{exact:false})).toBeVisible();await page.getByLabel('Caută documente').fill('Statut');await page.getByRole('button',{name:/Statutul asociației/}).click();await expect(page.getByRole('dialog')).toBeVisible();const download=page.waitForEvent('download');await page.getByRole('button',{name:'Descarcă modelul TXT'}).click();expect((await download).suggestedFilename()).toBe('statut-demo.txt');await page.getByRole('button',{name:'Închide documentul'}).click();
 await navigate(page,'Profil');await page.getByLabel('Nume afișat').fill('Explorator demo');await page.getByLabel('Simulează un rol').selectOption('coordonator');await page.reload();await expect(page.getByLabel('Nume afișat')).toHaveValue('Explorator demo');await navigate(page,'Proiecte');await expect(page.getByRole('slider').first()).toBeVisible();await page.getByRole('slider').first().fill('40');await page.reload();await expect(page.getByRole('slider').first()).toHaveValue('40');
 await navigate(page,'Profil');page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'Resetează datele demo'}).click();await expect(page.getByLabel('Nume afișat')).toHaveValue('Părinte demo');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();
});
test('PWA offline și recuperare după date corupte',async({page,context})=>{await page.goto('/');await page.evaluate(async()=>{await navigator.serviceWorker.ready});await page.reload();await expect.poll(()=>page.evaluate(()=>!!navigator.serviceWorker.controller)).toBeTruthy();await context.setOffline(true);await page.reload();await expect(page.getByRole('heading',{level:1})).toBeVisible();await navigate(page,'Documente');await expect(page.getByRole('button',{name:/Statutul asociației/})).toBeVisible();await context.setOffline(false);await page.evaluate(()=>localStorage.setItem('ap-digital:v1','{broken'));await page.reload();await navigate(page,'Profil');await expect(page.getByLabel('Nume afișat')).toHaveValue('Părinte demo')});
test('totaluri și voturi pe opțiuni: adăugare, schimbare, retragere și sincronizare între file',async({page,context})=>{
 await page.goto('/');await navigate(page,'Consultări');const poll=page.getByRole('article').first();
 await expect(poll.getByRole('status')).toHaveText('54 voturi în total');
 await expect(poll.getByText('24 voturi · 44%')).toBeVisible();
 const second=await context.newPage();await second.goto('/#Consultări');
 await poll.getByRole('radio',{name:/Colțul de lectură/}).check();
 await expect(poll.getByRole('status')).toHaveText('55 voturi în total');
 await expect(poll.getByText('25 voturi · 45%')).toBeVisible();
 await expect(second.getByRole('article').first().getByRole('status')).toHaveText('55 voturi în total');
 await poll.getByRole('radio',{name:/Curtea verde/}).check();
 await expect(poll.getByText('24 voturi · 44%')).toBeVisible();
 await expect(poll.getByText('19 voturi · 35%')).toBeVisible();
 await expect(poll.getByRole('status')).toHaveText('55 voturi în total');
 await poll.getByRole('radio',{name:/Curtea verde/}).check();
 await expect(poll.getByRole('status')).toHaveText('55 voturi în total');
 await page.reload();await expect(poll.getByRole('radio',{name:/Curtea verde/})).toBeChecked();
 await second.getByRole('article').first().getByRole('button',{name:'Retrage votul meu'}).click();
 await expect(poll.getByRole('status')).toHaveText('54 voturi în total');
 await expect(poll.getByRole('radio',{checked:true})).toHaveCount(0);
 await expect(poll.getByText('18 voturi · 33%')).toBeVisible();
 await page.reload();await expect(poll.getByRole('status')).toHaveText('54 voturi în total');
 await expect(page.getByRole('img',{name:/Sigla/}).filter({visible:true})).toHaveCount(1);
 await second.close();
});
test('anulare participare și voluntariat; date de vot invalide; dialog accesibil',async({page})=>{
 await page.goto('/');await page.evaluate(()=>{localStorage.setItem('ap-digital:v1',JSON.stringify({version:1,profile:{name:'Demo',role:'membru',notifications:true},projects:[],attendance:[],volunteering:[],votes:{prioritati:99,ateliere:-1}}))});await page.reload();await navigate(page,'Consultări');await expect(page.getByRole('article').first().getByRole('status')).toHaveText('54 voturi în total');
 await navigate(page,'Profil');page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'Resetează datele demo'}).click();
 await navigate(page,'Ședințe');await page.getByRole('button',{name:'Confirm participarea'}).first().click();await page.getByRole('button',{name:'Participarea confirmată'}).click();await page.reload();await expect(page.getByRole('button',{name:'Participarea confirmată'})).toHaveCount(0);
 await navigate(page,'Proiecte');await page.getByRole('button',{name:'Mă implic'}).first().click();await page.getByRole('button',{name:'Înscris',exact:true}).click();await page.reload();await expect(page.getByRole('button',{name:'Înscris',exact:true})).toHaveCount(0);await expect(page.getByRole('slider')).toHaveCount(0);
 await navigate(page,'Documente');await page.getByLabel('Categorie documente').selectOption('Ghiduri');await expect(page.getByRole('button',{name:/Ghidul voluntarului/})).toBeVisible();await expect(page.getByRole('button',{name:/Statutul asociației/})).toHaveCount(0);await page.getByRole('button',{name:/Ghidul voluntarului/}).click();const close=page.getByRole('button',{name:'Închide documentul'});await expect(close).toBeFocused();await page.keyboard.press('Shift+Tab');await expect(page.getByRole('button',{name:'Descarcă modelul TXT'})).toBeFocused();await page.keyboard.press('Tab');await expect(close).toBeFocused();await page.keyboard.press('Escape');await expect(page.getByRole('dialog')).toHaveCount(0);
});
