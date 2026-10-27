# 素材與來源

| 路徑／內容 | 來源 | 使用方式 |
|---|---|---|
| assets/scenes/cafe.png | 本次工作以 OpenAI image generation 產生的原創空咖啡廳場景，沒有從社群或網拍抓圖 | 執行期場景背景，隨 App 附帶 |
| lib/painting/art.dart 的人物、22 個內建項目與四個場景 | 本次工作新增的程式化向量繪製 | 可獨立變形／互動；沒有切割主畫面 mockup 冒充圖層 |
| assets/fonts/NotoSansTC.otf | 機器既有 Noto Sans CJK Regular TTC 的 Traditional Chinese font face，使用 fontTools 匯出 OTF | 完整本機中文字型，不使用字型 CDN |
| assets/fonts/LICENSE.txt | 原系統 fonts-noto-cjk 套件授權說明，含 SIL OFL | 隨字型散布 |
| docs/reference.png | 本對話先前生成的設計參考圖 | 文件用途，不作執行期 UI |

內建項目 metadata 在 `builtinItems()`：名稱、類別、圖層、形狀／圖片比例與顏色；預設錨點／倍率在 KindInfo。原創向量的繪製座標作為其內部比例定義。匯入照片由使用者自行選取，這個版本不向外抓取商品圖片。

目前美術為可用實作素材，尚未由使用者驗收符合參考圖的精緻度。人物不是照片級替身，也沒有經人體比例像似度研究。
