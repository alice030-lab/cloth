import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
const base=process.env.APP_URL??'http://127.0.0.1:8083';
const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true,args:['--no-sandbox']});
const context=await browser.newContext({viewport:{width:390,height:844}});
const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
const button=name=>page.getByRole('button',{name,exact:true});
const named=name=>page.getByText(name,{exact:true}).or(page.getByLabel(name,{exact:true})).first();
async function press(name){const target=button(name);await target.waitFor();for(let i=0;i<150&&!await target.isEnabled();i++)await page.waitForTimeout(20);assert.equal(await target.isEnabled(),true,`${name} must become enabled`);await target.press('Enter');}
async function accessible(){await page.locator('flt-semantics-placeholder, flt-semantics').first().waitFor({state:'attached'});const p=page.locator('flt-semantics-placeholder');if(await p.count())await p.evaluate(e=>e.click());}
async function count(locator, expected){for(let i=0;i<200&&await locator.count()!==expected;i++)await page.waitForTimeout(50);assert.equal(await locator.count(),expected);}
async function menu(action){await button('作品選單').first().press('Enter');await named(action).click();}
try{
 await page.goto(base);await accessible();await press('先試玩');
 await named('咖啡廳主題').click();await press('確認');
 // Every gender expression must retain a real photo renderer and a usable panel.
 for(const [value,label] of [['masculine','俐落 Masculine'],['neutral','中性 Neutral'],['feminine','柔和 Feminine']]){
  await press('我的替身');
  await page.getByRole('button',{name:/性別表現/}).press('Enter');
  await named(label).click();await press('套用');
  await page.getByRole('heading',{name:'我的替身',exact:true}).waitFor({state:'detached'});
  await page.getByLabel(/素材載入中/).first().waitFor({state:'detached'});
  await page.screenshot({path:`docs/screenshots/12-avatar-${value}.png`});
 }
 await press('完成穿搭');
 await page.getByRole('textbox',{name:'作品名稱',exact:true}).fill('驗收作品');
 await press('儲存可編輯作品');await named('作品已儲存').waitFor();await press('繼續編輯');
 await press('作品集');await menu('重新命名');
 await page.getByRole('textbox').fill('改名作品');await press('儲存');
 await page.getByRole('group',{name:/^改名作品/}).first().waitFor();await menu('複製為新變身');
 await press('完成穿搭');
 await press('儲存可編輯作品');await named('作品已儲存').waitFor();await press('繼續編輯');
 await press('作品集');await count(button('作品選單'),2);
 await page.getByRole('group',{name:/^改名作品・副本/}).first().waitFor();
 await page.screenshot({path:'docs/screenshots/13-project-copy.png'});
 await menu('刪除');await press('取消');await count(button('作品選單'),2);
 await menu('刪除');await press('確認');await count(button('作品選單'),1);
 // Reopen the surviving editable original, after deleting the copy.
 await page.mouse.click(100,200);await button('完成穿搭').waitFor();
 await press('隱私與設定');await named('清除所有本機資料').click();await press('確認');
 await named('已清除本機資料 · 僅限本機').waitFor();
 await page.reload();await accessible();await press('先試玩');await press('作品集');
 await named('還沒有作品，先完成一次穿搭吧。').waitFor();
 await page.screenshot({path:'docs/screenshots/14-cleared-projects.png'});
 assert.deepEqual(errors,[]);
 console.log('Acceptance passed: three realistic appearances, project rename/copy/delete/cancel/reopen, clear data and reload.');
}catch(error){await fs.writeFile('/tmp/cloth-acceptance-aria.txt',await page.locator('body').ariaSnapshot());await page.screenshot({path:'/tmp/cloth-acceptance-failure.png'});throw error;}finally{await browser.close();}
