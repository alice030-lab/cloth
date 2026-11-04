import {chromium} from 'playwright';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const baseline=process.argv.includes('--baseline');
const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true,args:['--no-sandbox']});
const page=await browser.newPage({viewport:{width:390,height:844}});
const errors=[];page.on('pageerror',e=>errors.push(e.message));
await fs.mkdir('docs/audit',{recursive:true});
try {
 await page.goto(process.env.APP_URL??'http://127.0.0.1:8083/');
 await page.locator('flt-semantics-placeholder, flt-semantics').first().waitFor({state:'attached'});
 const placeholder=page.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.evaluate(e=>e.click());
 await page.getByRole('button',{name:'先試玩',exact:true}).press('Enter');
 await page.getByText('咖啡廳主題',{exact:true}).click();await page.getByRole('button',{name:'確認',exact:true}).press('Enter');
 while(await page.getByLabel(/素材載入中/).count()){await page.getByLabel(/素材載入中/).first().waitFor({state:'detached'});}
 const shirt=page.getByRole('button',{name:'奶油白短版上衣',exact:true}).first();await shirt.click();
 const before=await shirt.boundingBox();await page.screenshot({path:`docs/audit/${baseline?'before':'after'}-selection.png`});
 let start;
 if(baseline) start={x:before.x+before.width-1,y:before.y+before.height-1};
 else {const box=await page.getByRole('button',{name:'拖曳縮放與旋轉，點選精確調整',exact:true}).boundingBox();assert.ok(box.width>=44&&box.height>=44);start={x:box.x+box.width/2,y:box.y+box.height/2};}
 // Use real canvas mouse input rather than the accessibility DOM's synthetic click.
 const style=await page.addStyleTag({content:'flt-semantics,flt-semantics * {pointer-events:none!important}'});
 await page.mouse.move(start.x,start.y);await page.mouse.down();
 await page.mouse.move(start.x+30,start.y+15,{steps:4});await page.mouse.move(start.x+75,start.y,{steps:5});await page.mouse.up();
 await style.evaluate(e=>e.remove());
 const after=await shirt.boundingBox();
 const result={baseline,before,after,saveHasTextLabel:await page.getByRole('button',{name:'儲存',exact:true}).count()>0};
 if(baseline){assert.ok(Math.abs(after.width-before.width)<1);assert.equal(result.saveHasTextLabel,false);}
 else {
  assert.ok(after.width>before.width*1.1,'Dragging the visible corner must resize the actual garment');assert.equal(result.saveHasTextLabel,true);
  await page.getByRole('button',{name:'復原',exact:true}).press('Enter');
  let restored;for(let i=0;i<100;i++){restored=await shirt.boundingBox();if(Math.abs(restored.width-before.width)<1)break;await page.waitForTimeout(20);}assert.ok(Math.abs(restored.width-before.width)<1,'A corner drag must undo in one step');
  await shirt.click();await page.getByRole('button',{name:'調整選取單品',exact:true}).press('Enter');
  await page.getByRole('button',{name:'取消',exact:true}).press('Enter');
  await page.getByText('精確調整',{exact:true}).waitFor({state:'hidden'});
  await page.getByRole('button',{name:'移除選取單品',exact:true}).press('Enter');
  await page.getByRole('button',{name:'復原',exact:true}).press('Enter');
  await shirt.waitFor();
 }
 assert.deepEqual(errors,[]);await fs.writeFile(`docs/audit/${baseline?'before':'after'}.json`,JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}catch(e){await page.screenshot({path:'/tmp/cloth-audit-failure.png'});console.log((await page.locator('body').ariaSnapshot()).slice(0,9000));throw e;}finally{await browser.close()}
