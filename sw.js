/* =========================================================
   AtlasIA — Service Worker
   Objetivo: deixar o app instalável (PWA) e permitir abrir a tela inicial
   mesmo sem internet. Funções que dependem de rede (IA generativa, busca,
   sincronização com a nuvem) continuam indisponíveis offline — isso é
   esperado e o próprio app avisa (ver offlineBanner em index.html) — mas
   a interface, o chat local, o modo FAQ e tudo que já estava salvo
   continuam abrindo normalmente.

   Sempre que publicar uma mudança no app, troque o número da versão
   abaixo (CACHE_VERSION) — é isso que faz o service worker perceber que
   há uma versão nova pra instalar (e então mostrar o banner de
   atualização em showUpdateBanner, no index.html).
   ========================================================= */
const CACHE_VERSION = 'atlasia-v1';
const CACHE_NAME = 'atlasia-shell-' + CACHE_VERSION;

// "App shell": o mínimo pra abrir a tela inicial offline. Adicione aqui
// outros arquivos estáticos que o app carregue sempre (ex: fontes ou
// imagens próprias que você venha a separar do index.html no futuro).
const APP_SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(APP_SHELL))
      .catch(() => { /* algum item pode não existir ainda no host — segue mesmo assim */ })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key.startsWith('atlasia-shell-') && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

// Permite que o botão "Atualizar agora" (showUpdateBanner, no index.html)
// force o novo service worker a assumir na hora, sem esperar todas as
// abas fecharem.
self.addEventListener('message', (event) => {
  if(event.data === 'ATLASIA_SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if(req.method !== 'GET') return; // não mexe em POST/PUT (chamadas à IA, Supabase etc.)

  const url = new URL(req.url);
  // Só cuida de pedidos pro próprio site — chamadas pra OpenAI, Gemini,
  // Supabase e afins passam direto (nunca ficam em cache, precisam
  // sempre de rede de verdade e de dado atual).
  if(url.origin !== self.location.origin) return;

  // Navegação (abrir/recarregar a página): tenta a rede primeiro, pra
  // sempre pegar a versão mais nova quando há internet; se falhar (rede
  // fora do ar), cai pro index.html salvo em cache — é isso que faz a
  // tela inicial abrir mesmo offline.
  if(req.mode === 'navigate'){
    event.respondWith(
      fetch(req).catch(() =>
        caches.match('./index.html').then((cached) => cached || caches.match('./'))
      )
    );
    return;
  }

  // Demais arquivos estáticos (ícones, manifest etc.): cache primeiro
  // (mais rápido e funciona offline), busca na rede só se não tiver em
  // cache ainda, e guarda uma cópia pra próxima vez.
  event.respondWith(
    caches.match(req).then((cached) => {
      if(cached) return cached;
      return fetch(req).then((res) => {
        if(res && res.ok){
          const resClone = res.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(req, resClone));
        }
        return res;
      }).catch(() => cached);
    })
  );
});
