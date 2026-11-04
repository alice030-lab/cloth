import {chromium} from 'playwright';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true,args:['--no-sandbox']});
const page=await browser.newPage({viewport:{width:390,height:844}});
try{
 await page.goto(process.env.APP_URL??'http://127.0.0.1:8083/');
 await page.locator('flt-semantics-placeholder,flt-semantics').first().waitFor({state:'attached'});
 const placeholder=page.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.evaluate(e=>e.click());
 await page.getByRole('button',{name:'先試玩',exact:true}).press('Enter');
 await page.getByRole('button',{name:'星星痘痘貼',exact:true}).click();
 const applied=page.getByRole('button',{name:'星星痘痘貼，已使用',exact:true});await applied.waitFor();
 const box=await applied.boundingBox();assert.ok(box.width>=44&&box.height>=44,'Small patch must retain a usable touch target');
 assert.equal(await page.getByRole('button',{name:'拖曳縮放與旋轉，點選精確調整',exact:true}).count(),0,'Initial care result must not be covered by an editing handle');
 await page.waitForTimeout(1100);await page.screenshot({path:'docs/audit/after-care.png'});
 await fs.writeFile('docs/audit/after-care.json',JSON.stringify({touchBox:box,usedOnFirstTap:true},null,2));
 await page.getByRole('button',{name:'復原',exact:true}).press('Enter');
 await applied.waitFor({state:'detached'});
 console.log('Care passed: first tap applies, 44px touch target, unobstructed face and one-step undo.');
}catch(e){console.log((await page.locator('body').ariaSnapshot()).slice(0,9000));throw e;}finally{await browser.close()}
