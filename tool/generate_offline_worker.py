"""Generate a same-origin, versioned offline shell after flutter build web."""
from pathlib import Path
import hashlib
import json
root = Path(__file__).resolve().parent.parent / 'build/web'
if not (root / 'main.dart.js').exists():
    raise SystemExit('Run flutter build web --release --no-web-resources-cdn first.')
files = sorted(p for p in root.rglob('*') if p.is_file() and p.name not in {'offline_worker.js', 'flutter_service_worker.js'})
digest = hashlib.sha256()
for path in files:
    digest.update(path.relative_to(root).as_posix().encode())
    digest.update(path.read_bytes())
paths = [p.relative_to(root).as_posix() for p in files]
script = """// Generated from the built app. No remote/CDN requests required.
const CACHE_PREFIX = 'outfit-' + encodeURIComponent(self.registration.scope) + '-';
const CACHE = CACHE_PREFIX + '__VERSION__';
const FILES = __FILES__;
self.addEventListener('install', event => event.waitUntil((async () => {
  const cache = await caches.open(CACHE);
  await cache.addAll(FILES.map(file => new URL(file, self.registration.scope).href));
  await self.skipWaiting();
})()));
self.addEventListener('activate', event => event.waitUntil((async () => {
  for (const key of await caches.keys()) {
    if (key.startsWith(CACHE_PREFIX) && key !== CACHE) await caches.delete(key);
  }
  await self.clients.claim();
})()));
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET' || new URL(event.request.url).origin !== self.location.origin) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const found = await cache.match(event.request, {ignoreSearch: true});
    if (found) return found;
    try { return await fetch(event.request); }
    catch (error) {
      if (event.request.mode === 'navigate') return await cache.match(new URL('index.html', self.registration.scope).href);
      throw error;
    }
  })());
});
"""
(root / 'offline_worker.js').write_text(script.replace('__VERSION__', digest.hexdigest()[:16]).replace('__FILES__', json.dumps(paths)))
print(f'Offline worker generated: {len(paths)} local resources, version {digest.hexdigest()[:16]}')
