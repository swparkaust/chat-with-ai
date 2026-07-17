import { supportsServiceWorker } from "@/lib/utils";
import { logger } from "@/lib/logger";

// Must match the constants in public/service-worker.js, which owns replay
const OUTBOX_DB_NAME = "offline-outbox";
const OUTBOX_DB_VERSION = 1;
const OUTBOX_STORE = "requests";
const SYNC_TAG = "sync-messages";

interface QueuedRequest {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: string;
}

function isOutboxSupported(): boolean {
  return (
    supportsServiceWorker() &&
    typeof indexedDB !== "undefined"
  );
}

function openOutboxDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(OUTBOX_DB_NAME, OUTBOX_DB_VERSION);
    request.onupgradeneeded = () => {
      request.result.createObjectStore(OUTBOX_STORE, {
        keyPath: "id",
        autoIncrement: true,
      });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function enqueueRequest(entry: QueuedRequest): Promise<void> {
  const db = await openOutboxDb();
  try {
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(OUTBOX_STORE, "readwrite");
      tx.objectStore(OUTBOX_STORE).add(entry);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } finally {
    db.close();
  }
}

interface SyncCapableRegistration extends ServiceWorkerRegistration {
  sync?: { register(tag: string): Promise<void> };
}

async function requestReplay(): Promise<void> {
  const registration = (await navigator.serviceWorker
    .ready) as SyncCapableRegistration;

  if (registration.sync) {
    // Background Sync fires the service worker's replay even if the page closes
    await registration.sync.register(SYNC_TAG);
    return;
  }

  // Fallback for browsers without Background Sync: ask the service worker to
  // flush now, and again whenever connectivity returns while the page is open
  registration.active?.postMessage({ type: "flush-outbox" });
  ensureOnlineFlushListener();
}

let onlineListenerRegistered = false;

function ensureOnlineFlushListener(): void {
  if (onlineListenerRegistered) return;
  onlineListenerRegistered = true;

  window.addEventListener("online", () => {
    navigator.serviceWorker.ready
      .then((registration) => {
        registration.active?.postMessage({ type: "flush-outbox" });
      })
      .catch((err) => {
        logger.error("Failed to trigger outbox flush:", err);
      });
  });
}

// Queue a failed request for replay when connectivity returns.
// Returns true if the request was queued.
export async function queueForSync(entry: QueuedRequest): Promise<boolean> {
  if (!isOutboxSupported()) return false;

  try {
    await enqueueRequest(entry);
    await requestReplay();
    return true;
  } catch (err) {
    logger.error("Failed to queue request for offline sync:", err);
    return false;
  }
}

// Replay anything left over from a previous session (e.g. the app was closed
// while offline on a browser without Background Sync). No-op when empty.
export async function flushPendingOnStartup(): Promise<void> {
  if (!isOutboxSupported()) return;

  try {
    await requestReplay();
  } catch (err) {
    logger.error("Failed to flush offline outbox on startup:", err);
  }
}
