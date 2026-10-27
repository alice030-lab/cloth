# GitHub Pages / app.uslinkyou.com

目標 repository：alice030-lab/cloth，部署分支 main，正式自訂網域 app.uslinkyou.com。

## 已加入的程式設定

`.github/workflows/pages.yml` 在 main push 或手動執行時：鎖定依賴 → analyze/test → release Web → Pages artifact → deploy-pages。deploy job 只有 pages:write 與 id-token:write；build job 保持 contents:read。

web/CNAME 是此專案的自訂網域來源。存在時 build 使用 base-href `/`；移除它改用 GitHub 專案網址時，workflow 自動使用 `/cloth/`。`tool/prepare_pages.py` 驗證域名並產生部署目錄 CNAME / .nojekyll；離線 cache 依 registration.scope 隔離，避免同一 github.io origin 下不同專案清理彼此的 cache。

**Actions 部署時，CNAME 檔不會代替 GitHub 儲存庫的 Custom domain 設定。** 下列 GitHub 設定與 DNS 都必須完成。

## GitHub 設定

在儲存庫 Settings → Pages：

1. Build and deployment 的 Source 選 GitHub Actions。
2. Custom domain 填 `app.uslinkyou.com` 並儲存。
3. DNS 檢查通過、憑證準備完成後，開啟 Enforce HTTPS。
4. 到 Actions 執行 Deploy Flutter Web to GitHub Pages，或推送 main 觸發。

如果 environment github-pages 要求 reviewer，需由有權限的人批准該 deployment。私有儲存庫還受帳號的 GitHub Pages 方案條件限制；未確認可用前不得自行將儲存庫改為公開。

## DNS 設定

在 uslinkyou.com 的 DNS 管理處新增：

| 類型 | 名稱 / Host | 目標 / Value |
|---|---|---|
| CNAME | app | alice030-lab.github.io |

目標不含 https、斜線或 cloth 路徑。如果 app 已有 DNS 記錄，先確認用途，不要直接覆蓋。Cloudflare 管理 DNS 時，GitHub 驗證與憑證申請階段先使用 DNS only。

可另在 GitHub 個人 Settings → Pages 驗證根網域，依 GitHub 畫面提供的唯一 TXT 值新增，不能自行猜值。

## 檢查與更新

- Actions 必須同時完成 build 與 deploy job；本機 build 通過不代表已部署。
- 使用正式網域檢查 HTTPS、圖片匯入、作品儲存重開、PNG 匯出及離線重載。
- 作品依網站 origin 儲存在瀏覽器，github.io 測試網址與自訂網域的本機作品不會自動同步。
- 後續推送 main 自動更新；未授權時不要強制 push 或覆蓋既有遠端提交。
