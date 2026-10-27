# P0 驗收報告 · Flutter Web 已執行

已解除官方 SDK 下載阻擋。Flutter **3.47.8**、Dart **3.13.7** 已安裝，依賴已解析並保存 pubspec.lock。此報告取代先前「尚未下載 SDK」版本。

目前結論：**Web 核心操作鏈已驗證，全平台 P0 尚未完成。** 不將原生未測項目、主觀美術驗收或使用者研究標為通過。已部署到 https://alice030-lab.github.io/cloth/ ，GitHub Actions run 40468669688 的 build、deploy 與公開首頁／main.dart.js 的 HTTPS 檢查均通過。相同 /cloth/ 產物在本機 Chromium 完整流程與離線測試通過。執行環境對 github.io 的直接外連受代理限制，未宣稱在此瀏覽器對外站做完整互動驗收。自訂網域 app.uslinkyou.com 尚未綁定。

## 實際結果

| 命令／檢查 | 結果 |
|---|---|
| flutter --suppress-analytics analyze | 通過，No issues found |
| flutter --suppress-analytics test --reporter expanded | 31 項通過：21 模型／持久化、10 widget 實例 |
| flutter --suppress-analytics build web --release --no-web-resources-cdn | 通過；JavaScript release 與 Wasm dry run 成功，未做 Wasm runtime 驗收 |
| python3 tool/generate_offline_worker.py | 成功，37 個同來源資源 |
| python3 -m unittest discover -s tool -p test_tooling.py -v | 3 個輔助腳本測試通過 |
| tool/browser_smoke.mjs + Chromium | 通過：試玩→套主題→體型面板→選圖→修圖匯入→立即試穿→登場→儲存→下載 PNG→reload→作品集→縮圖重開→離線 reload；360/390/430 寬截圖 |
| tool/bootstrap_platforms.sh | 實際執行成功，產生 iOS／Android runner 並接入 adapter；不代表原生 build 通過 |

瀏覽器驗收確認下載檔案為真正 PNG。無障礙 keyboard 與滑鼠混用：Flutter 語意樹的合併 label、live announcement 重複文字與動畫期間 hit-test 會影響定位，腳本針對實際輸出使用明確等待與相應定位。實際 pointer 拖曳／長按拖放另由 widget 測試驗證。

本輪修正：Blob 的公開匯入、道具函式避免覆寫 State.activate、替身輪廓斷裂、Web 不支援 encoded ImageDescriptor.width/height 的解碼 API、缺少的 Cupertino 字型與 Unicode 箭頭 fallback、測試假時鐘／儲存排程協調，以及過期 loading 說明的移除。沒有停用功能斷言或以零測試替代。

## A01–A20

「通過」限定下述已執行證據；「部分」仍有驗收缺口。

| ID | 狀態 | 證據與範圍 |
|---|---|---|
| A01 | 通過 Web | Chromium 首次免登入試玩；三尺寸 widget 與實際截圖 |
| A02 | 通過自動化範圍 | 參數獨立控制點、合法範圍、BodyPanel 取消／套用／undo；真人「像我」研究未做 |
| A03 | 通過 | 點入與工具列長按拖放、實際畫布 pointer 拖曳、分類與 Z 的模型測試 |
| A04 | 部分 | 單指移動與解除吸附已測；實體多指縮放／旋轉及極值操作仍待測 |
| A05 | 通過自動化範圍 | 23/25px 吸附邊界、體型改變後 attached／free 單品行為 |
| A06 | 通過自動化範圍 | 前後髮的 Z/order、成組移除；圖層面板程式可用，複雜遮擋人工驗收待做 |
| A07 | 通過 | 50步歷史、單手勢還原、redo 與新操作清空，主題一次 undo |
| A08 | 部分 | Chromium 真正檔案選取與 PNG 匯入通過；原生權限拒絕、HEIC 與格式錯誤矩陣待測 |
| A09 | 部分 | Web 明示手動模式；擦除／還原的透明像素與 PNG 輸出已測；iOS/Android 自動去背未驗證 |
| A10 | 部分 | reference 自由貼紙類別與模特兒提示已實作；真實網拍模特兒圖尚未驗收 |
| A11 | 部分 | 主題套用測試通過、8道具已附；精華／痘痘貼回饋與五階段真人完成率仍待人工驗收 |
| A12 | 部分 | 5場景、自訂匯入、取景與取消已實作；Chromium 本次使用咖啡廳，全部場景／裁切矩陣未跑完 |
| A13 | 通過 | 真實檔案資料庫關閉重開、IndexedDB reload 後恢復、離線重載 |
| A14 | 通過核心鏈 | Chromium 儲存→reload→作品清單→縮圖重開，widget 重開後可再次新增圖層；刪除／副本 UI 人工矩陣待補 |
| A15 | 部分 | 登場、before/after、真實完成圖 PNG 下載通過；原生分享、對比卡下載 UI 尚待獨立驗收 |
| A16 | 通過資料層 | 刪除衣櫥單品保留已存作品引用；交易清理只刪 orphan blob，容量壓力測試未做 |
| A17 | 通過資料層 | 模擬磁碟錯誤，失敗回報與記憶體編輯保留；真實裝置磁碟耗盡未做 |
| A18 | 通過指定 Web 範圍 | 360×800／390×844／430×932、1.5倍字體 widget 無例外，Web 寬度截圖已產生 |
| A19 | 通過已執行範圍 | Chromium 連線完成匯入／儲存／匯出，離線後 reload 成功並恢復畫布；未在離線狀態重跑每個匯入／匯出動作 |
| A20 | 部分 | 清除交易測試涵蓋文件／blob／體型／偏好；未做完整網路封包稽核與原生資料清除人工測試 |

## 原生與研究限制

本機是 Linux，沒有 macOS／Xcode，也沒有 Android SDK、adb、sdkmanager 或實體裝置。因此本次未產生／驗證 iOS build、APK、Vision／ML Kit 品質、裝置權限與原生分享。Android 單一 instance 點選目前明示不支援。Web 手動模式已能獨立完成核心工作；不拿 Web 成功代替原生結果。

70 張真實網拍／自拍樣本、10 位目標使用者測試、正式美術滿意度尚未執行，先前 pilot 成功率不是本次數據。

## 重跑與畫面

依 README 的 tool/check.sh 與 browser_smoke.mjs 指令重跑。測試遇到 socket／analyzer home cache 限制，需要執行環境允許相應工具通訊／快取，而非修改 App 斷言。

實際 Flutter 截圖：01-editor.png、02-body.png、03-import.png、04-result.png、05-projects.png、06-offline.png、07-width-360.png、07-width-430.png；實際匯出為 export.png，均在 docs/screenshots/。參考 mockup 與獨立 HTML 預覽均與這些截圖分開保存。
