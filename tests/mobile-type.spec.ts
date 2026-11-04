import {test,expect} from '@playwright/test';
for(const width of [375,390,768])test(`readable mobile text and contained layouts at ${width}px`,async({page})=>{
 await page.setViewportSize({width,height:844});
 for(const module of ['Acasă','Ședințe','Proiecte','Consultări','Documente','Comunitatea în cifre','Profil']){
  await page.goto('/?mode=demo#'+encodeURIComponent(module));
  await expect(page.getByRole('heading',{level:1})).toBeVisible();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),module+' horizontal overflow').toBe(true);
 }
 await page.goto('/?mode=demo#'+encodeURIComponent('Comunitatea în cifre'));
 expect(await page.locator('.metrics-notes p').first().evaluate(e=>parseFloat(getComputedStyle(e).fontSize))).toBeGreaterThanOrEqual(16);
 expect(await page.locator('.project-data td').first().evaluate(e=>parseFloat(getComputedStyle(e).fontSize))).toBeGreaterThanOrEqual(16);
 expect(await page.locator('select').first().evaluate(e=>parseFloat(getComputedStyle(e).fontSize))).toBeGreaterThanOrEqual(16);
});
test('desktop retains compact typography',async({page})=>{
 await page.setViewportSize({width:1440,height:1000});await page.goto('/?mode=demo#'+encodeURIComponent('Comunitatea în cifre'));
 expect(await page.locator('.metrics-notes p').first().evaluate(e=>getComputedStyle(e).fontSize)).toBe('11px');
});
