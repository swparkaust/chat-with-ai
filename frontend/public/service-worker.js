const CACHE_NAME = 'ai-chat-v1';
const urlsToCache = [
  '/',
  '/manifest.json',
];

// Install event - cache resources
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(urlsToCache);
    })
  );
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') return;

  // Skip API and WebSocket requests
  if (
    event.request.url.includes('/api/') ||
    event.request.url.includes('/cable')
  ) {
    return;
  }

  event.respondWith(
    caches.match(event.request).then((response) => {
      // Cache hit - return response
      if (response) {
        return response;
      }

      // Clone the request
      const fetchRequest = event.request.clone();

      return fetch(fetchRequest).then((response) => {
        // Check if valid response
        if (
          !response ||
          response.status !== 200 ||
          response.type !== 'basic'
        ) {
          return response;
        }

        // Clone the response
        const responseToCache = response.clone();

        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, responseToCache);
        });

        return response;
      });
    })
  );
});

// Push notification event
self.addEventListener('push', (event) => {
  let data = {};
  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data = { title: 'New message', body: event.data.text() };
    }
  }

  const title = data.title || '○○와 채팅하기';
  const options = {
    body: data.body || '새 메시지가 도착했습니다',
    icon: data.icon || '/icon-192x192.png',
    badge: data.badge || '/icon-192x192.png',
    tag: data.tag || 'default',
    requireInteraction: false,
    vibrate: [200, 100, 200],
    data: data.data || {},
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Notification click event
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const targetUrl = event.notification.data?.url || '/';

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // If a window is already open at the target URL, focus it
        for (const client of clientList) {
          if (new URL(client.url).pathname === targetUrl && 'focus' in client) {
            return client.focus();
          }
        }

        // Otherwise, open a new window
        if (clients.openWindow) {
          return clients.openWindow(targetUrl);
        }
      })
  );
});

// Offline message outbox — pages enqueue failed requests into IndexedDB
// (see lib/offlineOutbox.ts, which must use the same constants) and this
// worker replays them when connectivity returns.
const OUTBOX_DB_NAME = 'offline-outbox';
const OUTBOX_DB_VERSION = 1;
const OUTBOX_STORE = 'requests';
const SYNC_TAG = 'sync-messages';

function openOutboxDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(OUTBOX_DB_NAME, OUTBOX_DB_VERSION);
    request.onupgradeneeded = () => {
      request.result.createObjectStore(OUTBOX_STORE, {
        keyPath: 'id',
        autoIncrement: true,
      });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function readOutbox(db) {
  return new Promise((resolve, reject) => {
    const request = db
      .transaction(OUTBOX_STORE, 'readonly')
      .objectStore(OUTBOX_STORE)
      .getAll();
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function deleteOutboxEntry(db, id) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(OUTBOX_STORE, 'readwrite');
    tx.objectStore(OUTBOX_STORE).delete(id);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

// Serialize replays: overlapping runs (e.g. a flush-outbox message arriving
// while an earlier flush is mid-flight) would re-fetch entries neither run
// has deleted yet, double-sending them.
let syncInFlight = null;

function syncMessages() {
  if (!syncInFlight) {
    syncInFlight = replayOutbox().finally(() => {
      syncInFlight = null;
    });
  }
  return syncInFlight;
}

async function replayOutbox() {
  const db = await openOutboxDb();

  try {
    // getAll returns entries in ascending key order, i.e. enqueue order
    const entries = await readOutbox(db);

    for (const entry of entries) {
      // Throws while offline, rejecting waitUntil so sync retries later
      const response = await fetch(entry.url, {
        method: entry.method,
        headers: entry.headers,
        body: entry.body,
      });

      if (response.status >= 500) {
        throw new Error(`Server error ${response.status}, will retry`);
      }

      // Delivered (or permanently rejected, e.g. 4xx) — drop it either way
      await deleteOutboxEntry(db, entry.id);
    }
  } finally {
    db.close();
  }
}

// Background sync event (for the offline message outbox)
self.addEventListener('sync', (event) => {
  if (event.tag === SYNC_TAG) {
    event.waitUntil(syncMessages());
  }
});

// Fallback trigger for browsers without Background Sync
self.addEventListener('message', (event) => {
  if (event.data?.type === 'flush-outbox') {
    event.waitUntil(syncMessages());
  }
});
