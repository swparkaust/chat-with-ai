import { useState, useEffect, useSyncExternalStore } from "react";
import { isPWA, isIOSSafari } from "@/lib/utils";
import { logger } from "@/lib/logger";

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
}

export type InstallMethod = "prompt" | "manual" | null;

interface InstallPromptStore {
  prompt: BeforeInstallPromptEvent | null;
  listeners: Set<() => void>;
  registered: boolean;
  promptPending: boolean;
}

// The browser dispatches beforeinstallprompt once per page load, so the
// captured event must outlive any single hook instance — a consumer that
// mounts after it fired (e.g. the ambient banner mounting once onboarding
// completes) reads it from here. Parked on globalThis because dev Fast
// Refresh re-evaluates this module: a module-local store would reset to null
// (hiding the install UI until full reload) and stack duplicate window
// listeners on every hot update.
const globalScope = globalThis as { __installPromptStore?: InstallPromptStore };
const store = (globalScope.__installPromptStore ??= {
  prompt: null,
  listeners: new Set(),
  registered: false,
  promptPending: false,
});

function setCapturedPrompt(prompt: BeforeInstallPromptEvent | null) {
  store.prompt = prompt;
  store.listeners.forEach((notify) => notify());
}

function subscribeToPrompt(notify: () => void) {
  store.listeners.add(notify);
  return () => {
    store.listeners.delete(notify);
  };
}

if (typeof window !== "undefined" && !store.registered) {
  store.registered = true;
  window.addEventListener("beforeinstallprompt", (e) => {
    e.preventDefault();
    setCapturedPrompt(e as BeforeInstallPromptEvent);
  });
  window.addEventListener("appinstalled", () => {
    setCapturedPrompt(null);
  });
}

export function usePWAInstall() {
  const installPrompt = useSyncExternalStore(
    subscribeToPrompt,
    () => store.prompt,
    () => null
  );
  const [canInstallManually, setCanInstallManually] = useState(false);

  useEffect(() => {
    // iOS Safari never fires beforeinstallprompt — installation only happens
    // manually via the share sheet, so surface instructions instead
    setCanInstallManually(isIOSSafari() && !isPWA());
  }, []);

  const installMethod: InstallMethod = installPrompt
    ? "prompt"
    : canInstallManually
      ? "manual"
      : null;

  const promptInstall = async () => {
    // The pending flag lives on the store like the one-shot event it guards:
    // every caller (banner, onboarding) shares it, so no double-tap on any
    // surface can re-prompt the same event
    if (!installPrompt || store.promptPending) return false;

    store.promptPending = true;
    try {
      try {
        await installPrompt.prompt();
      } catch (err) {
        // prompt() failing before the dialog shows leaves the event unspent,
        // and the browser only re-fires beforeinstallprompt after a shown
        // prompt — keep the event so a later tap can retry
        logger.error("Error showing install prompt:", err);
        return false;
      }

      try {
        const choice = await installPrompt.userChoice;
        return choice.outcome === "accepted";
      } finally {
        // Once shown, the event is spent (a second prompt() call rejects),
        // so drop it whatever the outcome; the browser re-fires
        // beforeinstallprompt when a new prompt is permitted
        setCapturedPrompt(null);
      }
    } catch (err) {
      logger.error("Error resolving install choice:", err);
      return false;
    } finally {
      store.promptPending = false;
    }
  };

  return {
    installMethod,
    promptInstall,
  };
}
