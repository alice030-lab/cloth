// New workers may activate while this tab still runs the previous Flutter code.
// Announce that state; reload only after Flutter confirms the draft was saved.
(() => {
  if (!('serviceWorker' in navigator)) return;
  let controlled = !!navigator.serviceWorker.controller;
  let registration;
  let notice;
  function showUpdate() {
    if (notice) return;
    notice = document.createElement('aside');
    notice.id = 'app-update';
    notice.setAttribute('aria-label', 'App 更新');
    Object.assign(notice.style, {
      position: 'fixed', left: '12px', right: '12px', bottom: 'max(12px, env(safe-area-inset-bottom))',
      maxWidth: '520px', margin: '0 auto', zIndex: '2147483647', padding: '10px 12px',
      display: 'flex', alignItems: 'center', gap: '8px', borderRadius: '16px',
      color: '#292321', background: '#fffcf8', boxShadow: '0 4px 24px #29232133',
      border: '1px solid #d8c8bf', font: '14px sans-serif'
    });
    const status = document.createElement('span');
    status.textContent = '新版本已準備好';
    status.setAttribute('role', 'status');
    Object.assign(status.style, {flex: '1', lineHeight: '1.5'});
    const update = document.createElement('button');
    update.textContent = '存草稿並更新';
    Object.assign(update.style, {minHeight: '44px', padding: '0 14px', border: '0', borderRadius: '12px', background: '#762e3d', color: '#fff', font: 'inherit', cursor: 'pointer', flexShrink: '0'});
    update.addEventListener('click', async () => {
      update.disabled = true;
      try {
        if (typeof globalThis.__outfitPrepareReload !== 'function') {
          status.textContent = '畫面準備中，請稍後重試。';
        } else if (await globalThis.__outfitPrepareReload()) {
          location.reload();
          return;
        } else {
          status.textContent = '請先完成或關閉目前視窗，並確認草稿已儲存，再更新。';
        }
      } catch (_) {
        status.textContent = '草稿未能儲存，請回到畫布重試。';
      }
      update.disabled = false;
    });
    const close = document.createElement('button');
    close.textContent = '×'; close.setAttribute('aria-label', '稍後更新');
    Object.assign(close.style, {width: '44px', height: '44px', border: '0', background: 'transparent', color: '#746660', fontSize: '24px', cursor: 'pointer', flexShrink: '0'});
    close.addEventListener('click', () => {notice.remove(); notice = null;});
    notice.append(status, update, close);
    document.body.append(notice);
  }
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (controlled) showUpdate();
    controlled = true;
  });
  window.addEventListener('load', async () => {
    try {
      registration = await navigator.serviceWorker.register(new URL('offline_worker.js', document.baseURI), {updateViaCache: 'none'});
      await registration.update();
    } catch (_) { /* Existing offline shell remains usable. */ }
  });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && registration) registration.update().catch(() => {});
  });
})();
