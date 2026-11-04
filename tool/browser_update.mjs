import {chromium} from 'playwright';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const worker='build/web/offline_worker.js';
const original=await fs.readFile(worker);
const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true,args:['--no-sandbox']});
const context=await browser.newContext({viewport:{width:390,height:844}});
const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
async function accessible(){await page.locator('flt-semantics-placeholder, flt-semantics').first().waitFor({state:'attached'});const p=page.locator('flt-semantics-placeholder');if(await p.count())await p.evaluate(e=>e.click());}
const button=name=>page.getByRole('button',{name,exact:true});
try {
 await page.goto(process.env.APP_URL??'http://127.0.0.1:8083/');await accessible();
 await button('先試玩').press('Enter');await page.getByText('咖啡廳主題',{exact:true}).click();await button('確認').press('Enter');
 await page.evaluate(async()=>{await navigator.serviceWorker.ready; if(!navigator.serviceWorker.controller)await new Promise(resolve=>navigator.serviceWorker.addEventListener('controllerchange',resolve,{once:true}));});
 // A changed worker is a real SW update, not a mocked controllerchange event.
 await fs.writeFile(worker,Buffer.concat([original,Buffer.from(`\n// Browser audit update ${Date.now()}\n`)]));
 await page.evaluate(async()=>{const registration=await navigator.serviceWorker.getRegistration();await registration.update();});
 const update=page.getByRole('button',{name:/^(存草稿|儲存)並更新$/});await update.waitFor();
 await button('我的替身').press('Enter');
 await update.click();
 await page.getByText('請先完成或關閉目前視窗，並確認草稿已儲存，再更新。',{exact:true}).waitFor();
 await page.getByRole('heading',{name:'我的替身',exact:true}).waitFor();
 await page.screenshot({path:'docs/audit/update-protected.png'});
 await button('取消').press('Enter');
 await page.getByRole('heading',{name:'我的替身',exact:true}).waitFor({state:'detached'});
 // Add an edit, then immediately choose update. Recovery must include it.
 await page.getByRole('button',{name:'奶油白短版上衣',exact:true}).last().click();
 await button('拖曳縮放與旋轉，點選精確調整').waitFor();
 const shirts=page.getByRole('button',{name:'奶油白短版上衣',exact:true});
 const countBefore=await shirts.count();assert.ok(countBefore>=2);
 await Promise.all([page.waitForEvent('domcontentloaded'),update.click()]);
 await accessible();
 await button('完成穿搭').waitFor();
 for(let i=0;i<100&&await shirts.count()!==countBefore;i++)await page.waitForTimeout(30);
 assert.equal(await shirts.count(),countBefore,'Reload must recover the newly edited draft');
 assert.deepEqual(errors,[]);
 console.log(`Update passed: real worker activation, blocked modal reload, saved draft recovery (${countBefore} shirt controls).`);
}catch(e){await page.screenshot({path:'/tmp/cloth-update-failure.png'});console.log((await page.locator('body').ariaSnapshot()).slice(0,9000));throw e;}finally{await fs.writeFile(worker,original);await browser.close();}
