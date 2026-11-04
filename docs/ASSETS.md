# 素材與來源

| 路徑／內容 | 來源 | 使用方式 |
|---|---|---|
| assets/scenes/cafe.png | 本次工作以 OpenAI image generation 產生的原創空咖啡廳場景，沒有從社群或網拍抓圖 | 執行期場景背景，隨 App 附帶 |
| lib/painting/art.dart 的人物、22 個內建項目與四個場景 | 本次工作新增的程式化向量繪製 | 可獨立變形／互動；沒有切割主畫面 mockup 冒充圖層 |
| assets/fonts/NotoSansTC.otf | 機器既有 Noto Sans CJK Regular TTC 的 Traditional Chinese font face，使用 fontTools 匯出 OTF | 完整本機中文字型，不使用字型 CDN |
| assets/fonts/LICENSE.txt | 原系統 fonts-noto-cjk 套件授權說明，含 SIL OFL | 隨字型散布 |
| docs/reference.png | 本對話先前生成的設計參考圖 | 文件用途，不作執行期 UI |

內建項目 metadata 在 `builtinItems()`：名稱、類別、圖層、形狀／圖片比例與顏色；預設錨點／倍率在 KindInfo。原創向量的繪製座標作為其內部比例定義。匯入照片由使用者自行選取，這個版本不向外抓取商品圖片。

上述為原始插畫版本，現保留為替代模式；本次寫實素材更新如下。兩種模式均尚未經人體比例像似度研究，也未取得使用者的正式視覺驗收。

## 寫實素材更新（2026-11-03）

下列均為本次以 OpenAI image generation 新製作的素材，不是從參考 mockup 切下，也不是抓取網拍照片。PNG 原檔隨 App 打包；矩形圖集中的每個項目由 `lib/painting/fashion.dart` 的 source rectangle 獨立繪製、選取與變換。

| 檔案 | 內容 |
|---|---|
| assets/fashion/avatar.png | 虛構成人示範人物、透明背景、素色內搭；不是使用者自拍 |
| assets/fashion/garments.png | 白／玫瑰短上衣、藍針織外套、丹寧／西裝褲、黑裙，共 6 個獨立精靈 |
| assets/fashion/accessories.png | 兩色鞋、兩色包，共 4 個獨立精靈 |
| assets/fashion/extras.png | 綁帶襯衫、酒紅外套、前髮／後髮，共 4 個獨立精靈 |
| assets/fashion/scenes.png | 藝廊、花園、海岸、餐廳四個無人場景；各自可調整取景 |
| assets/fonts/ClothEditorial.otf | 系統 NotoSerifCJK-Bold.ttc 的繁中字形，經 fontTools 子集化與更名；只用於標題與完成按鈕，授權同附帶 SIL OFL |

寫實人物採局部網格變形：胸、腰、臀、肩、腿長各有影響範圍，與錨點共用同一個變形函式。這是視覺比例編輯，不是量測、合身預測、自拍生成，也不是衣服的布料模擬。三種性別表現的寫實外觀與原有插畫外觀均可切換。圖層貼合、髮際、膚色調整仍需正式美術與真實使用者驗收。

## 三種寫實外觀補充

`assets/fashion/avatars-inclusive.png` 為本次使用 OpenAI image generation 製作的兩格透明圖集：成年男性與中性外觀，各自獨立取樣，與既有女性外觀共用局部網格和錨點。人物皆為虛構示範，不代表使用者的長相。不同素材的肩線與衣物初始寬度已分開校正，使用者亦可在精確調整中改變圖層寬度。

## 0.3.1 透視修正

`assets/fashion/footwear.png` 為本次新製作的原創透明圖集（OpenAI image generation），分成酒紅／奶油兩對正面低視角鞋，取代先前俯視鞋在畫布上的使用。原 accessories.png 的包繼續使用。素材未從參考圖或網拍剪下；不宣稱具備真實穿著／合身校準。
