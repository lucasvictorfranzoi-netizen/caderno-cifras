/* Caderno de Cifras — service worker v0.4.0 */
const VERSION = "cifras-v0.4.0";
const CORE = ["./", "./index.html", "./manifest.json", "./icons/icon-192.png", "./icons/icon-512.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});
self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET") return;

  // Supabase: auth e dados sempre pela rede; ÁUDIOS (storage público) com cache
  if (url.hostname.endsWith(".supabase.co")) {
    if (url.pathname.startsWith("/storage/v1/object/public/")) {
      // nomes de arquivo são únicos por upload → cache-first é seguro
      e.respondWith(
        caches.open(VERSION).then(async c => {
          const hit = await c.match(e.request);
          if (hit) return hit;
          const r = await fetch(e.request);
          if (r && (r.ok || r.type === "opaque")) c.put(e.request, r.clone());
          return r;
        })
      );
    }
    return; // /auth e /rest: rede, sem cache
  }

  // Navegação/app shell: rede primeiro, cache como reserva (offline)
  if (e.request.mode === "navigate" || url.pathname.endsWith("/index.html")) {
    e.respondWith(
      fetch(e.request)
        .then(r => { const cp = r.clone(); caches.open(VERSION).then(c => c.put("./index.html", cp)); return r; })
        .catch(() => caches.match("./index.html"))
    );
    return;
  }

  // Fontes do Google: cache com atualização em segundo plano
  if (url.hostname === "fonts.googleapis.com" || url.hostname === "fonts.gstatic.com") {
    e.respondWith(
      caches.open(VERSION).then(async c => {
        const hit = await c.match(e.request);
        const net = fetch(e.request).then(r => { c.put(e.request, r.clone()); return r; }).catch(() => hit);
        return hit || net;
      })
    );
    return;
  }

  // Demais estáticos do próprio site: cache primeiro
  if (url.origin === location.origin) {
    e.respondWith(
      caches.match(e.request).then(hit => hit || fetch(e.request).then(r => {
        const cp = r.clone(); caches.open(VERSION).then(c => c.put(e.request, cp)); return r;
      }))
    );
  }
});
