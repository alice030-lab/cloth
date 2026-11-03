# P0 驗收報告 · Flutter Web 已執行

已解除官方 SDK 下載阻擋。Flutter **3.47.8**、Dart **3.13.7** 已安裝，依賴已解析並保存 pubspec.lock。此報告取代先前「尚未下載 SDK」版本。

目前結論：**Web 核心操作鏈已驗證，全平台 P0 尚未完成。** 不將原生未測項目、主觀美術驗收或使用者研究標為通過。

2026-11-03 寫實素材更新提交 `6ab5b7b` 已由 [GitHub Actions run 41593727792](https://github.com/alice030-lab/cloth/actions/runs/41593727792) 完成 build、deploy 與公開首頁／main.dart.js 檢查，整體結論 success。公開入口為 https://app.uslinkyou.com/ 。本機 Chromium 對相同根路徑 release 建置完成下述互動驗收；此雲端瀏覽器對自訂網域的連線受代理限制，沒有將部署端的連線檢查冒稱為外站完整互動實測。

先前初次部署紀錄為 40468669688（預設 /cloth/）與 40470732019（自訂網域根路徑）。本次透過 GitHub 公開 Actions 頁面確認部署結果；沒有額外宣稱 DNS health API 或憑證狀態已重新查驗。

## 實際結果

| 命令／檢查 | 結果 |
|---|---|
| flutter --suppress-analytics analyze | 通過，No issues found |
| flutter --suppress-analytics test --reporter expanded | 42 項通過：24 模型／持久化、14 編輯器 widget、4 修圖介面 |
| flutter --suppress-analytics build web --release --no-web-resources-cdn | 通過；JavaScript release 與 Wasm dry run 成功，未做 Wasm runtime 驗收 |
| python3 tool/generate_offline_worker.py | 成功，46 個同來源資源 |
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
| A04 | 部分 | 單指與雙指 pointer 測試通過：同時平移／縮放／旋轉，一次 undo；實體手機與平台極值仍待測 |
| A05 | 通過自動化範圍 | 23/25px 吸附邊界、體型改變後 attached／free 單品行為 |
| A06 | 通過自動化範圍 | 前後髮的 Z/order、成組移除；圖層面板程式可用，複雜遮擋人工驗收待做 |
| A07 | 通過 | 50步歷史、單手勢還原、redo 與新操作清空，主題一次 undo |
| A08 | 部分 | Chromium 真正檔案選取與 PNG 匯入通過；原生權限拒絕、HEIC 與格式錯誤矩陣待測 |
| A09 | 部分 | Web 明示手動模式；擦除／還原的透明像素與 PNG 輸出已測；iOS/Android 自動去背未驗證 |
| A10 | 部分 | reference 自由貼紙類別與模特兒提示已實作；真實網拍模特兒圖尚未驗收 |
| A11 | 部分 | 主題套用測試通過、8道具已附；精華／痘痘貼回饋與五階段真人完成率仍待人工驗收 |
| A12 | 部分 | 5 個寫實場景均已在 Chromium 實際切換；取景及自訂匯入已實作，全部裁切極值矩陣未跑完 |
| A13 | 通過 | 真實檔案資料庫關閉重開、IndexedDB reload 後恢復、離線重載 |
| A14 | 通過核心鏈 | Chromium 儲存→reload→縮圖重開，另實際完成作品改名、複製另存、刪除取消、確認刪除副本、重開原作；widget 重開後可再次新增圖層 |
| A15 | 部分 | 登場、before/after、完成圖與前後對比卡真實 PNG 下載均通過；原生分享待真機驗收 |
| A16 | 通過資料層 | 刪除衣櫥單品保留已存作品引用；交易清理只刪 orphan blob，容量壓力測試未做 |
| A17 | 通過資料層 | 模擬磁碟錯誤，失敗回報與記憶體編輯保留；真實裝置磁碟耗盡未做 |
| A18 | 通過指定 Web 範圍 | 360×800／390×844／430×932、1.5倍字體 widget 無例外，Web 寬度截圖已產生 |
| A19 | 通過已執行範圍 | Chromium 離線 reload 後恢復畫布，再實際選檔匯入、加入衣櫥、試穿、儲存、完成圖 PNG 下載，均通過 |
| A20 | 部分 | 清除交易測試涵蓋文件／blob／體型／偏好；Chromium 清除後 reload 回到首次引導且作品清單為空；完整匯入／儲存／匯出監測零跨來源請求及零失敗資源。原生資料清除人工測試未做 |

## 原生與研究限制

本機是 Linux，沒有 macOS／Xcode 或實體裝置。本輪已成功安裝 Android SDK 36 與 NDK；本機 APK 建置仍因 JRE 沒有 javac 而失敗，因此未宣稱本機 APK 成功。

[原生 CI run 41594945631](https://github.com/alice030-lab/cloth/actions/runs/41594945631) 在 GitHub 的 Ubuntu／macOS runner 實際成功編譯 Android debug APK 與 iOS 模擬器 App，並各自上傳 Artifact。這是編譯證據，不能代替 Vision／ML Kit 品質、裝置權限與原生分享驗證。Android 單一 instance 點選目前仍明示不支援。

70 張真實網拍／自拍樣本、10 位目標使用者測試、正式美術滿意度尚未執行，先前 pilot 成功率不是本次數據。

## 重跑與畫面

依 README 的 tool/check.sh 與 browser_smoke.mjs 指令重跑。測試遇到 socket／analyzer home cache 限制，需要執行環境允許相應工具通訊／快取，而非修改 App 斷言。

實際 Flutter 截圖：01-editor.png、02-body.png、03-import.png、04-result.png、05-projects.png、06-offline.png、07-width-360.png、07-width-430.png；實際匯出為 export.png，均在 docs/screenshots/。參考 mockup 與獨立 HTML 預覽均與這些截圖分開保存。

## 2026-11-03 視覺重做補充

詳見 VISUAL_REBUILD.md 與 ASSETS.md。新增寫實示範人物、12 件獨立服裝／鞋包、前後髮、四個新寫實場景與繁中襯線標題；保留五官與身材的限制說明。胸／腰／臀為局部網格變形，不宣稱校準量測或真人像似度。35 項 Flutter 測試、7 項 Python 輔助測試；瀏覽器擴充到五場景、前後對比卡 PNG 和真正離線匯入／儲存／匯出。這些通過不等於原生 P0、正式美術與研究驗收完成。

瀏覽器截圖固定實際 viewport（不擷取螢幕閱讀語意層造成的文件延伸），新增 08-scene-*.png、comparison.png、offline-export.png。

## 0.3 操作與原生驗收

本輪 40 項 Flutter 測試涵蓋單點擦除／還原的實際介面與 Alpha 輸出、錯誤格式、取消原生處理後忽略晚回應、保養使用狀態與 undo，以及非預設圖層寬度的 JSON roundtrip。另已新增 browser_acceptance.mjs 操作三種外觀及作品管理／清除資料矩陣，結果依部署紀錄補記。browser_smoke.mjs 同時檢查跨來源請求與失敗的同來源資源，避免以限制外連掩蓋缺少的字型檔。

追加結果：browser_acceptance.mjs 已通過三種外觀、作品改名／複製另存／刪除取消／確認刪除／重開原作，以及清除資料後重新啟動與空作品清單。新增 12-avatar-*.png、13-project-copy.png、14-cleared-projects.png 實際截圖。browser_smoke.mjs 的跨來源請求與資源載入檢查均通過。

41 項測試新增自訂圖片由紅切換為藍的實際像素檢查，確保替換時不讀取已釋放的舊圖片。文字輸入與操作以 Flutter 語意狀態為準，儲存期間的停用按鈕需等到重新啟用，不能以送出鍵盤事件視為完成操作。

縮放追加驗收：使用雙指在吸附錨點附近連續放大，放手後保留尺寸、仍貼齊錨點且一次 undo 還原。實際檔案資料庫關閉／重開亦驗證非預設縮放與寬度完全保留；只針對沒有 appearance 欄位的舊文件做初始座標遷移，不在每次啟動重設尺寸。本輪共 42 項 Flutter 測試（24 模型／資料、14 編輯器、4 修圖）。
