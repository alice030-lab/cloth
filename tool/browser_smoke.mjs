// Run only against the actual Flutter release build, never a mock HTML page.
import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import path from 'node:path';
const base = process.env.APP_URL ?? 'http://127.0.0.1:8080';
const out = path.resolve('docs/screenshots');
await fs.mkdir(out, { recursive: true });
const browser = await chromium.launch({executablePath:process.env.CHROME_PATH || undefined,headless:true,args:['--no-sandbox']});
const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1,acceptDownloads:true});
const page=await context.newPage();
const errors=[];page.on('pageerror',e=>errors.push(e.message));
async function accessible(){
  await page.locator('flt-semantics-placeholder, flt-semantics').first().waitFor({state:'attached'});
  const placeholder=page.locator('flt-semantics-placeholder');
  if(await placeholder.count())await placeholder.evaluate(el=>el.click());
}
async function shot(name){await page.screenshot({path:path.join(out,name+'.png'),fullPage:true});}
try{
  await page.goto(base);await accessible();
  await page.getByRole('button',{name:'先試玩',exact:true}).press('Enter');
  await page.getByText('咖啡廳主題',{exact:true}).click();
  await page.getByRole('button',{name:'確認',exact:true}).press('Enter');
  await shot('01-editor');
  await page.getByRole('button',{name:'我的替身',exact:true}).press('Enter');await shot('02-body');
  await page.getByRole('button',{name:'取消',exact:true}).press('Enter');
  const chooser=page.waitForEvent('filechooser');
  await page.getByText('匯入截圖',{exact:true}).click();
  const file=await chooser;
  await file.setFiles({name:'測試單品.png',mimeType:'image/png',buffer:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAYAAABw4pVUAAABQ0lEQVR4nO3dsVEDMRRFUUF9FEElBFRCEfQH0SZEMLNfc5HPKcCa52t5w10LAAAA6Hjaedj7x+fXzvPu9Pb6suW72nLIfw7x03SY58kPX+usGGvN7xkNclqMy+SusSCnxrhM7RsJcnqMy8TO8WcIf3N7kEe5HZe797ohMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLECBIjSIwgMYLE3B5k1xsxK+7e64bEjAR5lFsysXPshpweZWrf6F/WqVEmd40/Q06LMr3H+9R/6bQfFgAAAFHfwiM0oNlN1D8AAAAASUVORK5CYII=','base64')});
  await page.getByText('裝置端手動去背 · 圖片不會上傳',{exact:true}).waitFor();await shot('03-import');
  await page.getByRole('button',{name:'加入衣櫥',exact:true}).press('Enter');
  await page.getByRole('button',{name:'立即試穿',exact:true}).press('Enter');
  await page.getByRole('button',{name:'完成穿搭',exact:true}).press('Enter');
  await page.getByRole('button',{name:'儲存可編輯作品',exact:true}).waitFor();await shot('04-result');
  await page.getByRole('button',{name:'儲存可編輯作品',exact:true}).press('Enter');
  await page.getByText('作品已儲存',{exact:true}).last().waitFor();
  const download=page.waitForEvent('download');
  await page.getByRole('button',{name:'匯出完成圖 PNG',exact:true}).press('Enter');
  const downloaded=await download;const target=path.join(out,'export.png');await downloaded.saveAs(target);
  const bytes=await fs.readFile(target);assert.deepEqual([...bytes.subarray(0,8)],[137,80,78,71,13,10,26,10]);
  await page.getByRole('button',{name:'繼續編輯',exact:true}).press('Enter');
  await page.reload();await accessible();
  await page.getByRole('button',{name:'作品集',exact:true}).press('Enter');await shot('05-projects');
  await page.getByText('我的週末穿搭',{exact:false}).or(page.getByLabel(/我的週末穿搭/)).first().waitFor();
  await page.mouse.click(100,200);
  await page.getByRole('button',{name:'完成穿搭',exact:true}).waitFor();
  await page.reload();await accessible();
  // Offline shell must be installed before evaluating offline reload.
  await page.evaluate(async()=>{await navigator.serviceWorker.ready;});
  await context.setOffline(true);await page.reload();await accessible();
  await page.getByRole('button',{name:'完成穿搭',exact:true}).waitFor();await shot('06-offline');
  for(const width of [360,430]){await page.setViewportSize({width,height:width===360?800:932});await shot(`07-width-${width}`);}
  assert.deepEqual(errors,[]);console.log('Browser flow passed: theme, body, import, save, PNG export, persisted projects, offline reload.');
}finally{await browser.close();}
