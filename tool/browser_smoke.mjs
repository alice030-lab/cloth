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
const badResponses=[];page.on('response',response=>{if(response.status()>=400)badResponses.push(response.status()+' '+response.url());});
const external=new Set();context.on('request',request=>{const url=new URL(request.url());if(['http:','https:'].includes(url.protocol)&&url.origin!==new URL(base).origin)external.add(url.href);});
async function accessible(){
  await page.locator('flt-semantics-placeholder, flt-semantics').first().waitFor({state:'attached'});
  const placeholder=page.locator('flt-semantics-placeholder');
  if(await placeholder.count())await placeholder.evaluate(el=>el.click());
}
async function shot(name){while(await page.getByLabel(/素材載入中/).count()){await page.getByLabel(/素材載入中/).first().waitFor({state:'detached'});}await page.screenshot({path:path.join(out,name+'.png'),fullPage:false});}
try{
  await page.goto(base);await accessible();
  await page.getByRole('button',{name:'先試玩',exact:true}).press('Enter');
  await page.getByText('咖啡廳主題',{exact:true}).click();
  await page.getByRole('button',{name:'確認',exact:true}).press('Enter');
  await shot('01-editor');
  let currentScene='週末咖啡廳';
  for (const [id,label] of [['gallery','城市藝廊'],['garden','午後花園'],['coast','海邊假期'],['evening','夜晚餐敘'],['cafe','週末咖啡廳']]) {
    await page.getByRole('button',{name:currentScene,exact:true}).press('Enter');
    await page.getByRole('checkbox',{name:label,exact:true}).press('Space');
    await page.getByRole('button',{name:'套用',exact:true}).press('Enter');
    await page.getByRole('button',{name:label,exact:true}).waitFor();
    await shot(`08-scene-${id}`);currentScene=label;
  }
  await page.getByRole('button',{name:'完成穿搭',exact:true}).press('Enter');
  await page.getByRole('button',{name:'儲存可編輯作品',exact:true}).waitFor();
  await shot('09-clean-result');
  const cleanDownload=page.waitForEvent('download');
  await page.getByRole('button',{name:'匯出完成圖 PNG',exact:true}).press('Enter');
  await (await cleanDownload).saveAs(path.join(out,'outfit-demo.png'));
  await page.getByRole('button',{name:'繼續編輯',exact:true}).press('Enter');
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
  const comparison=page.waitForEvent('download');
  await page.getByRole('button',{name:'匯出前後對比卡',exact:true}).press('Enter');
  const comparisonFile=await comparison;await comparisonFile.saveAs(path.join(out,'comparison.png'));
  const comparisonBytes=await fs.readFile(path.join(out,'comparison.png'));
  assert.deepEqual([...comparisonBytes.subarray(0,8)],[137,80,78,71,13,10,26,10]);
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
  // A19: actually import, save and export while offline, beyond shell reload.
  await page.setViewportSize({width:390,height:844});
  const offlineChooser=page.waitForEvent('filechooser');
  await page.getByText('匯入截圖',{exact:true}).click();
  await (await offlineChooser).setFiles(target);
  await page.getByText('裝置端手動去背 · 圖片不會上傳',{exact:true}).waitFor();
  await page.getByRole('button',{name:'加入衣櫥',exact:true}).press('Enter');
  await page.getByRole('button',{name:'立即試穿',exact:true}).press('Enter');
  await page.getByRole('button',{name:'完成穿搭',exact:true}).press('Enter');
  await page.getByRole('button',{name:'儲存可編輯作品',exact:true}).press('Enter');
  await page.getByText('作品已儲存',{exact:true}).last().waitFor();
  const offlineDownload=page.waitForEvent('download');
  await page.getByRole('button',{name:'匯出完成圖 PNG',exact:true}).press('Enter');
  await (await offlineDownload).saveAs(path.join(out,'offline-export.png'));
  const offlineBytes=await fs.readFile(path.join(out,'offline-export.png'));
  assert.deepEqual([...offlineBytes.subarray(0,8)],[137,80,78,71,13,10,26,10]);
  assert.deepEqual([...external],[], 'App must not send photos or fetch remote dependencies');
  assert.deepEqual(badResponses,[], 'All bundled resources must load successfully');
  assert.deepEqual(errors,[]);console.log('Browser flow passed: five scenes, theme, body, import, editable save/reopen, completed and comparison PNGs, offline reload/import/save/export.');
}catch(error){await page.screenshot({path:'/tmp/cloth-browser-failure.png'});console.log((await page.locator('body').ariaSnapshot()).slice(0,12000));throw error;}finally{await browser.close();}
