# 穿搭預演 · Outfit Canvas

購買前的情境換裝畫布。Flutter 3.47.8 / Dart 3.13.7，本機優先，不需帳號或 API 金鑰。

**公開 App：[穿搭預演](http://app.uslinkyou.com/)**。自訂網域根路徑已部署成功，[部署紀錄](https://github.com/alice030-lab/cloth/actions/runs/40470732019)。目前 GitHub 憑證仍在準備，HTTPS 尚未強制啟用；就緒後應使用 HTTPS。

**目前已完成真正 Flutter Web 編譯與核心操作驗證。** 靜態分析零問題、31 項 Flutter 測試與 3 項輔助工具測試通過。Chromium 已驗證試玩、主題、體型面板、PNG 匯入、作品儲存／重新載入／重開、PNG 匯出與離線重載。[A01–A20 驗收表](docs/ACCEPTANCE.md) 區分通過與未測項目；iOS／Android 原生去背、實機多指操作與完整 P0 尚未全部驗證。

## 啟動

```bash
cd /workspace/cloth
export PATH=/workspace/flutter-sdk/bin:$PATH
export PUB_CACHE=/workspace/.pub-cache
flutter --suppress-analytics pub get --enforce-lockfile
flutter --suppress-analytics run -d chrome
```

其他機器先安裝 Flutter stable 3.47.8，於專案根目錄使用相同指令。SDK HEAD 為 `737ba8f885dc774b53b442759999a312c9461e4e`。此雲端環境保留 SDK 與 `/workspace/.pub-cache`；不依賴唯讀 home 目錄的套件快取。

## 檢查與 release build

```bash
./tool/check.sh
python3 -m unittest discover -s tool -p test_tooling.py -v
python3 -m http.server 8080 --directory build/web
# 另一終端，server 保持執行
npm --prefix tool ci
CHROME_PATH=/usr/bin/chromium node tool/browser_smoke.mjs
```

`check.sh` 依序解析依賴、analyze、跑全部 Flutter 測試、build web（引擎不使用 CDN）、產生帶內容版本的離線 worker。任何失敗保留退出碼並停止。瀏覽器腳本可透過 APP_URL 與 CHROME_PATH 調整測試伺服器與 Chrome 路徑。它混用滑鼠與無障礙鍵盤操作；Flutter 語意樹有合併標籤，不能將語意定位失敗視為已證明 App 行為失敗。

此執行環境的沙箱禁止測試 runner／瀏覽器的本機 socket，執行時需要平台允許程序通訊；這與 App 網路功能不同。測試需要的 analyzer 快取也可能位於工具預設 home 位置。

`docs/screenshots/` 是真正 Flutter Web release 的實際截圖。`docs/reference.png` 是美術參考；`preview/app.html` 是另外一份免 Flutter 的 HTML 原型，兩者均不冒充編譯後 App。

## iOS / Android

```bash
./tool/bootstrap_platforms.sh
flutter --suppress-analytics run -d <裝置ID>
```

已實際產生 ios/、android/ runner 並接好 native/ adapter。bootstrap 會冪等更新介面設定，保留已有 runner。iOS 需 macOS/Xcode；Android 需 Android SDK 與支援的裝置。本次 Linux 環境沒有這些原生驗證條件，未宣稱 APK、iOS build、真機分享或 ML 品質通過。

| 平台 | 本機資料與匯入 | 自動去背 | 匯出 |
|---|---|---|---|
| Web | IndexedDB；PNG 匯入與重開已實測；手動擦除／還原有像素測試 | 明示使用手動工具 | 真實 PNG 下載通過 |
| iOS | 原生資料庫與檔案選取程式已接入，待裝置驗證 | Vision iOS 17+，含 instance 點選 adapter，未實測 | 儲存對話框與分享介面待驗證 |
| Android | 原生資料庫與檔案選取程式已接入，待裝置驗證 | ML Kit adapter，可能先下載模型；整體前景可用性待驗證，單一 instance 點選尚未完成 | 儲存對話框與分享介面待驗證 |

## 功能與結構

- 五階段入口、可略過的首次手勢引導與體型設定。
- L1 時裝畫替身：身高、胸腰臀、肩寬獨立控制點；性別表現、膚色與臉型設定。
- 獨立前後髮／服裝／道具圖層，拖曳、縮放、旋轉、24px 吸附、圖層面板、精確調整、50 步復原／重做。
- 22 個內建項目、5 個場景、1 組主題；自訂圖片與場景匯入。
- 原圖／透明棋盤、裁切、手動擦除／原像素還原、類別與來源網址、PNG 輸出。
- 草稿自動儲存與重試、可編輯作品、副本、重新命名、刪除、前後圖卡與 PNG 匯出。
- 離線 worker、資源引用清理、資料清除與本機隱私。

`lib/core/` 為模型／控制器／解碼；`lib/data/` 為 Repository；`lib/features/` 為畫布、修圖與頁面；`lib/painting/` 為原創繪製；`native/` 為平台去背。21 個模型／持久化測試與 10 個 widget 實例，包含三種尺寸、1.5 倍字體、實際拖曳／長按拖放、檔案關閉重開、解碼與透明像素還原。

使用 Sembast 統一 IndexedDB 與原生儲存，圖片以 blob asset ID 引用；文件有 schemaVersion，依賴已有真正的 pubspec.lock。衣櫥刪除採封存，清理只移除草稿、作品、衣櫥均無引用的 blob。圖片與身材不主動上傳。Web 資料依 origin 隔離，清瀏覽器資料或解除安裝會影響作品，PNG 匯出不是可編輯備份。

## 已知限制

- 已部署並綁定 `app.uslinkyou.com`，HTTP 首頁與 JavaScript 在 GitHub runner 檢查通過；GitHub 憑證仍為 new，待 DNS 檢查更新與 HTTPS 憑證完成後啟用 Enforce HTTPS。
- 原生建置、ML、分享與權限，實體裝置雙指手勢、70 張去背樣本、10 位目標使用者研究仍待完成。
- L1 是時裝畫，並非照片級替身；正式美術的滿意度尚待使用者驗收。
- Android 單一 instance 選取尚未完成，需手動擦除修正。
- Web 引擎可能先解碼 intrinsic frame，再產生受限尺寸輸出；25MB 輸入上限不能代替所有解碼記憶體壓力測試。
- Supabase、L2/L3、付款與推薦不在這次本機核心流程內。

素材授權與來源見 [ASSETS.md](docs/ASSETS.md)，產品範圍見 [product.md](docs/product.md)。

## 公開部署

GitHub Pages 自動部署與 `app.uslinkyou.com` 的設定步驟見 [GITHUB_PAGES.md](docs/GITHUB_PAGES.md)。main 更新會觸發部署流程；DNS 和儲存庫 Pages 功能需另外啟用。
