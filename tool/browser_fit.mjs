import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const browser=await chromium.launch({executablePath:process.env.CHROME_PATH??'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const page=await browser.newPage({viewport:{width:390,height:844}});
const button=name=>page.getByRole('button',{name,exact:true});
async function ready(){while(await page.getByLabel(/素材載入中/).count())await page.getByLabel(/素材載入中/).first().waitFor({state:'detached'});}
try{
 await page.goto(process.env.APP_URL??'http://127.0.0.1:8083');
 await page.locator('flt-semantics-placeholder,flt-semantics').first().waitFor({state:'attached'});
 const p=page.locator('flt-semantics-placeholder');if(await p.count())await p.evaluate(e=>e.click());
 await button('先試玩').press('Enter');await page.getByText('咖啡廳主題',{exact:true}).click();await button('確認').press('Enter');await ready();
 await fs.mkdir('docs/fit',{recursive:true});await page.screenshot({path:'docs/fit/01-clothing.png'});
 await page.getByText('整理',{exact:true}).click();await button('自然長髮・前').last().click();await ready();
 await button('完成單品調整').press('Enter');await page.screenshot({path:'docs/fit/02-hair.png'});
 const front=button('自然長髮・前').first(),back=button('自然長髮・後').first();
 const beforeFront=await front.boundingBox(),beforeBack=await back.boundingBox();
 assert.ok(Math.abs(beforeFront.height-beforeBack.height)<1,'Hair pair must have equal height');
 assert.ok(beforeFront.y<beforeBack.y && beforeBack.y-beforeFront.y<10,'Hair pair must register the face opening');
 await front.click();const handle=button('拖曳縮放與旋轉，點選精確調整');const box=await handle.boundingBox();
 const style=await page.addStyleTag({content:'flt-semantics,flt-semantics *{pointer-events:none!important}'});
 const x=box.x+22,y=box.y+22;await page.mouse.move(x,y);await page.mouse.down();await page.mouse.move(x+15,y+10,{steps:3});await page.mouse.move(x+35,y+25,{steps:5});await page.mouse.up();await style.evaluate(e=>e.remove());
 const afterFront=await front.boundingBox(),afterBack=await back.boundingBox();assert.ok(afterFront.height>beforeFront.height);assert.ok(Math.abs(afterFront.y-afterBack.y)<20,'Hair pair must keep registered offsets');
 await button('自動貼合全部穿戴物').press('Enter');await ready();
 await page.screenshot({path:'docs/fit/03-refit.png'});
 await fs.writeFile('docs/fit/measurements.json',JSON.stringify({beforeFront,beforeBack,afterFront,afterBack},null,2));
 await button('我的替身').press('Enter');await page.getByRole('button',{name:/性別表現/}).press('Enter');await page.getByRole('menuitem',{name:'俐落 Masculine',exact:true}).click();await button('套用').press('Enter');await page.getByRole('heading',{name:'我的替身',exact:true}).waitFor({state:'detached'});await ready();await page.screenshot({path:'docs/fit/04-masculine.png'});
 console.log('Fit passed: complete outfits, registered hair pair, linked corner transform, refit all and avatar change.');
}catch(e){await fs.writeFile('/tmp/cloth-fit-aria.txt',await page.locator('body').ariaSnapshot());throw e;}finally{await browser.close();}
